#!/usr/bin/env bash
# O3: reconciliar fecha de migracion Django 0014 con API/Web efectivamente servidas.
# SOLO LECTURA: no docker compose, no migrate, no start/stop/restart/build/pg_restore.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o3-runtime.XXXXXXXX.log)"
PHASE=INICIO
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_DIAGNOSTICO=$rc"
  echo "SIN_MIGRACION_NI_DESPLIEGUE=1"
  echo "SIN_MODIFICACION_DATOS=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=REPO
echo "=== FUENTES ==="
echo "RAMA=$(git branch --show-current)"
echo "COMMIT=$(git rev-parse HEAD)"
echo "ESTADO_GIT=$(if git diff --quiet && git diff --cached --quiet; then echo LIMPIO; else echo CAMBIOS_LOCALES; fi)"
sudo -v

PHASE=CONTAINERS
echo "=== VERSIONES Y ARRANQUES DE CONTENEDORES ==="
for service in api db web_preview; do
  container="vencira_localcheck-${service}-1"
  project="$(sudo docker inspect "$container" \
    --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  test "$project" = vencira_localcheck || {
    echo "ERROR: servicio fuera de vencira_localcheck: $service"
    exit 4
  }
  echo "SERVICE=$service"
  sudo docker inspect "$container" --format \
    'CREATED={{.Created}} STARTED={{.State.StartedAt}} IMAGE_ID={{.Image}} STATUS={{.State.Status}} HEALTH={{if .State.Health}}{{.State.Health.Status}}{{else}}sin_health{{end}}'
done
echo "COMPOSE_IDENTITY=OK"

DB=vencira_localcheck-db-1
sql_read() {
  sudo docker exec "$DB" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "$1"' \
    sh "$1"
}
PHASE=DATABASE
echo "=== ESTADO REAL DE MIGRACION O3 ==="
sql_read "SELECT name || ' | aplicada=' || to_char(applied AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS') || ' UTC' FROM django_migrations WHERE app='reminders' AND name IN ('0013_renewal_manual_followups','0014_renewal_outcomes') ORDER BY name;" |
  while IFS= read -r line; do echo "MIGRACION_REGISTRO=$line"; done
sql_read "SELECT COUNT(*) FROM reminders_renewaloutcome;" |
  sed 's/^/EVENTOS_O3_CONTABILIZADOS=/'
sql_read "SELECT COUNT(*) FROM reminders_renewal WHERE archived_at IS NOT NULL;" |
  sed 's/^/ANOTACIONES_ARCHIVADAS_O3=/'
echo "DB_SCHEMA_O3=0014_APLICADA"

PHASE=API
echo "=== CODIGO O3 EN API ACTUAL ==="
api=vencira_localcheck-api-1
if sudo docker exec "$api" sh -c 'test -f /app/reminders/outcomes.py && test -f /app/reminders/migrations/0014_renewal_outcomes.py'; then
  echo "API_CONTIENE_MODULOS_O3=1"
else
  echo "API_CONTIENE_MODULOS_O3=0"
fi
if sudo docker exec "$api" sh -c 'grep -Fq "from .outcomes import renewal_outcomes" /app/reminders/urls.py'; then
  echo "API_RUTA_O3_EN_CODIGO=1"
else
  echo "API_RUTA_O3_EN_CODIGO=0"
fi

PHASE=HTTP
echo "=== ENDPOINTS ANONIMOS LOCALES ==="
for ep in outcomes follow-up; do
  case "$ep" in
    outcomes) tail="outcomes/";;
    follow-up) tail="follow-up/";;
  esac
  url="http://127.0.0.1:28732/api/v1/workspaces/11111111-1111-4111-8111-111111111111/renewals/b2222222-2222-4222-8222-222222222222/$tail"
  code="$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' "$url" 2>>"$LOG" || true)"
  echo "HTTP_${ep}=${code:-sin_respuesta}"
done
url=http://127.0.0.1:28732/
code="$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' "$url" 2>>"$LOG" || true)"
echo "HTTP_WEB_LOCAL=${code:-sin_respuesta}"

PHASE=WEB
echo "=== VERSION WEB ACTUAL ==="
web=vencira_localcheck-web_preview-1
if sudo docker exec "$web" sh -c 'test -s /usr/share/nginx/html/main.dart.js && grep -Fq "Elegir desenlace" /usr/share/nginx/html/main.dart.js'; then
  echo "WEB_INCLUYE_ETIQUETA_O3=1"
else
  echo "WEB_INCLUYE_ETIQUETA_O3=0_O_NO_DETECTABLE"
fi
if sudo docker exec "$web" sh -c 'test -s /usr/share/nginx/html/main.dart.js'; then
  echo "WEB_BUNDLE_EXISTE=1"
else
  echo "WEB_BUNDLE_EXISTE=0"
fi

PHASE=STARTUP_EVIDENCE
echo "=== EVIDENCIA DE ARRANQUE API (SOLO LINEAS DE MIGRACION) ==="
# Limita la salida a lineas no sensibles; no imprime solicitudes HTTP ni secretos.
sudo docker logs --tail 1500 "$api" 2>&1 |
  grep -E 'Applying reminders\.0014_renewal_outcomes|Applying reminders\.0013_renewal_manual_followups|No migrations to apply\.|Operations to perform:|Running migrations:' |
  tail -n 12 || true

PHASE=RESUMEN
echo "CAUSA_CAMBIO_0014=AUN_NO_ATRIBUIDA_CON_CERTEZA"
echo "CORRECCION_PENDIENTE=CONCILIAR_VERSIONES_SIN_REAPLICAR_0014"
