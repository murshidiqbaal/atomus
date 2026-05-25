-- ============================================================
-- Atomus -- Daily Exams System
-- ============================================================
-- A daily exam (exams.is_daily = true) is a REUSABLE TEMPLATE:
--   * Visible every day, regardless of exams.exam_date.
--   * Each day's marks are written into `marks` with a new
--     mark_date value, NOT by inserting a fresh exam row.
-- A regular exam (is_daily = false) keeps the old semantics --
-- visible only on its exam_date.
-- ============================================================

-- 1. mark_date column on marks ------------------------------------
-- The day this mark applies to. Defaults to CURRENT_DATE so older
-- code paths that don't pass mark_date still record a sensible
-- value.
ALTER TABLE public.marks
  ADD COLUMN IF NOT EXISTS mark_date DATE NOT NULL DEFAULT CURRENT_DATE;

-- Backfill: any pre-existing row gets mark_date = created_at::date
UPDATE public.marks
   SET mark_date = created_at::date
 WHERE mark_date IS NULL
    OR mark_date = CURRENT_DATE; -- (default applied during ADD COLUMN)

-- 2. Replace the old uniqueness rule ------------------------------
-- Old rule: one row per (exam_id, student_id, subject_id).
-- New rule: one row per (exam_id, student_id, subject_id, mark_date)
-- so a daily exam can hold one row per day per student.
-- Drop common names defensively in case the rule was created via
-- different generators.
ALTER TABLE public.marks
  DROP CONSTRAINT IF EXISTS marks_exam_id_student_id_subject_id_key;
DROP INDEX IF EXISTS public.marks_exam_student_subject_uidx;
DROP INDEX IF EXISTS public.marks_exam_id_student_id_subject_id_idx;

CREATE UNIQUE INDEX IF NOT EXISTS marks_exam_student_subject_date_uidx
  ON public.marks (
    exam_id,
    student_id,
    COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid),
    mark_date
  );

CREATE INDEX IF NOT EXISTS idx_marks_mark_date ON public.marks(mark_date);

-- 3. Helper view (optional, for analytics) ------------------------
-- Daily-exam roll-up: per (exam, mark_date, subject) -> avg, count.
CREATE OR REPLACE VIEW public.v_daily_exam_summary AS
SELECT
  m.exam_id,
  m.subject_id,
  m.mark_date,
  COUNT(*)                          AS student_count,
  ROUND(AVG(m.marks_obtained), 2)   AS avg_marks,
  MIN(m.marks_obtained)             AS min_marks,
  MAX(m.marks_obtained)             AS max_marks
FROM public.marks m
JOIN public.exams e ON e.id = m.exam_id
WHERE e.is_daily = TRUE
GROUP BY m.exam_id, m.subject_id, m.mark_date;

-- ============================================================
-- USAGE NOTES (client-side)
--   * Exam fetch filter:
--       WHERE is_daily = TRUE
--          OR (is_daily = FALSE AND exam_date = CURRENT_DATE)
--   * Marks upsert:
--       onConflict: "exam_id,student_id,subject_id,mark_date"
-- ============================================================
