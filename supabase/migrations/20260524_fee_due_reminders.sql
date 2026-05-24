-- ============================================================
-- Atomus Fee Due Date Reminders -- run in Supabase SQL Editor
-- Sends a parent notification 10 days before any unpaid fee is due.
-- Complements 20260516_notification_system.sql (absence alerts).
-- ============================================================

-- 1. Dedup: at most one fees-reminder per (student, fee, fired_date)
-- ------------------------------------------------------------
-- We piggyback on the existing notifications table. The unique
-- constraint guarantees that re-running the job on the same day
-- (or running it multiple times for the same fee) is a no-op.
CREATE TABLE IF NOT EXISTS public.fee_reminders_sent (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fee_id       UUID NOT NULL,
  student_id   UUID NOT NULL,
  reminder_for DATE NOT NULL,           -- the fee's due_date
  fired_on     DATE NOT NULL DEFAULT CURRENT_DATE,
  notification_id UUID,
  UNIQUE (fee_id, reminder_for)
);

CREATE INDEX IF NOT EXISTS fee_reminders_fired_idx
  ON public.fee_reminders_sent(fired_on);


-- 2. Core function -- scans fees and fires the notification
-- ------------------------------------------------------------
-- Fires for every unpaid fee whose due_date is exactly CURRENT_DATE + 10.
-- Idempotent: dedup table prevents duplicate inserts.
CREATE OR REPLACE FUNCTION public.notify_parents_of_upcoming_fees()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_target_date  DATE := CURRENT_DATE + INTERVAL '10 days';
  v_fee          RECORD;
  v_parent_id    UUID;
  v_student_name TEXT;
  v_notif_id     UUID;
  v_title        TEXT;
  v_message      TEXT;
  v_count        INTEGER := 0;
BEGIN
  FOR v_fee IN
    SELECT f.id            AS fee_id,
           f.student_id    AS student_id,
           f.amount_due    AS amount_due,
           f.amount_paid   AS amount_paid,
           f.due_date      AS due_date,
           f.payment_status AS payment_status
      FROM public.fees f
     WHERE DATE(f.due_date) = v_target_date
       AND COALESCE(f.payment_status, 'Pending') <> 'Paid'
       AND COALESCE(f.amount_due, 0) > COALESCE(f.amount_paid, 0)
  LOOP
    -- Skip if a reminder for this fee+date was already fired
    IF EXISTS (
      SELECT 1 FROM public.fee_reminders_sent
       WHERE fee_id = v_fee.fee_id
         AND reminder_for = v_fee.due_date
    ) THEN
      CONTINUE;
    END IF;

    -- Lookup parent + student name
    SELECT s.parent_id, s.full_name
      INTO v_parent_id, v_student_name
      FROM public.students s
     WHERE s.id = v_fee.student_id;

    IF v_parent_id IS NULL THEN
      CONTINUE;
    END IF;

    v_title := 'Fee Due in 10 Days';
    v_message := COALESCE(v_student_name, 'Your child')
      || '''s fee of '
      || TO_CHAR(GREATEST(v_fee.amount_due - COALESCE(v_fee.amount_paid, 0), 0), 'FM999G999G990D00')
      || ' is due on '
      || TO_CHAR(v_fee.due_date, 'DD Mon YYYY')
      || '. Please make the payment to avoid late charges.';

    INSERT INTO public.notifications (parent_id, student_id, title, message, type)
    VALUES (v_parent_id, v_fee.student_id, v_title, v_message, 'fees')
    RETURNING id INTO v_notif_id;

    INSERT INTO public.fee_reminders_sent (fee_id, student_id, reminder_for, notification_id)
    VALUES (v_fee.fee_id, v_fee.student_id, v_fee.due_date, v_notif_id)
    ON CONFLICT (fee_id, reminder_for) DO NOTHING;

    -- Push via FCM (function defined in 20260516_notification_system.sql)
    BEGIN
      PERFORM call_send_fcm(
        v_notif_id, v_parent_id, v_fee.student_id,
        v_title, v_message, 'fees'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL; -- never let FCM failure block the reminder loop
    END;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;


-- 3. Daily schedule via pg_cron
-- ------------------------------------------------------------
-- Requires pg_cron extension. Runs every day at 09:00 UTC.
-- Adjust the time as needed for your locale.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Drop any previous job of the same name first (idempotent re-run)
DO $$
BEGIN
  PERFORM cron.unschedule('atomus_fee_due_reminder')
   WHERE EXISTS (
     SELECT 1 FROM cron.job WHERE jobname = 'atomus_fee_due_reminder'
   );
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT cron.schedule(
  'atomus_fee_due_reminder',
  '0 9 * * *',          -- every day at 09:00 UTC
  $cmd$ SELECT public.notify_parents_of_upcoming_fees(); $cmd$
);


-- ============================================================
-- USAGE
--   Manual run / test:    SELECT public.notify_parents_of_upcoming_fees();
--   Inspect last fires:   SELECT * FROM public.fee_reminders_sent
--                          ORDER BY fired_on DESC LIMIT 20;
--   Disable temporarily:  SELECT cron.unschedule('atomus_fee_due_reminder');
-- ============================================================
