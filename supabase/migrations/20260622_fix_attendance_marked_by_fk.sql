-- ============================================================
-- Fix: attendance.marked_by FK now references auth.users(id)
-- instead of teachers(id) so admins can mark attendance.
-- 2026-06-22
-- ============================================================

-- 1. Drop the old FK constraint on marked_by → teachers(id)
--    The constraint name was auto-generated; find and drop it dynamically.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = ANY(con.conkey)
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'attendance'
          AND con.contype = 'f'            -- foreign key
          AND att.attname = 'marked_by'
    LOOP
        EXECUTE 'ALTER TABLE public.attendance DROP CONSTRAINT ' || quote_ident(r.conname);
        RAISE NOTICE 'Dropped FK constraint: %', r.conname;
    END LOOP;
END $$;

-- 2. Add new FK referencing auth.users(id) with ON DELETE SET NULL
--    This allows both teacher IDs (who are also auth users) and admin
--    auth user IDs to be stored in marked_by.
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_marked_by_auth_users_fk
  FOREIGN KEY (marked_by) REFERENCES auth.users(id)
  ON DELETE SET NULL;
