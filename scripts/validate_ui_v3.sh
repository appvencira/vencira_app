#!/usr/bin/env bash
# VENCIRA UI V3 — comprobación consolidada (no toca API ni PostgreSQL).
# Usar: bash scripts/validate_ui_v3.sh desde el checkout correcto.
# Es un proceso hijo: sus fallos NO cierran la shell SSH interactiva.
set -euo pipefail
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-ui-v3.XXXXXXXX.log)"
PHASE="inicio"

finish() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -eq 0 ]; then
    echo "RESULTADO_GLOBAL=0"
  else
    echo "RESULTADO_GLOBAL=$rc"
    echo "FASE_FALLIDA=$PHASE"
    echo "=== ULTIMAS 100 LINEAS DE DIAGNOSTICO ==="
    tail -n 100 "$LOG" 2>/dev/null || true
  fi
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

echo "=== REPOSITORIO Y PRECONDICIONES ==="
PHASE="GIT_BRANCH"
branch="$(git branch --show-current)"
echo "RAMA_LOCAL=$branch"
if [ "$branch" != "integration/local-e2e-prep" ]; then
  echo "ERROR: se esperaba integration/local-e2e-prep; no se hace checkout automático"
  exit 2
fi

PHASE="GIT_WORKTREE"
# Solo se permiten archivos generados conocidos. No borrar ni tocar ficheros
# locales y nunca ignorar cambios en código versionado.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ESTADO_GIT=MODIFICACIONES_VERSIONADAS"
  git status --short
  echo "ERROR: cambios rastreados o en staging; no se despliega."
  exit 3
fi

# pubspec.lock todavía no está versionado en este proyecto; se genera
# con flutter pub get. Cualquier OTRO archivo nuevo bloquea el despliegue.
extra_untracked="$(git ls-files --others --exclude-standard \
  | grep -vx 'clients/flutter/pubspec.lock' || true)"
if [ -n "$extra_untracked" ]; then
  echo "ESTADO_GIT=ARCHIVOS_NUEVOS_NO_ESPERADOS"
  printf '%s\n' "$extra_untracked"
  echo "ERROR: archivos locales ajenos a los artefactos permitidos."
  exit 3
fi
if [ -f clients/flutter/pubspec.lock ]; then
  echo "ARCHIVO_GENERADO_ADMITIDO=clients/flutter/pubspec.lock"
fi
echo "ESTADO_GIT=FUENTES_VERSIONADAS_LIMPIAS"
echo "COMMIT=$(git rev-parse HEAD)"

PHASE="COMPOSE_IDENTITY"
for service in api db web_preview; do
  echo "COMPROBANDO_SERVICIO=$service"
  label="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  test "$label" = "vencira_localcheck" || {
    echo "ERROR: proyecto Docker inesperado: $service"
    exit 4
  }
done
echo "COMPOSE_IDENTITY=OK"

COMPOSE=(sudo docker compose -p vencira_localcheck \
  -f compose.yaml -f compose.preview.yaml)

step "COMPOSE_CONFIG" "${COMPOSE[@]}" config --quiet

step "FLUTTER_PUB_GET_ANALYZE_TEST_BUILD" \
  sudo docker run --rm \
    -v "$PWD/clients/flutter:/work" -w /work \
    ghcr.io/cirruslabs/flutter:stable \
    sh -ec 'flutter pub get && flutter analyze && flutter test test/design_v3_test.dart && flutter test && flutter build web --release --pwa-strategy=none'

echo "FLUTTER_V3_Y_TESTS=OK"

# Sólo después de que TODAS las pruebas pasen se prepara y recrea Web.
step "WEB_BUILD" "${COMPOSE[@]}" build web_preview
step "WEB_DEPLOY" "${COMPOSE[@]}" up -d --no-deps web_preview

PHASE="HEALTHCHECK"
echo "=== $PHASE ==="
health="starting"
for attempt in $(seq 1 24); do
  health="$(sudo docker inspect vencira_localcheck-web_preview-1 \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  if [ "$health" = "healthy" ]; then break; fi
  if [ "$health" = "unhealthy" ]; then break; fi
  sleep 5
done
echo "WEB_HEALTH=$health"
test "$health" = "healthy"

PHASE="HTTP"
echo "=== $PHASE ==="
for endpoint in / /api/health/ /api/ready/ /accounts/login/; do
  status="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' \
    "http://127.0.0.1:28732$endpoint")"
  echo "PROXY_ENDPOINT=$endpoint STATUS=$status"
  test "$status" = "200"
done

for service in api db web_preview; do
  health="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_${service}=$health"
  test "$health" = "healthy"
done

# Confirmación externa opcional: no bloquear despliegue por túnel/DNS externo.
PHASE="HTTPS_PUBLICO"
echo "=== $PHASE (informativa, sin credenciales) ==="
https_status="$(curl -L -sS --max-time 15 -o /dev/null -w '%{http_code}' \
  'https://dev.vencira.es/' 2>/dev/null || true)"
echo "DEV_VENCIRA_HTTPS_HTTP=${https_status:-no_disponible}"

PHASE="VERSION_WEB"
echo "=== $PHASE ==="
echo "COMMIT_VALIDADO=$(git rev-parse HEAD)"
echo "DESPLIEGUE_WEB_V3_LOCALCHECK=OK"
echo "SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1"
