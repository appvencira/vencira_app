#!/usr/bin/env bash
# C2 pre-deploy checks, read-only; never deploys or migrates.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
echo "C2_SOURCE_SHA=$(git rev-parse HEAD)"
sudo docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml config --quiet
echo "C2_COMPOSE=OK"
for svc in api db web_preview; do
  id="vencira_localcheck-$svc-1"
  test "$(sudo docker inspect "$id" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(sudo docker inspect "$id" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
  image="$(sudo docker inspect "$id" --format '{{.Image}}')"
  sudo docker image inspect "$image" >/dev/null
  echo "C2_SERVICE_$svc=HEALTHY_IMAGE_PRESENT"
done
cmd="$(sudo docker inspect vencira_localcheck-api-1 --format '{{json .Config.Cmd}}')"
case "$cmd" in *"migrate --check --noinput"*) echo "C2_API_MIGRATE_CHECK_ONLY=OK";; *) echo "C2_API_COMMAND_UNSAFE=1"; exit 3;; esac
sudo bash scripts/o5_verify_active_schedule.sh | grep -E '^(TIMERS_ACTIVOS_Y_HABILITADOS|COPIA_TRAS_REAUTORIZACION|ULTIMO_SNAPSHOT_MENOS_36H|AUDITORIA_FINAL_O5)='
echo "C2_O5_CHECK=REPORTED"
sudo docker exec vencira_localcheck-db-1 sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT name FROM django_migrations WHERE app='"'"'reminders'"'"' ORDER BY name DESC LIMIT 1;"' | sed 's/^/C2_DB_MIGRATION=/'
curl -fsS --max-time 15 -o /dev/null https://dev.vencira.es/
echo "C2_HTTPS=OK"
echo "C2_READINESS_READONLY=OK"
echo "NO_DEPLOY_NO_MIGRATION=1"
