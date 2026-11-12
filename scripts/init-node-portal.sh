#!/bin/bash
# Aplica os schemas do backend Node.js no banco portal_escarlate.
# Executado pelo PostgreSQL no primeiro boot (docker-entrypoint-initdb.d).
set -e

PSQL="psql -U $POSTGRES_USER -d portal_escarlate"

for f in auth.sql registrar.sql password-recovery.sql email.sql news.sql ai.sql article-summary.sql; do
  echo "[init] Aplicando $f em portal_escarlate..."
  $PSQL -f "/docker-entrypoint-initdb.d/$f"
done

echo "[init] Schemas do Node.js aplicados com sucesso."
