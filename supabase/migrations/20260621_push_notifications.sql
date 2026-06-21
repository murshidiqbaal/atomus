-- ============================================================
-- Enterprise Push Notification System Migration
-- 2026-06-21
-- ============================================================

-- 1. Create device_tokens table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL,
  user_type    TEXT NOT NULL CHECK (user_type IN ('parent', 'teacher', 'admin')),
  device_token TEXT NOT NULL UNIQUE,
  device_name  TEXT,
  device_model TEXT,
  platform     TEXT CHECK (platform IN ('android', 'ios', 'web')),
  app_version  TEXT,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  last_used    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id, is_active);

-- 2. Alter notifications table to be generic
-- --------------------------------------------------------
-- Remove NOT NULL constraints to accommodate teachers/admins and non-student notifications
ALTER TABLE public.notifications ALTER COLUMN parent_id DROP NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN student_id DROP NOT NULL;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS receiver_id UUID,
  ADD COLUMN IF NOT EXISTS receiver_type TEXT DEFAULT 'parent' CHECK (receiver_type IN ('parent', 'teacher', 'admin')),
  ADD COLUMN IF NOT EXISTS reference_table TEXT,
  ADD COLUMN IF NOT EXISTS reference_id TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal' CHECK (priority IN ('normal', 'high')),
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Drop type check constraint if it exists to allow generic types
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Sync Trigger: keep parent_id and receiver_id synced when receiver_type = 'parent'
CREATE OR REPLACE FUNCTION sync_notifications_parent_id()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.receiver_type = 'parent' AND NEW.receiver_id IS NOT NULL THEN
    NEW.parent_id := NEW.receiver_id;
  ELSIF NEW.parent_id IS NOT NULL AND NEW.receiver_id IS NULL THEN
    NEW.receiver_id := NEW.parent_id;
    NEW.receiver_type := 'parent';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_notifications_parent_id ON public.notifications;
CREATE TRIGGER trg_sync_notifications_parent_id
  BEFORE INSERT OR UPDATE ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION sync_notifications_parent_id();

-- 3. Create notification_preferences table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  attendance    BOOLEAN NOT NULL DEFAULT TRUE,
  marks         BOOLEAN NOT NULL DEFAULT TRUE,
  fees          BOOLEAN NOT NULL DEFAULT TRUE,
  announcements BOOLEAN NOT NULL DEFAULT TRUE,
  reports       BOOLEAN NOT NULL DEFAULT TRUE,
  general       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create notification_logs table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
  device_token    TEXT,
  platform        TEXT,
  status          TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'delivered', 'opened')),
  failure_reason  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_logs_notif ON public.notification_logs(notification_id);

-- 5. Row-Level Security Policies
-- --------------------------------------------------------
-- Device Tokens policies
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_select_own_tokens" ON public.device_tokens;
CREATE POLICY "user_select_own_tokens" ON public.device_tokens FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_insert_own_tokens" ON public.device_tokens;
CREATE POLICY "user_insert_own_tokens" ON public.device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_update_own_tokens" ON public.device_tokens;
CREATE POLICY "user_update_own_tokens" ON public.device_tokens FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_delete_own_tokens" ON public.device_tokens;
CREATE POLICY "user_delete_own_tokens" ON public.device_tokens FOR DELETE USING (auth.uid() = user_id);

-- Notification Preferences policies
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_select_own_prefs" ON public.notification_preferences;
CREATE POLICY "user_select_own_prefs" ON public.notification_preferences FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_upsert_own_prefs" ON public.notification_preferences;
CREATE POLICY "user_upsert_own_prefs" ON public.notification_preferences FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Recreate notifications policies for receiver_id
DROP POLICY IF EXISTS "parent_select_own" ON public.notifications;
DROP POLICY IF EXISTS "user_select_own" ON public.notifications;
CREATE POLICY "user_select_own" ON public.notifications FOR SELECT USING (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "parent_update_own" ON public.notifications;
DROP POLICY IF EXISTS "user_update_own" ON public.notifications;
CREATE POLICY "user_update_own" ON public.notifications FOR UPDATE USING (auth.uid() = receiver_id) WITH CHECK (auth.uid() = receiver_id);

-- Recreate service role insert policy
DROP POLICY IF EXISTS "service_insert" ON public.notifications;
CREATE POLICY "service_insert" ON public.notifications FOR INSERT WITH CHECK (true);

-- Enable RLS on notification logs
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

-- 6. Create scheduled_notifications table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  message         TEXT NOT NULL,
  type            TEXT NOT NULL,
  target          TEXT NOT NULL,
  campus_id       UUID REFERENCES public.campuses(id) ON DELETE CASCADE,
  course_id       UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  scheduled_time  TIMESTAMPTZ NOT NULL,
  is_sent         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;
