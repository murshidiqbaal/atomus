-- ============================================================
-- Teacher Session Type and Constraints Migration
-- ============================================================

-- 1. Add session_type column if it does not exist
ALTER TABLE public.teacher_attendance 
  ADD COLUMN IF NOT EXISTS session_type TEXT DEFAULT 'forenoon' CHECK (session_type IN ('forenoon', 'afternoon'));

-- 2. Drop old unique constraint
ALTER TABLE public.teacher_attendance 
  DROP CONSTRAINT IF EXISTS teacher_attendance_teacher_id_attendance_date_subject_id_key;

-- 3. Add new unique constraint on (teacher_id, attendance_date, session_type)
ALTER TABLE public.teacher_attendance
  ADD CONSTRAINT teacher_attendance_teacher_date_session_uq
  UNIQUE (teacher_id, attendance_date, session_type);
