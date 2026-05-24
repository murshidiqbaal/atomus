-- ============================================================
-- Attendance Uniqueness and Status Migration
-- 2026-05-24
-- ============================================================

-- 1. De-duplicate existing attendance records, keeping only the latest one per student, subject, and date.
DELETE FROM public.attendance a
WHERE a.id NOT IN (
  SELECT DISTINCT ON (student_id, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid), attendance_date) id
  FROM public.attendance
  ORDER BY student_id, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid), attendance_date, marked_at DESC NULLS LAST
);

-- 2. Drop old unique indexes or constraints if they exist
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_student_subject_date_uq;
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_student_date_uq;
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_student_subject_date_uidx;
DROP INDEX IF EXISTS public.attendance_student_subject_date_uidx;
DROP INDEX IF EXISTS public.attendance_student_date_uidx;

-- 3. Create unique constraint using NULLS NOT DISTINCT on (student_id, subject_id, attendance_date)
-- This ensures uniqueness even when subject_id is null (e.g. course-level attendance).
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_student_subject_date_uq
  UNIQUE NULLS NOT DISTINCT (student_id, subject_id, attendance_date);

-- 4. Dynamically drop any status check constraints on public.attendance
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'attendance'
          AND con.contype = 'c'
          AND con.consrc LIKE '%status%'
    LOOP
        EXECUTE 'ALTER TABLE public.attendance DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
END $$;

-- 5. Add status check constraint including 'Unmarked'
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_status_check
  CHECK (status IN ('Present', 'Absent', 'Late', 'Leave', 'Unmarked'));
