-- ============================================================
-- Parent Daily App Open Tracking Schema
-- 2026-07-02
-- ============================================================

-- 1. Create parent_daily_app_opens table
CREATE TABLE IF NOT EXISTS public.parent_daily_app_opens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id       UUID NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE,
  student_id      UUID REFERENCES public.students(id) ON DELETE SET NULL,
  campus_id       UUID REFERENCES public.campuses(id) ON DELETE SET NULL,
  course_id       UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  batch_id        UUID REFERENCES public.batches(id) ON DELETE SET NULL,
  open_date       DATE NOT NULL DEFAULT CURRENT_DATE,
  first_opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_opened_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  open_count      INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Ensure only one record exists per parent per day
  CONSTRAINT unique_parent_daily_open UNIQUE (parent_id, open_date)
);

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_parent_daily_opens_parent ON public.parent_daily_app_opens(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_daily_opens_date ON public.parent_daily_app_opens(open_date);
CREATE INDEX IF NOT EXISTS idx_parent_daily_opens_campus ON public.parent_daily_app_opens(campus_id);
CREATE INDEX IF NOT EXISTS idx_parent_daily_opens_course ON public.parent_daily_app_opens(course_id);
CREATE INDEX IF NOT EXISTS idx_parent_daily_opens_batch ON public.parent_daily_app_opens(batch_id);

-- 3. Enable RLS
ALTER TABLE public.parent_daily_app_opens ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Policy 1: Parents can read their own activity records
DROP POLICY IF EXISTS "parents_select_own_activity" ON public.parent_daily_app_opens;
CREATE POLICY "parents_select_own_activity" ON public.parent_daily_app_opens
  FOR SELECT TO authenticated
  USING (auth.uid() = parent_id);

-- Policy 2: Parents can insert their own activity records
DROP POLICY IF EXISTS "parents_insert_own_activity" ON public.parent_daily_app_opens;
CREATE POLICY "parents_insert_own_activity" ON public.parent_daily_app_opens
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = parent_id);

-- Policy 3: Parents can update their own activity records
DROP POLICY IF EXISTS "parents_update_own_activity" ON public.parent_daily_app_opens;
CREATE POLICY "parents_update_own_activity" ON public.parent_daily_app_opens
  FOR UPDATE TO authenticated
  USING (auth.uid() = parent_id)
  WITH CHECK (auth.uid() = parent_id);

-- Policy 4: Teachers/Admins can read all activity records for reporting
DROP POLICY IF EXISTS "teachers_select_all_activity" ON public.parent_daily_app_opens;
CREATE POLICY "teachers_select_all_activity" ON public.parent_daily_app_opens
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.teachers WHERE id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.device_tokens WHERE user_id = auth.uid() AND user_type = 'admin'
    )
  );
