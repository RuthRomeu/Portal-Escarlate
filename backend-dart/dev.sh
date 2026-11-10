#!/usr/bin/env bash
# =============================================================================
# dev.sh — Roda um microsserviço Dart carregando o .env automaticamente
#
# Uso:
#   ./dev.sh <nome_do_servico>
#
# Exemplos:
#   ./dev.sh ai_service
#   ./dev.sh auth_service
#   ./dev.sh news_service
#   ./dev.sh api_gateway
#
# Sem argumento, lista os serviços disponíveis.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# ---------------------------------------------------------------------------
# Carregar .env
# ---------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo .env não encontrado em: $ENV_FILE"
  echo "   Copie o .env.example e preencha os valores."
  exit 1
fi

# Exporta todas as variáveis do .env (ignora comentários e linhas vazias)
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

echo "Variáveis carregadas de $ENV_FILE"

# ---------------------------------------------------------------------------
# Argumento: nome do serviço
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  echo ""
  echo "Uso: ./dev.sh <nome_do_servico>"
  echo ""
  echo "Serviços disponíveis:"
  for dir in "$SCRIPT_DIR/apps"/*/; do
    echo "  - $(basename "$dir")"
  done
  echo ""
  exit 0
fi

SERVICE="$1"
SERVICE_PATH="$SCRIPT_DIR/apps/$SERVICE"

if [[ ! -d "$SERVICE_PATH" ]]; then
  echo "Serviço '$SERVICE' não encontrado em apps/"
  echo ""
  echo "Serviços disponíveis:"
  for dir in "$SCRIPT_DIR/apps"/*/; do
    echo "  - $(basename "$dir")"
  done
  exit 1
fi

ENTRY_POINT="$SERVICE_PATH/bin/main.dart"
if [[ ! -f "$ENTRY_POINT" ]]; then
  echo "Entry point não encontrado: $ENTRY_POINT"
  exit 1
fi

# ---------------------------------------------------------------------------
# Rodar
# ---------------------------------------------------------------------------
echo "Iniciando $SERVICE..."
echo ""

cd "$SCRIPT_DIR"
exec dart run "apps/$SERVICE/bin/main.dart"