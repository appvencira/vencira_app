#!/usr/bin/env bash
# O5: configuración OAuth interactiva; NO COMPARTIR SALIDA rclone config.
# Requiere túnel SSH localhost:53682 en cliente con navegador, o rclone authorize.
# No realiza backups ni modifica contenedores ni migraciones.
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=INICIO
finish() {
  local rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "COPIA_DRIVE_NO_EJECUTADA=1"
  echo "SIN_MIGRACIONES_NI_REINICIOS=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=GIT
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)" && test -z "$(git diff --cached --name-only)"
echo "COMMIT=$(git rev-parse HEAD)"
PHASE=TOOLS
test "$(restic version | awk '{print $2}')" = 0.19.1
command -v rclone >/dev/null
echo "RESTIC=0.19.1"
echo "RCLONE=DISPONIBLE"
sudo -v
PHASE=SERVICIOS
for svc in api db web_preview; do
  container="vencira_localcheck-${svc}-1"
  project="$(sudo docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(sudo docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy
done
echo "STACK_LOCALCHECK=healthy"

PHASE=PREPARAR_CONFIG_ROOT
ROOT=/etc/vencira-backup
CONF="$ROOT/rclone.conf"
sudo test ! -L "$ROOT" && sudo test ! -L "$CONF"
if [ -e "$ROOT" ]; then
  test -d "$ROOT" && test "$(sudo stat -c %u:%a "$ROOT")" = 0:700 || {
    echo "ERROR: directorio de secretos existente sin permisos root:700"
    exit 3
  }
else
  sudo install -o root -g root -m 0700 -d "$ROOT"
fi
if sudo test -e "$CONF"; then
  test "$(sudo stat -c %u:%a "$CONF")" = 0:600 || {
    echo "ERROR: rclone.conf existente con permisos inseguros"
    exit 3
  }
  if sudo env RCLONE_CONFIG="$CONF" rclone listremotes 2>/dev/null |
    grep -Fxq 'vencira_google:'; then
    echo "ERROR: remoto vencira_google existente. No sobrescribir."
    exit 3
  fi
else
  sudo install -o root -g root -m 0600 /dev/null "$CONF"
fi
echo "CONFIG_PRIVADA_ROOT_0700_0600=OK"

echo "=== RCLONE CONFIG: NO COMPARTIR LA TRANSCRIPCION ==="
echo "Nuevo remoto 'vencira_google' y storage 'drive'."
echo "Introducir CLIENT ID + CLIENT SECRET privados desde Google Cloud."
echo "Scope 'drive.file' (no 'drive'). No Shared Drive."
echo "Con tunel SSH 53682 activo en el navegador: usar Y en auto config."
echo "Sin tunel: usar N y rclone authorize en otro equipo con navegador."
PHASE=RCLONE_OAUTH_INTERACTIVO
sudo env RCLONE_CONFIG="$CONF" rclone config

PHASE=VERIFICACION_LOCAL_SIN_SECRETOS
sudo python3 - "$CONF" <<'PY'
import configparser
import os
import stat
import sys
p = sys.argv[1]
st = os.stat(p)
if st.st_uid != 0 or stat.S_IMODE(st.st_mode) != 0o600:
    raise SystemExit("ERROR: permisos rclone.conf")
cfg = configparser.ConfigParser(interpolation=None)
if not cfg.read(p) or not cfg.has_section("vencira_google"):
    raise SystemExit("ERROR: remoto ausente")
section = cfg["vencira_google"]
if section.get("type") != "drive" or section.get("scope") != "drive.file":
    raise SystemExit("ERROR: tipo/scope incorrecto")
if not all(section.get(k) for k in ("client_id", "client_secret", "token")):
    raise SystemExit("ERROR: credenciales OAuth incompletas")
print("OAUTH_PROPIO_SCOPE_DRIVE_FILE=OK")
print("RCLONE_CONF_ROOT_PERMISOS=OK")
PY

PHASE=VERIFICACION_REMOTA
if sudo env RCLONE_CONFIG="$CONF" rclone lsd vencira_google: >/dev/null 2>&1; then
  echo "RCLONE_GOOGLE_DRIVE_ACCESO=OK"
else
  echo "ERROR: Drive no accesible (revisar OAuth/Drive API)"
  exit 4
fi
echo "O5_OAUTH_CONFIGURADO=1"
