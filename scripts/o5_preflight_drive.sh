#!/usr/bin/env bash
# VENCIRA O5 — diagnostico SOLO LECTURA antes de habilitar Google Drive.
# NO instala, NO autoriza Google, NO crea copias ni modifica servicios.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck

PHASE=INICIO
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "SIN_INSTALACION_NI_ACCESO_GOOGLE=1"
  echo "SIN_COPIAS_REMOTAS_NI_CAMBIOS_DB=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

echo "=== REPOSITORIO ==="
PHASE=GIT
branch="$(git branch --show-current)"
echo "RAMA=$branch"
test "$branch" = integration/local-e2e-prep
echo "COMMIT=$(git rev-parse HEAD)"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: cambios versionados locales"
  exit 2
fi
echo "GIT_TRACKED_LIMPIO=1"

echo "=== ENTORNO Y SERVICIOS ==="
PHASE=DOCKER
sudo -v
for service in api db web_preview; do
  cname="vencira_localcheck-${service}-1"
  label="$(sudo docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$cname" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin_health{{end}}')"
  test "$label" = vencira_localcheck || { echo "ERROR: identidad Docker incorrecta en $service"; exit 3; }
  echo "HEALTH_${service}=$health"
  test "$health" = healthy || { echo "ERROR: $service no saludable"; exit 3; }
done
echo "IDENTIDAD_LOCALCHECK=OK"

PHASE=DB
schema="$(sudo docker exec vencira_localcheck-db-1 sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq -c "SELECT name FROM django_migrations WHERE app=\047reminders\047 ORDER BY name DESC LIMIT 1;"')"
echo "ULTIMA_MIGRACION=$schema"
test "$schema" = 0014_renewal_outcomes || {
  echo "ERROR: esquema inesperado, O5 no continúa"
  exit 4
}

PHASE=HERRAMIENTAS
echo "=== HERRAMIENTAS PARA BACKUP ==="
missing=0
for cmd in rclone restic openssl curl python3 flock; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "TOOL_${cmd}=INSTALADA"
  else
    echo "TOOL_${cmd}=FALTA"
    missing=$((missing+1))
  fi
done
if command -v rclone >/dev/null 2>&1; then
  echo "RCLONE_VERSION=$(rclone version | head -n 1)"
fi
if command -v restic >/dev/null 2>&1; then
  echo "RESTIC_VERSION=$(restic version | head -n 1)"
fi
echo "HERRAMIENTAS_FALTANTES=$missing"

echo "=== ESPACIO Y CONFIGURACION EXTERNA ==="
PHASE=DISCO
df -h --output=source,size,avail,pcent /home/vencira | tail -n 1 | awk '{print "DISCO_RAIZ=" $1 " ESPACIO_TOTAL=" $2 " ESPACIO_DISPONIBLE=" $3 " USO=" $4}'
if [ -f /etc/vencira-backup/config.env ]; then
  echo "BACKUP_CONFIG_ROOT=EXISTE_SIN_LECTURA"
else
  echo "BACKUP_CONFIG_ROOT=NO_CONFIGURADO"
fi
if [ -f /etc/vencira-backup/restic-password ]; then
  echo "BACKUP_CLAVE_ROOT=EXISTE_SIN_LECTURA"
else
  echo "BACKUP_CLAVE_ROOT=NO_CONFIGURADA"
fi
echo "GOOGLE_ACCOUNT_DOCUMENTADA=appvencira@gmail.com"
echo "GOOGLE_OAUTH_ESTADO=NO_VERIFICADO_EN_ESTE_DIAGNOSTICO"
echo "FASE_O5=PREPARACION_SIN_CAMBIOS"
