#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -p vencira_preview -f compose.yaml -f compose.preview.yaml down
echo "VENCIRA preview detenida. Volumen de PostgreSQL conservado."
