#!/usr/bin/env bash
# O7/O8: preflight completo en recursos efimeros, SIN despliegue ni migracion viva.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=IDENTIDAD
LOG="$(mktemp /tmp/vencira-o7-o8-preflight.XXXXXXXX.log)"
NETWORK=""
DB=""
finish(){
  rc=$?
  trap - EXIT
  if [ -n "$DB" ]; then sudo docker rm -f "$DB" >>"$LOG" 2>&1 || true; fi
  if [ -n "$NETWORK" ]; then sudo docker network rm "$NETWORK" >>"$LOG" 2>&1 || true; fi
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "=== PRIMERAS EXCEPCIONES ==="
    grep -m 12 -E 'error •|Exception|FAIL|ERROR|Error:|error:|Failed' "$LOG" || true
    echo "=== ULTIMAS 60 LINEAS ==="
    tail -n 60 "$LOG" || true
  fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1"
  echo "SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
step(){
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  if "$@" >>"$LOG" 2>&1; then echo "$PHASE=OK"; else return $?; fi
}
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
extra="$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$extra" || { echo "ERROR=ARCHIVOS_AJENOS_LOCAL"; exit 3; }
SHA="$(git rev-parse HEAD)"
echo "COMMIT=$SHA"
PHASE=CONTAINERS
for service in api db web_preview; do
  name="vencira_localcheck-$service-1"
  test "$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
echo "LOCALCHECK_HEALTH_PRE=OK"
step CONFIG_COMPOSE sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml config --quiet
step I18N_ES_CA python3 scripts/check_flutter_l10n.py

IMG="vencira-o7-o8-check:$(git rev-parse --short=12 HEAD)"
step BUILD_BACKEND_AISLADO sudo docker build -t "$IMG" ./backend
step DJANGO_CHECK_MIGRACION_SECA sudo docker run --rm \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o7-o8-ci-only-key-never-prod-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  "$IMG" sh -ec 'python manage.py check && python manage.py makemigrations --check --dry-run'
step DJANGO_SQLITE_SUITE_COMPLETA sudo docker run --rm \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o7-o8-ci-only-key-never-prod-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  "$IMG" python manage.py test reminders --verbosity 1 --noinput

PHASE=PG17_TEMPORAL
NETWORK="vencira_o7o8_net_$$"
DB="vencira_o7o8_db_$$"
sudo docker network create "$NETWORK" >>"$LOG" 2>&1
sudo docker run -d --name "$DB" --network "$NETWORK" \
  -e POSTGRES_DB=o7o8_tmp -e POSTGRES_USER=o7o8_tmp \
  -e POSTGRES_PASSWORD=o7o8-test-only-static-value \
  postgres:17-alpine >>"$LOG" 2>&1
ready=0
for i in $(seq 1 40); do
  if sudo docker exec "$DB" pg_isready -U o7o8_tmp -d o7o8_tmp >>"$LOG" 2>&1; then
    ready=1; break
  fi
  sleep 2
done
test "$ready" -eq 1
echo "PG17_TEMPORAL=OK"
step DJANGO_POSTGRES17_SUITE_COMPLETA sudo docker run --rm --network "$NETWORK" \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o7-o8-ci-only-key-never-prod-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=o7o8_tmp \
  -e POSTGRES_USER=o7o8_tmp -e POSTGRES_PASSWORD=o7o8-test-only-static-value \
  "$IMG" python manage.py test reminders --verbosity 1 --noinput
step FLUTTER_ANALYZE_TEST_BUILD sudo docker run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  ghcr.io/cirruslabs/flutter:stable \
  sh -ec 'flutter pub get && flutter analyze && flutter test && flutter build web --release --pwa-strategy=none'

PHASE=LOCALCHECK_FINAL
for service in api db web_preview; do
  name="vencira_localcheck-$service-1"
  test "$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
echo "LOCALCHECK_HEALTH_POST=OK"
echo "O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK"
