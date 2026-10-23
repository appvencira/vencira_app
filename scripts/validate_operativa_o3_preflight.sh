#!/usr/bin/env bash
# O3: pruebas aisladas antes de tocar la DB de localcheck. NO despliega.
set -euo pipefail
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-operativa-o3-preflight.XXXXXXXX.log)"
PHASE="PRECONDICIONES"
NETWORK=""
DATABASE_CONTAINER=""
finish() {
  local rc=$?
  trap - EXIT
  # Recursos efímeros exclusivos de prueba; jamás parar servicios localcheck.
  if [ -n "$DATABASE_CONTAINER" ]; then
    sudo docker rm -f "$DATABASE_CONTAINER" >>"$LOG" 2>&1 || true
  fi
  if [ -n "$NETWORK" ]; then
    sudo docker network rm "$NETWORK" >>"$LOG" 2>&1 || true
  fi
  if [ "$rc" -eq 0 ]; then
    echo "RESULTADO_GLOBAL=0"
  else
    echo "RESULTADO_GLOBAL=$rc"
    echo "FASE_FALLIDA=$PHASE"
    echo "=== PRIMER ERROR O EXCEPCION ==="
    grep -m 12 -E 'Exception|ERROR|FAIL|RenderFlex|Error:|error •' "$LOG" || true
    echo "=== ULTIMAS 100 LINEAS ==="
    tail -n 100 "$LOG" || true
  fi
  echo "SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
}
trap finish EXIT

step() {
  PHASE="$1"
  shift
  echo "=== $PHASE ==="
  if "$@" >>"$LOG" 2>&1; then
    echo "OK: $PHASE"
  else
    return $?
  fi
}

echo "=== REPOSITORIO ==="
BRANCH="$(git branch --show-current)"
echo "RAMA_LOCAL=$BRANCH"
test "$BRANCH" = integration/local-e2e-prep
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: fuentes locales modificadas; se conserva el trabajo local"
  git status --short
  exit 3
fi
UNTRACKED="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
if [ -n "$UNTRACKED" ]; then
  echo "ERROR: archivos no versionados inesperados"
  printf '%s\n' "$UNTRACKED"
  exit 3
fi
SHA="$(git rev-parse HEAD)"
echo "COMMIT=$SHA"
echo "ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS"

for service in api db web_preview; do
  project="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  if [ "$project" != vencira_localcheck ]; then
    echo "ERROR: identidad Docker incorrecta en $service"
    exit 4
  fi
done
echo "COMPOSE_IDENTITY=OK"
step COMPOSE_CONFIG sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml config --quiet

IMAGE="vencira-o3-tests:${SHA:0:12}"
step BUILD_API_PRUEBA_AISLADA sudo docker build -t "$IMAGE" ./backend

DJANGO_ENV=(
  -e VENCIRA_ENV=test
  -e VENCIRA_DB_ENGINE=sqlite
  -e DJANGO_DEBUG=0
  -e DJANGO_SECRET_KEY=o3-ephemeral-validation-key-never-production-2026
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
)
step DJANGO_CHECK_Y_MIGRACION_EN_SECO sudo docker run --rm \
  "${DJANGO_ENV[@]}" "$IMAGE" \
  sh -ec 'python manage.py check && python manage.py makemigrations --check --dry-run'
step DJANGO_SQLITE_SUITE sudo docker run --rm \
  "${DJANGO_ENV[@]}" "$IMAGE" \
  python manage.py test reminders --verbosity 1 --noinput

# PostgreSQL temporal. Sin conexión ni volumen compartido con localcheck.
NETWORK="vencira_o3_net_$$"
DATABASE_CONTAINER="vencira_o3_pg_$$"
PHASE=POSTGRES_EFIMERO
sudo docker network create "$NETWORK" >>"$LOG" 2>&1
sudo docker run -d --name "$DATABASE_CONTAINER" --network "$NETWORK" \
  -e POSTGRES_DB=o3_tmp -e POSTGRES_USER=o3_tmp \
  -e POSTGRES_PASSWORD=o3-temporary-not-production \
  postgres:17-alpine >>"$LOG" 2>&1
echo "=== POSTGRES_EFIMERO ==="
ready=0
for attempt in $(seq 1 40); do
  if sudo docker exec "$DATABASE_CONTAINER" pg_isready \
    -U o3_tmp -d o3_tmp >>"$LOG" 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
test "$ready" = 1
echo "OK: POSTGRES_EFIMERO"
step DJANGO_POSTGRES_O3_TESTS sudo docker run --rm --network "$NETWORK" \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=o3-ephemeral-validation-key-never-production-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  -e POSTGRES_HOST="$DATABASE_CONTAINER" -e POSTGRES_USER=o3_tmp \
  -e POSTGRES_PASSWORD=o3-temporary-not-production -e POSTGRES_DB=o3_tmp \
  "$IMAGE" python manage.py test reminders.test_outcomes reminders.test_manual_follow_up \
    --verbosity 1 --noinput

step FLUTTER_O3_SUITE_Y_BUILD sudo docker run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  ghcr.io/cirruslabs/flutter:stable sh -ec \
    'flutter pub get && flutter analyze && flutter test test/outcomes_test.dart && flutter test test/manual_follow_up_test.dart && flutter test test/vencira_api_test.dart && flutter test && flutter build web --release --pwa-strategy=none'

echo "DJANGO_SQLITE_POSTGRES_FLUTTER_O3=OK"
echo "VERSION_PREVALIDADA=$SHA"
echo "MIGRACION_0014_AUN_NO_APLICADA=1"
