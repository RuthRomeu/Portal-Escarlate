-- Execute manualmente sobre email_db se o volume já existia antes da
-- implantação da infraestrutura. Faça backup antes de aplicar.
BEGIN;
ALTER TABLE event_inbox
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE event_inbox
  ADD COLUMN IF NOT EXISTS claimed_until timestamptz;
ALTER TABLE event_inbox ALTER COLUMN processed_at DROP NOT NULL;
ALTER TABLE event_inbox ALTER COLUMN processed_at DROP DEFAULT;
UPDATE event_inbox SET status = 'processed'
  WHERE processed_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS email_inbox_pending_idx
  ON event_inbox(status, claimed_until);
COMMIT;
