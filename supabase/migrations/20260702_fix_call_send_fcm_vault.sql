-- ============================================================
-- Fix call_send_fcm to fallback to vault.decrypted_secrets
-- 2026-07-02
-- ============================================================

CREATE OR REPLACE FUNCTION call_send_fcm(
  p_notification_id UUID,
  p_parent_id       UUID,
  p_student_id      UUID,
  p_title           TEXT,
  p_message         TEXT,
  p_type            TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_service_key TEXT;
BEGIN
  -- 1. Try to get service role key from session settings
  v_service_key := current_setting('app.service_role_key', true);
  
  -- 2. Fallback to Supabase Vault decrypted secrets if not set in session
  IF v_service_key IS NULL OR v_service_key = '' THEN
    BEGIN
      SELECT decrypted_secret INTO v_service_key
        FROM vault.decrypted_secrets
       WHERE name = 'service_role_key'
       LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_service_key := NULL;
    END;
  END IF;

  -- 3. Invoke Edge Function asynchronously via pg_net
  PERFORM net.http_post(
    url     := 'https://txtvvlxaurqovghtngzm.supabase.co/functions/v1/send-fcm-notification',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || COALESCE(v_service_key, '')
               ),
    body    := jsonb_build_object(
                 'notification_id', p_notification_id,
                 'parent_id',       p_parent_id,
                 'student_id',      p_student_id,
                 'title',           p_title,
                 'message',         p_message,
                 'type',            p_type
               )
  );
EXCEPTION WHEN OTHERS THEN
  -- Never let FCM failure block main database operations
  NULL;
END;
$$;
