-- ============================================================
-- Fix Daily Exams Uniqueness Constraint
-- ============================================================

-- 1. Drop the old unique constraint that restricted one mark per (exam, student, subject) across all dates
ALTER TABLE public.marks
  DROP CONSTRAINT IF EXISTS marks_exam_student_subject_uq;

-- 2. Drop the unique index that was created previously
DROP INDEX IF EXISTS public.marks_exam_student_subject_date_uidx;

-- 3. Add a new unique constraint that scopes marks to (exam, student, subject, mark_date)
-- Using NULLS NOT DISTINCT ensures that course-wide exams (where subject_id is NULL)
-- are correctly checked for uniqueness per date without needing COALESCE.
ALTER TABLE public.marks
  ADD CONSTRAINT marks_exam_student_subject_date_uq
  UNIQUE NULLS NOT DISTINCT (exam_id, student_id, subject_id, mark_date);
