#!/usr/bin/env bash
# Ejecutar desde el servidor de pruebas con permisos propios.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077

if [[ ! -f .env ]]; then
  python3 scripts/init_env.py
fi
if ! command -v docker >/dev/null; then
  echo "Docker no está instalado; no se ha modificado nada." >&2
  exit 1
fi

COMPOSE=(docker compose -p vencira_preview -f compose.yaml -f compose.preview.yaml)
"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up --build -d
"${COMPOSE[@]}" ps
python3 scripts/smoke_same_origin.py
echo "Preview local: http://127.0.0.1:18732"
echo "Para acceder desde otro equipo usa un túnel SSH (ver docs/SERVER_PREVIEW.md)."
