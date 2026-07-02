/**
 * Supabase Edge Function: send-fcm-notification
 *
 * Called by the PostgreSQL trigger via pg_net (or invoked directly).
 * Looks up the recipient's FCM token from the device_tokens table
 * (with fallback to parents/teachers legacy columns) and sends a
 * push notification via FCM HTTP v1 API.
 *
 * Environment variables required (set in Supabase Dashboard > Edge Functions > Secrets):
 *   FIREBASE_PROJECT_ID   - Your Firebase project ID
 *   FIREBASE_SERVICE_KEY  - Full service account JSON (stringify the JSON)
 *   SUPABASE_SERVICE_ROLE_KEY - Service role key for Supabase admin queries
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationPayload {
  notification_id: string;
  /** receiver_id is the primary lookup key (parent, teacher, or admin UUID) */
  receiver_id: string;
  /** Optional — kept for backwards compatibility with older triggers */
  parent_id?: string;
  student_id?: string;
  title: string;
  message: string;
  type: string;
  receiver_type?: string;
}

async function getAccessToken(serviceKey: string): Promise<string> {
  const key = JSON.parse(serviceKey);
  const now = Math.floor(Date.now() / 1000);

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    _pemToBuffer(key.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  return create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: key.client_email,
      sub: key.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    cryptoKey,
  );
}

function _pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

async function sendFcmMessage(
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<void> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        data,
        android: {
          priority: "high",
          notification: {
            channel_id: data.type === "attendance"
              ? "atomus_attendance"
              : "atomus_general",
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`FCM error ${response.status}: ${err}`);
  }
}

/**
 * Look up FCM token for a user. Tries device_tokens first,
 * then falls back to legacy parents/teachers table columns.
 */
async function getFcmToken(
  admin: ReturnType<typeof createClient>,
  userId: string,
  receiverType?: string,
): Promise<string | null> {
  // 1. Try the device_tokens table (preferred — supports all user types)
  const { data: tokenRow } = await admin
    .from("device_tokens")
    .select("device_token")
    .eq("user_id", userId)
    .eq("is_active", true)
    .order("last_used", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (tokenRow?.device_token) {
    return tokenRow.device_token;
  }

  // 2. Fallback to legacy columns
  const table = receiverType === "teacher" ? "teachers" : "parents";
  const { data: legacyRow } = await admin
    .from(table)
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();

  return legacyRow?.fcm_token ?? null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
    const firebaseServiceKey = Deno.env.get("FIREBASE_SERVICE_KEY")!;

    const admin = createClient(supabaseUrl, serviceRoleKey);

    // Resolve the target user ID — prefer receiver_id, fall back to parent_id
    const targetUserId = payload.receiver_id || payload.parent_id;
    if (!targetUserId) {
      return new Response(
        JSON.stringify({ error: "No receiver_id or parent_id provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Look up FCM token
    const fcmToken = await getFcmToken(admin, targetUserId, payload.receiver_type);
    if (!fcmToken) {
      return new Response(
        JSON.stringify({ error: "No FCM token found for user" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Get FCM OAuth2 access token
    const jwtToken = await getAccessToken(firebaseServiceKey);

    // Exchange JWT for actual access token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwtToken,
      }),
    });
    const { access_token } = await tokenRes.json();

    await sendFcmMessage(
      firebaseProjectId,
      fcmToken,
      payload.title,
      payload.message,
      {
        type: payload.type,
        notification_id: payload.notification_id,
        student_id: payload.student_id ?? "",
        receiver_id: targetUserId,
      },
      access_token,
    );

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
