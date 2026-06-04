/**
 * Supabase Edge Function: profile-image-upload
 *
 * Uploads parent/student profile images to Google Drive, sets public-read
 * permissions, validates parent ownership, and stores only the Drive file ID
 * in the existing parents/students tables.
 *
 * Environment variables:
 *   SUPABASE_SERVICE_ROLE_KEY
 *   GOOGLE_SERVICE_ACCOUNT_KEY              Full service account JSON string
 *   GOOGLE_DRIVE_PARENT_PROFILES_FOLDER_ID  Optional existing folder ID
 *   GOOGLE_DRIVE_STUDENT_PROFILES_FOLDER_ID Optional existing folder ID
 */

import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { createJWT } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type TargetType = "parent" | "student";

class HttpError extends Error {
  constructor(message: string, readonly status = 500) {
    super(message);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new HttpError("Method not allowed", 405);
    }

    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const googleServiceKey = requiredEnv("GOOGLE_SERVICE_ACCOUNT_KEY");
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) throw new HttpError("Missing authorization token", 401);

    const { data, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !data.user) {
      throw new HttpError("Invalid or expired user session", 401);
    }

    const form = await req.formData();
    const targetType = form.get("target_type")?.toString() as TargetType;
    const targetId = form.get("target_id")?.toString();
    const file = form.get("file");

    if (targetType !== "parent" && targetType !== "student") {
      throw new HttpError("Invalid upload target", 400);
    }
    if (!targetId) throw new HttpError("Missing target ID", 400);
    if (!(file instanceof File)) {
      throw new HttpError("Missing image file", 400);
    }
    if (!file.type.startsWith("image/")) {
      throw new HttpError("Only image files are allowed", 400);
    }
    if (file.size > 8 * 1024 * 1024) {
      throw new HttpError("Image is too large after compression", 413);
    }

    const parent = await resolveParent(admin, data.user);
    await validateTarget(admin, parent.id, targetType, targetId);

    const accessToken = await getDriveAccessToken(googleServiceKey);
    const folderId = await resolveFolderId(accessToken, targetType);
    const driveFileId = await uploadToDrive({
      accessToken,
      folderId,
      targetType,
      targetId,
      file,
    });
    await makePublic(accessToken, driveFileId);
    await saveDriveFileId(admin, parent.id, targetType, targetId, driveFileId);

    return jsonResponse({
      success: true,
      fileId: driveFileId,
      targetType,
      targetId,
    });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse(
      { error: error instanceof Error ? error.message : String(error) },
      status,
    );
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(`Missing environment variable: ${name}`);
  return value;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function resolveParent(
  admin: SupabaseClient,
  user: User,
): Promise<Record<string, string>> {
  const checks = [
    ["id", user.id],
    ["auth_user_id", user.id],
    ["auth_id", user.id],
    ["email", user.email ?? ""],
    ["phone_number", user.phone ?? ""],
    ["username", user.phone ?? ""],
  ];

  for (const [column, value] of checks) {
    if (!value) continue;
    const parent = await tryResolveParent(admin, column, value);
    if (parent) return parent;
  }

  throw new HttpError("Parent profile not found for this user", 403);
}

async function tryResolveParent(
  admin: SupabaseClient,
  column: string,
  value: string,
): Promise<Record<string, string> | null> {
  const { data, error } = await admin
    .from("parents")
    .select("id")
    .eq(column, value)
    .maybeSingle();

  if (error || !data?.id) return null;
  return { id: data.id.toString() };
}

async function validateTarget(
  admin: SupabaseClient,
  parentId: string,
  targetType: TargetType,
  targetId: string,
): Promise<void> {
  if (targetType === "parent") {
    if (targetId !== parentId) {
      throw new HttpError("You can only update your own parent photo", 403);
    }
    return;
  }

  const { data, error } = await admin
    .from("students")
    .select("id, parent_id")
    .eq("id", targetId)
    .maybeSingle();

  if (error || !data || data.parent_id?.toString() !== parentId) {
    throw new HttpError("Student is not linked to this parent", 403);
  }
}

async function getDriveAccessToken(serviceKey: string): Promise<string> {
  const key = JSON.parse(serviceKey);
  const now = Math.floor(Date.now() / 1000);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuffer(key.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const assertion = await createJWT(
    { alg: "RS256", typ: "JWT" },
    {
      iss: key.client_email,
      sub: key.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/drive",
    },
    cryptoKey,
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new HttpError(`Google OAuth failed: ${await response.text()}`, 502);
  }

  const json = await response.json();
  if (!json.access_token) {
    throw new HttpError("Google OAuth returned no access token", 502);
  }
  return json.access_token;
}

function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

async function resolveFolderId(
  accessToken: string,
  targetType: TargetType,
): Promise<string> {
  const envName = targetType === "parent"
    ? "GOOGLE_DRIVE_PARENT_PROFILES_FOLDER_ID"
    : "GOOGLE_DRIVE_STUDENT_PROFILES_FOLDER_ID";
  const configured = Deno.env.get(envName);
  if (configured) return configured;

  if (targetType === "parent") {
    return "1bBwK2-emly4lpO7KD7EFz0H-VcVLb3Wq";
  }

  return findOrCreateFolder(
    accessToken,
    "StudentProfiles",
  );
}

async function findOrCreateFolder(
  accessToken: string,
  folderName: string,
): Promise<string> {
  const query = [
    `name='${folderName.replaceAll("'", "\\'")}'`,
    "mimeType='application/vnd.google-apps.folder'",
    "trashed=false",
  ].join(" and ");

  const listUrl = new URL("https://www.googleapis.com/drive/v3/files");
  listUrl.searchParams.set("q", query);
  listUrl.searchParams.set("fields", "files(id,name)");
  const listResponse = await driveFetch(accessToken, listUrl.toString());
  const listJson = await listResponse.json();
  const existing = listJson.files?.[0]?.id;
  if (existing) return existing;

  const createResponse = await driveFetch(
    accessToken,
    "https://www.googleapis.com/drive/v3/files?fields=id",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: folderName,
        mimeType: "application/vnd.google-apps.folder",
      }),
    },
  );
  const createJson = await createResponse.json();
  if (!createJson.id) throw new HttpError("Could not create Drive folder", 502);
  return createJson.id;
}

async function uploadToDrive({
  accessToken,
  folderId,
  targetType,
  targetId,
  file,
}: {
  accessToken: string;
  folderId: string;
  targetType: TargetType;
  targetId: string;
  file: File;
}): Promise<string> {
  const boundary = `atomus_${globalThis.crypto.randomUUID()}`;
  const safeTargetId = targetId.replace(/[^A-Za-z0-9_-]/g, "");
  const extension = file.type === "image/png" ? "png" : "jpg";
  const metadata = {
    name: `${targetType}_${safeTargetId}_${Date.now()}.${extension}`,
    mimeType: file.type || "image/jpeg",
    parents: [folderId],
  };

  const body = new Blob([
    `--${boundary}\r\n`,
    "Content-Type: application/json; charset=UTF-8\r\n\r\n",
    JSON.stringify(metadata),
    "\r\n",
    `--${boundary}\r\n`,
    `Content-Type: ${file.type || "image/jpeg"}\r\n\r\n`,
    new Uint8Array(await file.arrayBuffer()),
    "\r\n",
    `--${boundary}--`,
  ]);

  const response = await driveFetch(
    accessToken,
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id",
    {
      method: "POST",
      headers: { "Content-Type": `multipart/related; boundary=${boundary}` },
      body,
    },
  );
  const json = await response.json();
  if (!json.id) throw new HttpError("Google Drive returned no file ID", 502);
  return json.id;
}

async function makePublic(accessToken: string, fileId: string): Promise<void> {
  await driveFetch(
    accessToken,
    `https://www.googleapis.com/drive/v3/files/${fileId}/permissions`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role: "reader", type: "anyone" }),
    },
  );
}

async function saveDriveFileId(
  admin: SupabaseClient,
  parentId: string,
  targetType: TargetType,
  targetId: string,
  driveFileId: string,
): Promise<void> {
  if (targetType === "parent") {
    const { error } = await admin
      .from("parents")
      .update({ 
        profile_photo_drive_id: driveFileId,
        profile_photo_url: `/api/media?id=${driveFileId}`
      })
      .eq("id", parentId);
    if (error) throw new HttpError(error.message, 500);
    return;
  }

  const { error } = await admin
    .from("students")
    .update({ 
      profile_photo_drive_id: driveFileId,
      profile_photo_url: `/api/media?id=${driveFileId}`
    })
    .eq("id", targetId)
    .eq("parent_id", parentId);
  if (error) throw new HttpError(error.message, 500);
}

async function driveFetch(
  accessToken: string,
  url: string,
  init: RequestInit = {},
): Promise<Response> {
  const headers = new Headers(init.headers);
  headers.set("Authorization", `Bearer ${accessToken}`);
  const response = await fetch(url, { ...init, headers });
  if (!response.ok) {
    throw new HttpError(`Google Drive error ${response.status}: ${await response.text()}`, 502);
  }
  return response;
}
