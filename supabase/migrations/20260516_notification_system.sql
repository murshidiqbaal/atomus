-- ============================================================
-- Atomus Notification System — Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add FCM token + last_active to parents table
-- --------------------------------------------------------
ALTER TABLE public.parents
  ADD COLUMN IF NOT EXISTS fcm_token TEXT,
  ADD COLUMN IF NOT EXISTS last_active TIMESTAMPTZ DEFAULT NOW();


-- 2. Notifications table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   UUID NOT NULL,   -- = auth.users.id (RLS key)
  student_id  UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  message     TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'attendance'
                CHECK (type IN ('attendance','marks','fees','announcements','emergency')),
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS notifications_parent_idx  ON public.notifications(parent_id);
CREATE INDEX IF NOT EXISTS notifications_time_idx    ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx  ON public.notifications(parent_id, is_read)
  WHERE is_read = FALSE;

-- Duplicate-prevention: one absence notification per student per calendar day
CREATE UNIQUE INDEX IF NOT EXISTS notifications_absence_dedup
  ON public.notifications(student_id, (DATE(created_at)))
  WHERE type = 'attendance';


-- 3. Row-Level Security
-- --------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Parents see only their own notifications
CREATE POLICY "parent_select_own"
  ON public.notifications FOR SELECT
  USING (auth.uid() = parent_id);

-- Parents can mark their own notifications as read
CREATE POLICY "parent_update_own"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = parent_id)
  WITH CHECK (auth.uid() = parent_id);

-- Service role / triggers can insert notifications
CREATE POLICY "service_insert"
  ON public.notifications FOR INSERT
  WITH CHECK (true);


-- 4. Enable Supabase Realtime for instant push to the parent app
-- --------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;


-- 5. Helper function — send FCM via pg_net (optional, requires pg_net extension)
-- --------------------------------------------------------
-- Enable pg_net if not already active:
-- CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION call_send_fcm(
  p_notification_id UUID,
  p_parent_id       UUID,
  p_student_id      UUID,
  p_title           TEXT,
  p_message         TEXT,
  p_type            TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Calls the Supabase Edge Function asynchronously via pg_net.
  -- Replace <PROJECT_REF> with your Supabase project reference.
  PERFORM net.http_post(
    url     := 'https://txtvvlxaurqovghtngzm.supabase.co/functions/v1/send-fcm-notification',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
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
  -- Never let FCM failure block the main attendance write
  NULL;
END;
$$;


-- 6. Core trigger function — fires on every attendance insert/update
-- --------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_parent_on_absence()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_parent_id    UUID;
  v_student_name TEXT;
  v_subject_name TEXT;
  v_notif_id     UUID;
  v_title        TEXT;
  v_message      TEXT;
BEGIN
  -- Only act on 'Absent' status
  IF NEW.status <> 'Absent' THEN
    RETURN NEW;
  END IF;

  -- Only act on today's attendance
  IF DATE(NEW.attendance_date) <> CURRENT_DATE THEN
    RETURN NEW;
  END IF;

  -- Lookup parent + student name
  SELECT s.parent_id, s.full_name
    INTO v_parent_id, v_student_name
    FROM public.students s
   WHERE s.id = NEW.student_id;

  IF v_parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Lookup subject name via batch (best-effort; NULL is fine)
  SELECT sub.subject_name
    INTO v_subject_name
    FROM public.batches b
    JOIN public.subjects sub ON sub.id = b.subject_id
   WHERE b.id = NEW.batch_id
   LIMIT 1;

  -- Build notification text
  v_title   := 'Student Absent Alert';
  v_message := v_student_name || ' was marked absent today'
    || CASE WHEN v_subject_name IS NOT NULL
            THEN ' for ' || v_subject_name || ' class.'
            ELSE '.'
       END;

  -- Insert notification — ON CONFLICT DO NOTHING prevents duplicates
  INSERT INTO public.notifications (parent_id, student_id, title, message, type)
  VALUES (v_parent_id, NEW.student_id, v_title, v_message, 'attendance')
  ON CONFLICT ON CONSTRAINT notifications_absence_dedup DO NOTHING
  RETURNING id INTO v_notif_id;

  -- Fire FCM push (if pg_net is enabled and insert succeeded)
  IF v_notif_id IS NOT NULL THEN
    PERFORM call_send_fcm(
      v_notif_id, v_parent_id, NEW.student_id,
      v_title, v_message, 'attendance'
    );
  END IF;

  RETURN NEW;
END;
$$;


-- 7. Attach trigger to attendance table
-- --------------------------------------------------------
DROP TRIGGER IF EXISTS trg_attendance_absence_notify ON public.attendance;

CREATE TRIGGER trg_attendance_absence_notify
  AFTER INSERT OR UPDATE OF status
  ON public.attendance
  FOR EACH ROW
  EXECUTE FUNCTION notify_parent_on_absence();


-- ============================================================
-- DONE. Summary of what was created:
--   • parents.fcm_token / parents.last_active columns
--   • notifications table with RLS + dedup index
--   • Realtime enabled on notifications
--   • notify_parent_on_absence() trigger function
--   • trg_attendance_absence_notify trigger on attendance
--   • call_send_fcm() helper (needs pg_net + project ref update)
-- ============================================================
