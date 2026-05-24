-- ============================================================
-- Marks Uniqueness Migration
-- 2026-05-24
-- ============================================================

-- 1. De-duplicate existing marks records, keeping only the latest one per student, exam, and subject.
DELETE FROM public.marks m
WHERE m.id NOT IN (
  SELECT DISTINCT ON (exam_id, student_id, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid)) id
  FROM public.marks
  ORDER BY exam_id, student_id, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid), created_at DESC NULLS LAST
);

-- 2. Drop old index
DROP INDEX IF EXISTS public.marks_exam_student_subject_date_uidx;

-- 3. Create unique constraint using NULLS NOT DISTINCT on (exam_id, student_id, subject_id)
-- This ensures uniqueness even when subject_id is null (e.g. course-wide exams).
ALTER TABLE public.marks
  ADD CONSTRAINT marks_exam_student_subject_uq
  UNIQUE NULLS NOT DISTINCT (exam_id, student_id, subject_id);
