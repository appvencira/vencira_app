#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -p vencira_preview -f compose.yaml -f compose.preview.yaml exec -T api python manage.py seed_preview
