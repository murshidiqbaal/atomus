-- ============================================================
-- Fix Notifications Schema — Idempotent Migration
-- 2026-06-22
--
-- Ensures the notifications table has ALL required columns
-- regardless of which prior migrations have been applied.
-- Every statement uses IF NOT EXISTS / IF EXISTS guards.
-- ============================================================

-- 1. Add missing columns (safe to re-run)
-- --------------------------------------------------------
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS receiver_id      UUID,
  ADD COLUMN IF NOT EXISTS receiver_type    TEXT DEFAULT 'parent',
  ADD COLUMN IF NOT EXISTS parent_id        UUID,
  ADD COLUMN IF NOT EXISTS teacher_id       UUID,
  ADD COLUMN IF NOT EXISTS student_id       UUID,
  ADD COLUMN IF NOT EXISTS title            TEXT,
  ADD COLUMN IF NOT EXISTS message          TEXT,
  ADD COLUMN IF NOT EXISTS type             TEXT DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS read_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reference_table  TEXT,
  ADD COLUMN IF NOT EXISTS reference_id     TEXT,
  ADD COLUMN IF NOT EXISTS image_url        TEXT,
  ADD COLUMN IF NOT EXISTS priority         TEXT DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS created_by       UUID,
  ADD COLUMN IF NOT EXISTS campus_id        UUID,
  ADD COLUMN IF NOT EXISTS course_id        UUID,
  ADD COLUMN IF NOT EXISTS batch_id         UUID,
  ADD COLUMN IF NOT EXISTS scope            TEXT DEFAULT 'individual',
  ADD COLUMN IF NOT EXISTS created_at       TIMESTAMPTZ DEFAULT NOW();

-- 2. Drop outdated CHECK constraints (safe even if they don't exist)
-- --------------------------------------------------------
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_receiver_type_check;
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_priority_check;
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_scope_check;

-- Re-add with expanded values
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_receiver_type_check
    CHECK (receiver_type IN ('parent', 'teacher', 'admin'));

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_priority_check
    CHECK (priority IN ('normal', 'high'));

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_scope_check
    CHECK (scope IN ('individual', 'course', 'campus', 'broadcast'));

-- 3. Indexes for performance
-- --------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_notifications_receiver
  ON public.notifications(receiver_id, is_read);

CREATE INDEX IF NOT EXISTS idx_notifications_receiver_type
  ON public.notifications(receiver_type);

CREATE INDEX IF NOT EXISTS idx_notifications_campus
  ON public.notifications(campus_id)
  WHERE campus_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_course
  ON public.notifications(course_id)
  WHERE course_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_created
  ON public.notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_parent
  ON public.notifications(parent_id)
  WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_teacher
  ON public.notifications(teacher_id)
  WHERE teacher_id IS NOT NULL;

-- 4. Sync trigger: keep parent_id/teacher_id and receiver_id in sync
-- --------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_notification_receiver_fields()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- When receiver_id is set, populate the role-specific column
  IF NEW.receiver_id IS NOT NULL THEN
    IF NEW.receiver_type = 'parent' THEN
      NEW.parent_id := COALESCE(NEW.parent_id, NEW.receiver_id);
    ELSIF NEW.receiver_type = 'teacher' THEN
      NEW.teacher_id := COALESCE(NEW.teacher_id, NEW.receiver_id);
    END IF;
  END IF;

  -- When parent_id is set but receiver_id is not, backfill
  IF NEW.parent_id IS NOT NULL AND NEW.receiver_id IS NULL THEN
    NEW.receiver_id := NEW.parent_id;
    NEW.receiver_type := 'parent';
  END IF;

  -- When teacher_id is set but receiver_id is not, backfill
  IF NEW.teacher_id IS NOT NULL AND NEW.receiver_id IS NULL THEN
    NEW.receiver_id := NEW.teacher_id;
    NEW.receiver_type := 'teacher';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_notifications_parent_id ON public.notifications;
DROP TRIGGER IF EXISTS trg_sync_notification_receiver ON public.notifications;
CREATE TRIGGER trg_sync_notification_receiver
  BEFORE INSERT OR UPDATE ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION sync_notification_receiver_fields();

-- 5. RLS Policies — use receiver_id exclusively
-- --------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop ALL old policies to avoid conflicts
DROP POLICY IF EXISTS "parent_select_own" ON public.notifications;
DROP POLICY IF EXISTS "parent_update_own" ON public.notifications;
DROP POLICY IF EXISTS "user_select_own" ON public.notifications;
DROP POLICY IF EXISTS "user_update_own" ON public.notifications;
DROP POLICY IF EXISTS "service_insert" ON public.notifications;

-- Users can read their own notifications
CREATE POLICY "user_select_own" ON public.notifications
  FOR SELECT USING (auth.uid() = receiver_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "user_update_own" ON public.notifications
  FOR UPDATE USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);

-- Service role / triggers can insert
CREATE POLICY "service_insert" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- 6. Update the absence notification trigger to use receiver_id
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

  -- Lookup subject name (best-effort)
  BEGIN
    SELECT sub.subject_name
      INTO v_subject_name
      FROM public.subjects sub
     WHERE sub.id = NEW.subject_id
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_subject_name := NULL;
  END;

  -- Build notification text
  v_title   := 'Student Absent Alert';
  v_message := v_student_name || ' was marked absent today'
    || CASE WHEN v_subject_name IS NOT NULL
            THEN ' for ' || v_subject_name || ' class.'
            ELSE '.'
       END;

  -- Insert notification using receiver_id (trigger will sync parent_id)
  INSERT INTO public.notifications (
    receiver_id, receiver_type, parent_id, student_id,
    title, message, type, scope
  )
  VALUES (
    v_parent_id, 'parent', v_parent_id, NEW.student_id,
    v_title, v_message, 'attendance', 'individual'
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_notif_id;

  -- Fire FCM push (if pg_net is enabled and insert succeeded)
  IF v_notif_id IS NOT NULL THEN
    BEGIN
      PERFORM call_send_fcm(
        v_notif_id, v_parent_id, NEW.student_id,
        v_title, v_message, 'attendance'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Never let FCM failure block attendance
    END;
  END IF;

  RETURN NEW;
END;
$$;

-- 7. Update fee reminder trigger to use receiver_id
-- --------------------------------------------------------
CREATE OR REPLACE FUNCTION send_fee_due_reminders()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_fee       RECORD;
  v_parent_id UUID;
  v_student_name TEXT;
  v_title     TEXT;
  v_message   TEXT;
  v_notif_id  UUID;
  v_count     INT := 0;
BEGIN
  FOR v_fee IN
    SELECT f.id AS fee_id, f.student_id, f.amount_due, f.amount_paid, f.due_date
    FROM public.fees f
    WHERE f.status IN ('pending', 'partially_paid')
      AND f.due_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '10 days')
      AND NOT EXISTS (
        SELECT 1 FROM public.fee_reminders_sent r
        WHERE r.fee_id = f.id AND r.reminder_for = f.due_date
      )
  LOOP
    -- Lookup parent
    SELECT s.parent_id, s.full_name
      INTO v_parent_id, v_student_name
      FROM public.students s
     WHERE s.id = v_fee.student_id;

    IF v_parent_id IS NULL THEN
      CONTINUE;
    END IF;

    v_title := 'Fee Due in 10 Days';
    v_message := COALESCE(v_student_name, 'Your child')
      || '''s fee of '
      || TO_CHAR(GREATEST(v_fee.amount_due - COALESCE(v_fee.amount_paid, 0), 0), 'FM999G999G990D00')
      || ' is due on '
      || TO_CHAR(v_fee.due_date, 'DD Mon YYYY')
      || '. Please make the payment to avoid late charges.';

    INSERT INTO public.notifications (
      receiver_id, receiver_type, parent_id, student_id,
      title, message, type, scope
    )
    VALUES (
      v_parent_id, 'parent', v_parent_id, v_fee.student_id,
      v_title, v_message, 'fees', 'individual'
    )
    RETURNING id INTO v_notif_id;

    INSERT INTO public.fee_reminders_sent (fee_id, student_id, reminder_for, notification_id)
    VALUES (v_fee.fee_id, v_fee.student_id, v_fee.due_date, v_notif_id)
    ON CONFLICT (fee_id, reminder_for) DO NOTHING;

    -- Push via FCM
    BEGIN
      PERFORM call_send_fcm(
        v_notif_id, v_parent_id, v_fee.student_id,
        v_title, v_message, 'fees'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Sent % fee reminders', v_count;
END;
$$;

-- 8. Backfill existing rows: sync receiver_id from parent_id where missing
-- --------------------------------------------------------
UPDATE public.notifications
SET receiver_id = parent_id,
    receiver_type = 'parent',
    scope = COALESCE(scope, 'individual')
WHERE parent_id IS NOT NULL
  AND receiver_id IS NULL;

-- ============================================================
-- DONE. The notifications table now has all columns needed for
-- individual, course-wide, campus-wide, and broadcast notifications
-- for parents, teachers, and admins.
-- ============================================================
