-- Parent profile management needs an editable address on the existing table.
-- This keeps profile data in public.parents and avoids creating side tables.

ALTER TABLE public.parents
  ADD COLUMN IF NOT EXISTS address TEXT;
