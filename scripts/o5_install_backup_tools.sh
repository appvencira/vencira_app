#!/usr/bin/env bash
# VENCIRA O5: instalar únicamente herramientas de copias en Ubuntu 24.04.
# Sin OAuth, sin tocar DB/Docker/servicios, sin copiar archivos a la nube.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck

LOG="$(mktemp /tmp/vencira-o5-tools.XXXXXXXX.log)"
PHASE=INICIO
INSTALLED=0
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "=== ULTIMAS 45 LINEAS ==="
    tail -n 45 "$LOG" 2>/dev/null || true
  fi
  echo "RCLONE_RESTIC_INSTALADOS_Y_PROBADOS=$INSTALLED"
  echo "GOOGLE_DRIVE_NO_CONECTADO=1"
  echo "SIN_COPIAS_REMOTE_NI_MIGRACION=1"
  echo "LOG_LOCAL=$LOG"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

step() {
  PHASE="$1"; shift
  echo "=== $PHASE ==="
  if "$@" >>"$LOG" 2>&1; then echo "OK: $PHASE"; else return $?; fi
}

echo "=== BASE Y SISTEMA ==="
PHASE=IDENTIDAD
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)"
. /etc/os-release
test "$ID" = ubuntu && test "$VERSION_ID" = 24.04 || {
  echo "ERROR: este instalador está limitado a Ubuntu 24.04"
  exit 2
}
echo "SISTEMA=Ubuntu_24.04"
echo "RAMA=integration/local-e2e-prep"
echo "COMMIT=$(git rev-parse HEAD)"
sudo -v
for service in api db web_preview; do
  cname="vencira_localcheck-${service}-1"
  project="$(sudo docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  state="$(sudo docker inspect "$cname" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin_health{{end}}')"
  test "$project" = vencira_localcheck && test "$state" = healthy || {
    echo "ERROR: proyecto/salud $service inesperados"
    exit 3
  }
done
API_ID="$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
DB_ID="$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
WEB_ID="$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
echo "LOCALCHECK_SERVICIOS=healthy"

echo "=== APT: SOLO DOS PAQUETES ==="
# Los repositorios firmados Ubuntu y sus actualizaciones de seguridad.
# No ejecutar dist-upgrade, ni scripts de descarga remota.
step APT_UPDATE sudo env DEBIAN_FRONTEND=noninteractive apt-get update
step APT_INSTALL_RESTIC_RCLONE sudo env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends restic rclone

PHASE=VERSIONES
command -v restic >/dev/null
command -v rclone >/dev/null
echo "RESTIC_VERSION=$(restic version | sed -n '1p')"
echo "RCLONE_VERSION=$(rclone version | sed -n '1p')"
if ! restic backup --help 2>>"$LOG" | grep -F -- '--stdin-from-command' >>"$LOG"; then
  echo "ERROR: Restic sin soporte para capturar salida+errores del pg_dump"
  exit 5
fi
if ! restic dump --help >>"$LOG" 2>&1; then
  echo "ERROR: Restic sin comando de recuperación"
  exit 5
fi
if ! rclone serve restic --help >>"$LOG" 2>&1; then
  echo "ERROR: Rclone sin backend Restic"
  exit 5
fi
echo "RESTIC_STDIN_FROM_COMMAND=OK"
echo "RCLONE_BACKEND_RESTIC=OK"

PHASE=VERIFICACION_FINAL
test "$API_ID" = "$(sudo docker inspect vencira_localcheck-api-1 --format '{{.Id}}')"
test "$DB_ID" = "$(sudo docker inspect vencira_localcheck-db-1 --format '{{.Id}}')"
test "$WEB_ID" = "$(sudo docker inspect vencira_localcheck-web_preview-1 --format '{{.Id}}')"
for service in api db web_preview; do
  healthy="$(sudo docker inspect "vencira_localcheck-${service}-1" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin_health{{end}}')"
  echo "HEALTH_${service}=$healthy"
  test "$healthy" = healthy || exit 6
done
echo "CONTENEDORES_INTACTOS=1"
INSTALLED=1
