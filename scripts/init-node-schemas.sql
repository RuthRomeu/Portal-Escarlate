-- Schemas do backend Node.js aplicados no banco portal_escarlate.
-- Executado automaticamente pelo PostgreSQL na primeira inicialização
-- do volume (docker-entrypoint-initdb.d).

\connect portal_escarlate

-- auth
CREATE TABLE IF NOT EXISTS users_2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password text NOT NULL,
  role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS users_2_email_idx ON users_2(email);
CREATE INDEX IF NOT EXISTS users_2_role_idx ON users_2(role);

-- registration
CREATE TABLE IF NOT EXISTS email_verification_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  password_hash text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS email_verification_tokens_email_idx ON email_verification_tokens(email);
CREATE INDEX IF NOT EXISTS email_verification_tokens_token_hash_idx ON email_verification_tokens(token_hash);
CREATE INDEX IF NOT EXISTS email_verification_tokens_expires_at_idx ON email_verification_tokens(expires_at);

-- password-recovery
CREATE TABLE IF NOT EXISTS password_recovery_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS password_recovery_tokens_email_idx ON password_recovery_tokens(email);
CREATE INDEX IF NOT EXISTS password_recovery_tokens_token_hash_idx ON password_recovery_tokens(token_hash);
CREATE INDEX IF NOT EXISTS password_recovery_tokens_expires_at_idx ON password_recovery_tokens(expires_at);

-- email
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
CREATE INDEX IF NOT EXISTS email_connections_active_idx ON email_connections(active, priority);
CREATE INDEX IF NOT EXISTS email_connections_email_idx ON email_connections(email);

-- news
CREATE TABLE IF NOT EXISTS news_api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'newsapi',
  api_key text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 100,
  last_failure_at timestamptz,
  last_failure_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS news_search_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_email text NOT NULL,
  query text NOT NULL,
  total_results integer NOT NULL DEFAULT 0,
  theme_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS news_search_history_user_email_idx ON news_search_history(user_email);
CREATE INDEX IF NOT EXISTS news_search_history_created_at_idx ON news_search_history(created_at DESC);
CREATE INDEX IF NOT EXISTS news_search_history_theme_id_idx ON news_search_history(theme_id);
CREATE TABLE IF NOT EXISTS news_search_themes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS news_search_themes_key_idx ON news_search_themes(key);

-- ai
CREATE TABLE IF NOT EXISTS ai_api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'openrouter',
  label text NOT NULL,
  api_key text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS ai_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id uuid NOT NULL REFERENCES ai_api_keys(id) ON DELETE CASCADE,
  model text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_models_api_key_id_idx ON ai_models(api_key_id);
CREATE INDEX IF NOT EXISTS ai_models_active_idx ON ai_models(active, priority);

-- article-summary
CREATE TABLE IF NOT EXISTS news_article_summaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  url text NOT NULL,
  normalized_url text NOT NULL UNIQUE,
  title text NOT NULL,
  author text,
  source text,
  published_at timestamptz,
  url_to_image text,
  summary text NOT NULL,
  provider text NOT NULL DEFAULT '',
  model text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS news_article_summaries_normalized_url_idx ON news_article_summaries(normalized_url);
