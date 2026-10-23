#!/usr/bin/env bash
# O3: diagnostico SOLO LECTURA despues de bloqueo PREMIGRACION.
# No usa docker compose up/run/build, no reinicia ni migra nada.
set -euo pipefail
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-o3-schema.XXXXXXXX.log)"
PHASE=INICIO
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_DIAGNOSTICO=$rc"
  echo "SIN_MIGRACION_NI_DESPLIEGUE=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

echo "=== REPOSITORIO E IDENTIDAD ==="
PHASE=GIT
echo "RAMA_LOCAL=$(git branch --show-current)"
echo "COMMIT_LOCAL=$(git rev-parse HEAD)"
echo "ESTADO_GIT=$(if git diff --quiet && git diff --cached --quiet; then echo LIMPIO; else echo CAMBIOS_LOCALES; fi)"
PHASE=DOCKER
sudo -v
for service in api db web_preview; do
  name="vencira_localcheck-${service}-1"
  label="$(sudo docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  test "$label" = vencira_localcheck || { echo "ERROR: proyecto Docker inesperado"; exit 4; }
  health="$(sudo docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  echo "HEALTH_${service}=$health"
done
echo "COMPOSE_IDENTITY=OK"
DB=vencira_localcheck-db-1
sql_read() {
  sudo docker exec "$DB" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "$1"' \
    sh "$1"
}
PHASE=SCHEMA_READ
echo "=== MIGRACIONES DJANGO (ULTIMAS 6) ==="
latest="$(sql_read "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
printf 'ULTIMA_MIGRACION_REAL=%s\n' "$latest"
echo "NOMBRE_MIGRACION_LONGITUD=${#latest}"
sql_read "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 6;" | while IFS= read -r name; do
  printf 'MIGRACION=%s\n' "$name"
done
echo "=== OBJETOS DE ESQUEMA O2/O3 ==="
sql_read "SELECT to_regclass('public.reminders_renewalfollowup') IS NOT NULL;" |
  sed 's/^/TABLA_O2_PRESENTE=/'
sql_read "SELECT to_regclass('public.reminders_renewaloutcome') IS NOT NULL;" |
  sed 's/^/TABLA_O3_PRESENTE=/'
sql_read "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='reminders_renewal' AND column_name IN ('archived_at','archive_outcome');" |
  sed 's/^/COLUMNAS_O3_PRESENTES=/'
sql_read "SELECT to_regclass('public.outcome_renewal_time_idx') IS NOT NULL;" |
  sed 's/^/INDICE_O3_PRESENTE=/'
echo "=== DIAGNOSTICO ==="
if [ "$latest" = 0013_renewal_manual_followups ]; then
  echo "ESQUEMA_REAL=0013_ESPERADO"
  echo "NOTA=La comprobacion actual coincide; no repetir despliegue hasta revisar causa de discrepancia anterior."
elif [ "$latest" = 0014_renewal_outcomes ]; then
  echo "ESQUEMA_REAL=0014_APLICADA_POR_OTRA_RUTA"
  echo "NOTA=No repetir migracion ni restaurar backup; revisar causa antes de actualizar servicios."
else
  echo "ESQUEMA_REAL=INESPERADO"
  echo "NOTA=Abstenerse de desplegar hasta resolver migraciones."
fi
