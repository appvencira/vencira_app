#!/usr/bin/env bash
# C2 readiness audit. Read-only; NEVER deploys, migrates, tags images or restarts.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
phase="START"
finish() {
  rc=$?
  trap - EXIT
  echo "C2_READINESS_PHASE=$phase"
  echo "C2_READINESS_RESULT=$rc"
  echo "NO_DEPLOY_NO_MIGRATION=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
phase="GIT"
test "$(git branch --show-current)" = "integration/local-e2e-prep"
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra"
echo "COMMIT=$(git rev-parse HEAD)"
echo "C2_GIT_CLEAN=OK"
phase="COMPOSE"
sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml config --quiet
echo "C2_COMPOSE_CONFIG=OK"
phase="CONTAINERS"
for svc in api db web_preview; do
  name="vencira_localcheck-$svc-1"
  project="$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  healthy="$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = "vencira_localcheck"
  test "$healthy" = "healthy"
  echo "C2_HEALTH_$svc=$healthy"
done
phase="API_COMMAND"
cmd="$(sudo docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}')"
case "$cmd" in *"migrate --check --noinput"*) echo "C2_API_MIGRATION_CHECK_ONLY=OK";; *) echo "C2_UNSAFE_API_COMMAND=1"; exit 2;; esac
phase="SCHEMA"
# SQL read-only; no passwords or row data exposed.
migration="$(sudo docker exec vencira_localcheck-db-1 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT name FROM django_migrations WHERE app='"'"'reminders'"'"' ORDER BY name DESC LIMIT 1;"')"
echo "C2_LATEST_REMINDERS_MIGRATION=$migration"
phase="IMAGES"
for svc in api web_preview; do
  image="$(sudo docker inspect "vencira_localcheck-$svc-1" --format '{{.Image}}')"
  sudo docker image inspect "$image" >/dev/null
  echo "C2_PREVIOUS_IMAGE_$svc=AVAILABLE"
done
phase="O5_BACKUP"
sudo bash scripts/o5_verify_active_schedule.sh | grep -E 'TIMERS_ACTIVOS_Y_HABILITADOS=|COPIA_TRAS_REAUTORIZACION=|ULTIMO_SNAPSHOT_MENOS_36H=|AUDITORIA_FINAL_O5='
echo "C2_O5_INSPECTED=OK"
phase="HTTPS"
for url in https://dev.vencira.es/ https://dev.vencira.es/api/v1/me/; do
  result="$(curl --silent --show-error --max-time 15 --output /dev/null --write-out '%{http_code}' "$url")"
  echo "C2_HTTPS_STATUS=$result"
done
phase="FINISH"
echo "C2_READINESS_READONLY=OK"
