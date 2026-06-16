-- ============================================================
-- Student Daily Reports Schema Migration
-- 2026-06-16
-- ============================================================

CREATE TABLE IF NOT EXISTS student_daily_reports (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id        UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  subject_id        UUID REFERENCES subjects(id) ON DELETE CASCADE,
  date_str          DATE NOT NULL DEFAULT CURRENT_DATE,
  behavior_rating   TEXT NOT NULL CHECK (behavior_rating IN ('Poor', 'Needs Imp.', 'Average', 'Good', 'Excellent')),
  study_engagement  TEXT NOT NULL CHECK (study_engagement IN ('Active', 'Passive', 'Distracted')),
  homework_status   TEXT NOT NULL CHECK (homework_status IN ('Completed', 'Partial', 'Not Completed', 'N/A')),
  remarks           TEXT,
  teacher_id        UUID REFERENCES teachers(id) ON DELETE SET NULL,
  teacher_name      TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure only one report per student/date when subject is null (general daily report)
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_reports_unique_null_subject
  ON student_daily_reports (student_id, date_str)
  WHERE subject_id IS NULL;

-- Ensure only one report per student/subject/date when subject is specified
CREATE UNIQUE INDEX IF NOT EXISTS idx_student_reports_unique_subject
  ON student_daily_reports (student_id, subject_id, date_str)
  WHERE subject_id IS NOT NULL;

-- Query indexing optimization
CREATE INDEX IF NOT EXISTS idx_student_reports_student ON student_daily_reports(student_id);
CREATE INDEX IF NOT EXISTS idx_student_reports_subject ON student_daily_reports(subject_id);
CREATE INDEX IF NOT EXISTS idx_student_reports_date    ON student_daily_reports(date_str);
