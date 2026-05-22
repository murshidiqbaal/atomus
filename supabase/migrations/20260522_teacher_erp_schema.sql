-- ============================================================
-- Teacher ERP Schema Migration
-- 2026-05-22
-- ============================================================

-- ── 1. Add coordinates to campuses (if not already present) ──
ALTER TABLE campuses
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geofence_radius_meters INTEGER DEFAULT 25;

-- ── 2. Teacher attendance table ──────────────────────────────
CREATE TABLE IF NOT EXISTS teacher_attendance (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id              UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  campus_id               UUID REFERENCES campuses(id),
  subject_id              UUID REFERENCES subjects(id),
  course_id               UUID REFERENCES courses(id),
  batch_id                UUID REFERENCES batches(id),
  attendance_date         DATE NOT NULL DEFAULT CURRENT_DATE,
  start_time              TIMESTAMPTZ,
  end_time                TIMESTAMPTZ,
  total_duration_minutes  INTEGER GENERATED ALWAYS AS (
    CASE
      WHEN end_time IS NOT NULL AND start_time IS NOT NULL
      THEN EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER / 60
      ELSE NULL
    END
  ) STORED,
  latitude                DOUBLE PRECISION,
  longitude               DOUBLE PRECISION,
  attendance_status       TEXT NOT NULL DEFAULT 'Active'
                            CHECK (attendance_status IN ('Active','Completed','Missed')),
  created_at              TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (teacher_id, attendance_date, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_att_teacher  ON teacher_attendance(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_att_date     ON teacher_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_teacher_att_status   ON teacher_attendance(attendance_status);
CREATE INDEX IF NOT EXISTS idx_teacher_att_campus   ON teacher_attendance(campus_id);

-- ── 3. Student daily attendance (one record per student/subject/day) ─
-- (Only add if attendance table does not have a "status" column already)
ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Present'
    CHECK (status IN ('Present','Absent','Late','Leave')),
  ADD COLUMN IF NOT EXISTS marked_by UUID REFERENCES teachers(id),
  ADD COLUMN IF NOT EXISTS marked_at TIMESTAMPTZ DEFAULT NOW();

-- ── 4. FCM token for teachers ──────────────────────────────────
ALTER TABLE teachers
  ADD COLUMN IF NOT EXISTS fcm_token   TEXT,
  ADD COLUMN IF NOT EXISTS last_active TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_active   BOOLEAN DEFAULT TRUE;

-- ── 5. teacher_subjects linking table (if not exists) ──────────
CREATE TABLE IF NOT EXISTS teacher_subjects (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  course_id  UUID REFERENCES courses(id),
  batch_id   UUID REFERENCES batches(id),
  campus_id  UUID REFERENCES campuses(id),
  is_active  BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (teacher_id, subject_id, batch_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_subj_teacher ON teacher_subjects(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_subj_subject ON teacher_subjects(subject_id);

-- ── 6. teacher_batches linking table (if not exists) ───────────
CREATE TABLE IF NOT EXISTS teacher_batches (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  batch_id   UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  course_id  UUID REFERENCES courses(id),
  campus_id  UUID REFERENCES campuses(id),
  is_active  BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (teacher_id, batch_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_batch_teacher ON teacher_batches(teacher_id);

-- ── 7. Pending sync queue for offline attendance ────────────────
CREATE TABLE IF NOT EXISTS pending_attendance_sync (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id     UUID NOT NULL,
  payload        JSONB NOT NULL,
  sync_type      TEXT NOT NULL CHECK (sync_type IN ('teacher_attendance','student_attendance')),
  is_synced      BOOLEAN DEFAULT FALSE,
  sync_attempts  INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  synced_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_pending_sync_teacher   ON pending_attendance_sync(teacher_id);
CREATE INDEX IF NOT EXISTS idx_pending_sync_unsynced  ON pending_attendance_sync(is_synced) WHERE is_synced = FALSE;
