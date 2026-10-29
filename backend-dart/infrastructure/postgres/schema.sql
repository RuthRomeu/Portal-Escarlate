-- Inicialização local: executada APENAS quando o volume PostgreSQL é novo.
-- Em instalações existentes, aplicar migrações versionadas separadamente.

\connect auth_db
CREATE TABLE IF NOT EXISTS users_2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password text NOT NULL,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS users_2_role_idx ON users_2(role);
CREATE TABLE IF NOT EXISTS event_outbox (
  event_id uuid PRIMARY KEY,
  type text NOT NULL,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);
CREATE INDEX IF NOT EXISTS auth_outbox_pending_idx
  ON event_outbox(occurred_at) WHERE published_at IS NULL;

\connect registration_db
CREATE TABLE IF NOT EXISTS email_verification_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  password_hash text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS registration_tokens_email_idx
  ON email_verification_tokens(email);
CREATE INDEX IF NOT EXISTS registration_tokens_expiry_idx
  ON email_verification_tokens(expires_at);
CREATE TABLE IF NOT EXISTS event_outbox (
  event_id uuid PRIMARY KEY,
  type text NOT NULL,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);
CREATE INDEX IF NOT EXISTS registration_outbox_pending_idx
  ON event_outbox(occurred_at) WHERE published_at IS NULL;

\connect password_recovery_db
CREATE TABLE IF NOT EXISTS password_recovery_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS recovery_tokens_email_idx
  ON password_recovery_tokens(email);
CREATE INDEX IF NOT EXISTS recovery_tokens_expiry_idx
  ON password_recovery_tokens(expires_at);
CREATE TABLE IF NOT EXISTS event_outbox (
  event_id uuid PRIMARY KEY,
  type text NOT NULL,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);
CREATE INDEX IF NOT EXISTS recovery_outbox_pending_idx
  ON event_outbox(occurred_at) WHERE published_at IS NULL;

\connect email_db
CREATE TABLE IF NOT EXISTS email_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'gmail',
  email text NOT NULL UNIQUE,
  refresh_token text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS email_connections_priority_idx
  ON email_connections(active, priority, created_at);
CREATE TABLE IF NOT EXISTS event_outbox (
  event_id uuid PRIMARY KEY,
  type text NOT NULL,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);
CREATE TABLE IF NOT EXISTS event_inbox (
  event_id uuid PRIMARY KEY,
  type text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'processed')),
  claimed_until timestamptz,
  processed_at timestamptz
);
CREATE INDEX IF NOT EXISTS email_inbox_pending_idx ON event_inbox(status, claimed_until);
CREATE INDEX IF NOT EXISTS email_outbox_pending_idx
  ON event_outbox(occurred_at) WHERE published_at IS NULL;
