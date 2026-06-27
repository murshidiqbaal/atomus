-- ============================================================
-- Daily Class Reports & Daily Student Reports Schema Migration
-- 2026-06-28
-- ============================================================

-- 1. Create Daily Class Reports Table
CREATE TABLE IF NOT EXISTS public.daily_class_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id      UUID REFERENCES public.teachers(id) ON DELETE SET NULL,
  course_id       UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  batch_id        UUID REFERENCES public.batches(id) ON DELETE CASCADE,
  subject_id      UUID REFERENCES public.subjects(id) ON DELETE CASCADE,
  report_date     DATE NOT NULL,
  session_type    TEXT NOT NULL CHECK (session_type IN ('forenoon', 'afternoon')),
  topics_covered  TEXT NOT NULL,
  homework        TEXT,
  general_remarks TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure subject_id exists if the table already existed without it
ALTER TABLE public.daily_class_reports ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES public.subjects(id) ON DELETE CASCADE;

-- Ensure batch_id is nullable for course-wide daily reports
ALTER TABLE public.daily_class_reports ALTER COLUMN batch_id DROP NOT NULL;

-- Drop old unique constraints and partial indices if they exist
ALTER TABLE public.daily_class_reports DROP CONSTRAINT IF EXISTS daily_class_reports_course_id_batch_id_report_date_session_key;
ALTER TABLE public.daily_class_reports DROP CONSTRAINT IF EXISTS daily_class_reports_course_id_batch_id_report_date_se_key;
ALTER TABLE public.daily_class_reports DROP CONSTRAINT IF EXISTS daily_class_reports_subject_session_key;
DROP INDEX IF EXISTS idx_daily_class_reports_unique_subject;
DROP INDEX IF EXISTS idx_daily_class_reports_unique_null_subject;

-- Add total unique constraint matching PostgREST/Supabase conflict target
ALTER TABLE public.daily_class_reports 
  ADD CONSTRAINT daily_class_reports_subject_session_key 
  UNIQUE (course_id, batch_id, subject_id, report_date, session_type);

-- Create index on daily class reports query fields
CREATE INDEX IF NOT EXISTS idx_daily_class_reports_batch ON public.daily_class_reports(batch_id);
CREATE INDEX IF NOT EXISTS idx_daily_class_reports_subject ON public.daily_class_reports(subject_id);
CREATE INDEX IF NOT EXISTS idx_daily_class_reports_date ON public.daily_class_reports(report_date);

-- 2. Create Daily Student Reports Table
CREATE TABLE IF NOT EXISTS public.daily_student_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_report_id UUID NOT NULL REFERENCES public.daily_class_reports(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  status          TEXT NOT NULL CHECK (status IN ('normal', 'need_improvement')),
  comment         TEXT,
  behavior_rating   TEXT DEFAULT 'Needs Imp.',
  study_engagement  TEXT DEFAULT 'Active',
  homework_status   TEXT DEFAULT 'Completed',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE (daily_report_id, student_id)
);

-- Ensure ratings columns exist if table already existed
ALTER TABLE public.daily_student_reports ADD COLUMN IF NOT EXISTS behavior_rating TEXT DEFAULT 'Needs Imp.';
ALTER TABLE public.daily_student_reports ADD COLUMN IF NOT EXISTS study_engagement TEXT DEFAULT 'Active';
ALTER TABLE public.daily_student_reports ADD COLUMN IF NOT EXISTS homework_status TEXT DEFAULT 'Completed';

-- Create index on daily student reports query fields
CREATE INDEX IF NOT EXISTS idx_daily_student_reports_report ON public.daily_student_reports(daily_report_id);
CREATE INDEX IF NOT EXISTS idx_daily_student_reports_student ON public.daily_student_reports(student_id);

-- 3. Enable RLS and define permissive policies for authenticated users
ALTER TABLE public.daily_class_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_student_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_select_daily_class_reports" ON public.daily_class_reports;
CREATE POLICY "auth_select_daily_class_reports" ON public.daily_class_reports
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "auth_all_daily_class_reports" ON public.daily_class_reports;
CREATE POLICY "auth_all_daily_class_reports" ON public.daily_class_reports
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_select_daily_student_reports" ON public.daily_student_reports;
CREATE POLICY "auth_select_daily_student_reports" ON public.daily_student_reports
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "auth_all_daily_student_reports" ON public.daily_student_reports;
CREATE POLICY "auth_all_daily_student_reports" ON public.daily_student_reports
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 4. Create trigger to notify parent of Need Improvement students
CREATE OR REPLACE FUNCTION notify_parent_on_need_improvement()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_parent_id    UUID;
  v_student_name TEXT;
  v_notif_id     UUID;
  v_title        TEXT;
  v_message      TEXT;
BEGIN
  -- Only act on 'need_improvement' status
  IF NEW.status <> 'need_improvement' THEN
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

  -- Build notification text
  v_title   := 'Academic Improvement Required';
  v_message := v_student_name || ' requires additional attention in today''s class. Open the app to view teacher remarks.';

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
      NULL; -- Never let FCM failures block report saving
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_daily_student_reports_notify ON public.daily_student_reports;
CREATE TRIGGER trg_daily_student_reports_notify
  AFTER INSERT OR UPDATE
  ON public.daily_student_reports
  FOR EACH ROW
  EXECUTE FUNCTION notify_parent_on_need_improvement();

-- 5. Migrate existing data from student_daily_reports to new daily_class_reports & daily_student_reports
DO $$
DECLARE
  r RECORD;
  new_report_id UUID;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_daily_reports') THEN
    FOR r IN 
      SELECT sdr.*, s.course_id as student_course_id, s.batch_id as student_batch_id
      FROM public.student_daily_reports sdr
      JOIN public.students s ON s.id = sdr.student_id
    LOOP
      -- Check if we already created a daily_class_report for this combination
      SELECT id INTO new_report_id 
      FROM public.daily_class_reports
      WHERE course_id = r.student_course_id 
        AND batch_id = r.student_batch_id 
        AND ((r.subject_id IS NULL AND subject_id IS NULL) OR (r.subject_id = subject_id))
        AND report_date = r.date_str
        AND session_type = 'forenoon'; -- default to forenoon for migrated reports
      
      IF new_report_id IS NULL THEN
        -- Insert daily class report
        INSERT INTO public.daily_class_reports (
          teacher_id, course_id, batch_id, subject_id, report_date, session_type, topics_covered, homework, general_remarks, created_at
        ) VALUES (
          r.teacher_id,
          r.student_course_id,
          r.student_batch_id,
          r.subject_id,
          r.date_str,
          'forenoon',
          COALESCE(r.remarks, 'Migrated Daily Class Report'),
          NULL,
          NULL,
          r.created_at
        ) RETURNING id INTO new_report_id;
      END IF;

      -- Insert student report details
      INSERT INTO public.daily_student_reports (
        daily_report_id, student_id, status, comment, created_at,
        behavior_rating, study_engagement, homework_status
      ) VALUES (
        new_report_id,
        r.student_id,
        CASE WHEN r.behavior_rating = 'Needs Imp.' OR r.behavior_rating = 'Poor' THEN 'need_improvement' ELSE 'normal' END,
        r.remarks,
        r.created_at,
        r.behavior_rating,
        r.study_engagement,
        r.homework_status
      ) ON CONFLICT (daily_report_id, student_id) DO NOTHING;
    END LOOP;
  END IF;
END $$;
