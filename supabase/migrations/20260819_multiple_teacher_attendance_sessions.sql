-- ============================================================
-- Migration: Multiple Teacher Attendance Sessions Per Day
-- Date: 2026-08-19
-- ============================================================

-- 1. Add extra location & timestamp columns if not existing
ALTER TABLE public.teacher_attendance
  ADD COLUMN IF NOT EXISTS punch_out_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS punch_out_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS punch_in_location TEXT,
  ADD COLUMN IF NOT EXISTS punch_out_location TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Make session_type nullable and without restrictive check constraints
ALTER TABLE public.teacher_attendance
  ALTER COLUMN session_type DROP NOT NULL;

-- 2. Drop ALL legacy check & unique constraints restricting sessions or session_type
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
          AND con.contype IN ('u', 'c')
          AND (
            conname LIKE '%session_type%' 
            OR conname LIKE '%session%' 
            OR conname LIKE '%date%' 
            OR conname LIKE '%subject%'
            OR conname LIKE '%unique%'
            OR conname LIKE '%key%'
          )
          AND conname NOT LIKE '%pkey%'
    LOOP
        EXECUTE 'ALTER TABLE public.teacher_attendance DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
    END LOOP;
END $$;

-- 3. Create Partial Unique Index:
-- Enforces AT MOST ONE OPEN SESSION per teacher at any given time.
-- An open session is identified by `end_time IS NULL` and `attendance_status = 'Active'`.
DROP INDEX IF EXISTS public.idx_one_open_teacher_attendance_session;
CREATE UNIQUE INDEX idx_one_open_teacher_attendance_session
  ON public.teacher_attendance (teacher_id)
  WHERE end_time IS NULL AND attendance_status = 'Active';

-- Index for fast daily query of teacher sessions
CREATE INDEX IF NOT EXISTS idx_teacher_att_teacher_date
  ON public.teacher_attendance (teacher_id, attendance_date, start_time);

-- 4. Atomic Punch-In Function
CREATE OR REPLACE FUNCTION public.fn_teacher_punch_in(
  p_teacher_id UUID,
  p_campus_id UUID DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_course_id UUID DEFAULT NULL,
  p_batch_id UUID DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_location TEXT DEFAULT NULL
)
RETURNS SETOF public.teacher_attendance
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_open_count INT;
  v_new_session public.teacher_attendance%ROWTYPE;
BEGIN
  -- Check for existing open session
  SELECT COUNT(*) INTO v_open_count
  FROM public.teacher_attendance
  WHERE teacher_id = p_teacher_id
    AND end_time IS NULL
    AND attendance_status = 'Active';

  IF v_open_count > 0 THEN
    RAISE EXCEPTION 'OPEN_SESSION_EXISTS: You already have an active attendance session. Please punch out before starting another session.';
  END IF;

  -- Insert new session using server NOW() and current date in UTC / local
  INSERT INTO public.teacher_attendance (
    teacher_id,
    campus_id,
    subject_id,
    course_id,
    batch_id,
    attendance_date,
    start_time,
    end_time,
    latitude,
    longitude,
    punch_in_location,
    attendance_status,
    session_type,
    created_at,
    updated_at
  ) VALUES (
    p_teacher_id,
    p_campus_id,
    p_subject_id,
    p_course_id,
    p_batch_id,
    (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE,
    NOW(),
    NULL,
    p_latitude,
    p_longitude,
    p_location,
    'Active',
    'session',
    NOW(),
    NOW()
  )
  RETURNING * INTO v_new_session;

  RETURN NEXT v_new_session;
END;
$$;

-- 5. Atomic Punch-Out Function
CREATE OR REPLACE FUNCTION public.fn_teacher_punch_out(
  p_teacher_id UUID,
  p_session_id UUID DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_location TEXT DEFAULT NULL
)
RETURNS SETOF public.teacher_attendance
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_id UUID;
  v_updated_session public.teacher_attendance%ROWTYPE;
BEGIN
  -- Resolve session ID if not explicitly passed
  IF p_session_id IS NOT NULL THEN
    v_session_id := p_session_id;
  ELSE
    SELECT id INTO v_session_id
    FROM public.teacher_attendance
    WHERE teacher_id = p_teacher_id
      AND end_time IS NULL
      AND attendance_status = 'Active'
    ORDER BY start_time DESC
    LIMIT 1;
  END IF;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'NO_ACTIVE_SESSION: No open attendance session found to punch out.';
  END IF;

  -- Update session row atomically
  UPDATE public.teacher_attendance
  SET
    end_time = NOW(),
    punch_out_latitude = p_latitude,
    punch_out_longitude = p_longitude,
    punch_out_location = p_location,
    attendance_status = 'Completed',
    updated_at = NOW()
  WHERE id = v_session_id
  RETURNING * INTO v_updated_session;

  RETURN NEXT v_updated_session;
END;
$$;
