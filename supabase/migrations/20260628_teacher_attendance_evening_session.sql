-- ============================================================
-- Teacher Attendance & Daily Class Reports Evening Session Migration
-- ============================================================

-- 1. Drop existing session_type check constraints from teacher_attendance and daily_class_reports
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
          AND rel.relname = 'teacher_attendance'
          AND con.contype = 'c'
          AND con.consrc LIKE '%session_type%'
    LOOP
        EXECUTE 'ALTER TABLE public.teacher_attendance DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
END $$;

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
          AND rel.relname = 'daily_class_reports'
          AND con.contype = 'c'
          AND con.consrc LIKE '%session_type%'
    LOOP
        EXECUTE 'ALTER TABLE public.daily_class_reports DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
END $$;

-- 2. Add updated session_type check constraints allowing 'evening'
ALTER TABLE public.teacher_attendance
  ADD CONSTRAINT teacher_attendance_session_type_check
  CHECK (session_type IN ('forenoon', 'afternoon', 'evening'));

ALTER TABLE public.daily_class_reports
  ADD CONSTRAINT daily_class_reports_session_type_check
  CHECK (session_type IN ('forenoon', 'afternoon', 'evening'));
