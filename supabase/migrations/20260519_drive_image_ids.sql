-- Migration: Replace Supabase Storage URLs with Google Drive file IDs
-- Date: 2026-05-19
--
-- Adds Drive ID columns to all relevant tables.
-- The old URL columns are left in place (nullable) for rollback safety
-- and can be dropped after confirming all clients use the new columns.

-- students: student profile photos
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS profile_photo_drive_id TEXT;

-- parents: parent profile photos
ALTER TABLE public.parents
  ADD COLUMN IF NOT EXISTS profile_photo_drive_id TEXT;

-- teachers: teacher profile photos
ALTER TABLE public.teachers
  ADD COLUMN IF NOT EXISTS profile_photo_drive_id TEXT;

-- announcements: announcement images / posters
ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS image_drive_id TEXT;

-- courses: course thumbnail images
ALTER TABLE public.courses
  ADD COLUMN IF NOT EXISTS thumbnail_drive_id TEXT;

-- posters (if table exists): standalone poster images
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'posters'
  ) THEN
    ALTER TABLE public.posters
      ADD COLUMN IF NOT EXISTS drive_file_id TEXT;
  END IF;
END$$;

-- certificates (if table exists): certificate document images
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'certificates'
  ) THEN
    ALTER TABLE public.certificates
      ADD COLUMN IF NOT EXISTS drive_file_id TEXT;
  END IF;
END$$;
