-- ============================================================
-- Fix duplicate absent notifications & daily report notifications
-- 2026-06-24
-- ============================================================

-- 1. Redefine notify_parent_on_absence with a duplication check
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

  -- Only act on attendance marked for today or yesterday/tomorrow (to accommodate timezone offsets)
  IF NEW.attendance_date < CURRENT_DATE - INTERVAL '1 day' OR NEW.attendance_date > CURRENT_DATE + INTERVAL '1 day' THEN
    RETURN NEW;
  END IF;

  -- Check if a notification for this student's absence has already been created today/yesterday
  IF EXISTS (
    SELECT 1 
      FROM public.notifications 
     WHERE student_id = NEW.student_id 
       AND type = 'attendance' 
       AND created_at >= CURRENT_DATE - INTERVAL '1 day'
  ) THEN
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


-- 2. Define trigger function for daily reports
CREATE OR REPLACE FUNCTION notify_parent_on_daily_report()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_parent_id    UUID;
  v_student_name TEXT;
  v_subject_name TEXT;
  v_notif_id     UUID;
  v_title        TEXT;
  v_message      TEXT;
BEGIN
  -- Lookup parent + student name
  SELECT s.parent_id, s.full_name
    INTO v_parent_id, v_student_name
    FROM public.students s
   WHERE s.id = NEW.student_id;

  IF v_parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Lookup subject name (best-effort)
  IF NEW.subject_id IS NOT NULL THEN
    BEGIN
      SELECT sub.subject_name
        INTO v_subject_name
        FROM public.subjects sub
       WHERE sub.id = NEW.subject_id
       LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_subject_name := NULL;
    END;
  END IF;

  -- Build notification text
  v_title   := 'New Daily Report';
  v_message := 'A new report card/remarks updated for ' || v_student_name
    || CASE WHEN v_subject_name IS NOT NULL
            THEN ' in ' || v_subject_name || '.'
            ELSE '.'
       END;

  -- Insert notification using receiver_id (trigger will sync parent_id)
  INSERT INTO public.notifications (
    receiver_id, receiver_type, parent_id, student_id,
    title, message, type, scope
  )
  VALUES (
    v_parent_id, 'parent', v_parent_id, NEW.student_id,
    v_title, v_message, 'reports', 'individual'
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_notif_id;

  -- Fire FCM push (if pg_net is enabled and insert succeeded)
  IF v_notif_id IS NOT NULL THEN
    BEGIN
      PERFORM call_send_fcm(
        v_notif_id, v_parent_id, NEW.student_id,
        v_title, v_message, 'reports'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Attach trigger to student_daily_reports table
DROP TRIGGER IF EXISTS trg_student_daily_reports_notify ON public.student_daily_reports;
CREATE TRIGGER trg_student_daily_reports_notify
  AFTER INSERT OR UPDATE
  ON public.student_daily_reports
  FOR EACH ROW
  EXECUTE FUNCTION notify_parent_on_daily_report();
