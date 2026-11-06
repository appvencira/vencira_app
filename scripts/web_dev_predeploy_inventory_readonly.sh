#!/usr/bin/env bash
# Inventory ONLY. No compose up/build, DB writes, credentials or deploy.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "WEB_DEV_INVENTORY_MODE=READ_ONLY"
echo "WEB_DEV_SOURCE_HEAD=$(git rev-parse --short HEAD)"
echo "WEB_DEV_SOURCE_BRANCH=$(git branch --show-current)"
for name in vencira_localcheck-web_preview-1 vencira_localcheck-api-1 vencira_localcheck-db-1; do
  if sudo docker container inspect "$name" >/dev/null 2>&1; then
    echo "WEB_DEV_CONTAINER=$name"
    sudo docker inspect "$name" --format 'WEB_DEV_STATE={{.State.Status}} WEB_DEV_HEALTH={{if .State.Health}}{{.State.Health.Status}}{{else}}NOT_CONFIGURED{{end}} WEB_DEV_IMAGE_ID={{.Image}} WEB_DEV_COMPOSE_PROJECT={{index .Config.Labels "com.docker.compose.project"}}'
  else
    echo "WEB_DEV_CONTAINER_MISSING=$name"
  fi
done
if sudo docker container inspect vencira_localcheck-web_preview-1 >/dev/null 2>&1; then
  image="$(sudo docker inspect -f '{{.Image}}' vencira_localcheck-web_preview-1)"
  if sudo docker image inspect "$image" >/dev/null 2>&1; then
    echo "WEB_DEV_PREVIOUS_WEB_IMAGE_RECOVERABLE=YES"
  else
    echo "WEB_DEV_PREVIOUS_WEB_IMAGE_RECOVERABLE=NO"
  fi
fi
# GET checks are required for Django /api/health/ (HEAD can legitimately be 405).
# Capture only status codes: never output headers, cookies or response bodies.
for url in http://127.0.0.1:18732/ http://127.0.0.1:18731/api/health/; do
  if result="$(curl --noproxy '*' -sS --max-time 8 -o /dev/null -w '%{http_code}' "$url")"; then
    echo "WEB_DEV_LOCAL_HTTP_STATUS=$url:$result"
  else
    echo "WEB_DEV_LOCAL_HTTP_STATUS=$url:UNREACHABLE"
  fi
done
for path in /home/vencira/vencira-localcheck /home/vencira/vencira-m3-localcheck; do
  if [ -d "$path/.git" ]; then
    printf 'WEB_DEV_CHECKOUT=%s HEAD=' "$path"
    git -C "$path" rev-parse --short HEAD
    printf 'WEB_DEV_CHECKOUT_BRANCH=%s:' "$path"
    git -C "$path" branch --show-current
    printf 'WEB_DEV_CHECKOUT_DIRTY_COUNT=%s:' "$path"
    git -C "$path" status --porcelain --untracked-files=no | wc -l
  fi
done
if command -v systemctl >/dev/null; then
  for service in vencira-o5-backup.timer vencira-o5-health.timer; do
    if systemctl is-active --quiet "$service"; then
      echo "WEB_DEV_TIMER_$service=ACTIVE"
    else
      echo "WEB_DEV_TIMER_$service=NOT_ACTIVE"
    fi
  done
fi
# Read-only migration gate inside existing service; no database/schema writes.
if sudo docker container inspect vencira_localcheck-api-1 >/dev/null 2>&1; then
  if sudo docker exec vencira_localcheck-api-1 python manage.py migrate --check --noinput >/dev/null 2>&1; then
    echo "WEB_DEV_API_SCHEMA_CHECK_ONLY=OK"
  else
    echo "WEB_DEV_API_SCHEMA_CHECK_ONLY=FAIL"
  fi
fi
echo "WEB_DEV_BASELINE_READONLY=COMPLETE"
echo "WEB_DEV_DEPLOY_EXECUTED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
