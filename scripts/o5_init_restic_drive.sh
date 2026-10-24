#!/usr/bin/env bash
# O5 — inicializa UN repositorio Restic cifrado en Google Drive.
# NO exporta PostgreSQL, no programa timers, no migra ni reinicia Docker.
# Requiere TTY seguro: muestra UNA clave para guardarla FUERA del servidor.
# ¡NO COPIAR LA TRANSCRIPCION COMPLETA AL CHAT NI GRABAR EL TERMINAL!
set -euo pipefail
umask 077
cd /home/vencira/vencira-localcheck

PHASE=INICIO
REPO_READY=0
PROOF_OK=0
KEY_SAVED=0
finish() {
  local result=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$result"
  if [ "$result" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
  fi
  echo "CLAVE_PRIVADA_EN_SERVIDOR=$KEY_SAVED"
  echo "REPO_RESTIC_REMOTO_INICIALIZADO=$REPO_READY"
  echo "PRUEBA_CIFRADA_DRIVE_RESTAURADA=$PROOF_OK"
  echo "POSTGRES_NO_RESPALDADO_AUN=1"
  echo "SIN_MIGRACIONES_NI_REINICIOS=1"
  echo "CONSOLA_ABIERTA"
  exit "$result"
}
trap finish EXIT

PHASE=USUARIO
test "$(id -u)" -eq 0 || {
  echo "ERROR: ejecutar mediante sudo bash, no como usuario normal"
  exit 2
}
test -t 0 && test -t 1 || {
  echo "ERROR: usar terminal SSH interactivo sin grabación"
  exit 2
}
gitrepo() { git -c safe.directory=/home/vencira/vencira-localcheck "$@"; }
test "$(gitrepo branch --show-current)" = integration/local-e2e-prep
test -z "$(gitrepo diff --name-only)" && test -z "$(gitrepo diff --cached --name-only)"
echo "COMMIT=$(gitrepo rev-parse HEAD)"
test "$(restic version | awk '{print $2}')" = 0.19.1
command -v rclone >/dev/null
# Comprobar capacidad del servidor Restic de Rclone antes de pedir/guardar la clave.
rclone serve restic --help 2>/dev/null | grep -F -- "--b2-hard-delete" >/dev/null || {
  echo "ERROR: Rclone carece de compatibilidad con las opciones que usa Restic"; exit 2;
}
command -v openssl >/dev/null
command -v flock >/dev/null
command -v python3 >/dev/null
exec 8>/run/lock/vencira-o5-backup.lock
flock -n 8 || { echo "ERROR: tarea O5 ya ejecutándose"; exit 2; }

PHASE=STACK
echo "=== ENTORNO Y SALUD ==="
for service in api db web_preview; do
  cname="vencira_localcheck-${service}-1"
  project="$(docker inspect "$cname" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
  health="$(docker inspect "$cname" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')"
  test "$project" = vencira_localcheck && test "$health" = healthy || {
    echo "ERROR: stack Docker ajeno o no saludable: $service"; exit 3;
  }
  echo "HEALTH_${service}=healthy"
done

PHASE=CONF
ROOT=/etc/vencira-backup
RCLONE_CONFIG="$ROOT/rclone.conf"
RESTIC_PASSWORD_FILE="$ROOT/restic-password"
CONFIG_FILE="$ROOT/config.env"
RESTIC_REPOSITORY="rclone:vencira_google:VENCIRA-Backups/PostgreSQL"
# Rclone debe usar exclusivamente las credenciales privadas del backend, también en el preflight.
export RCLONE_CONFIG
test -d "$ROOT" && test ! -L "$ROOT"
test "$(stat -c '%u:%a' "$ROOT")" = 0:700
test -f "$RCLONE_CONFIG" && test ! -L "$RCLONE_CONFIG"
test "$(stat -c '%u:%a' "$RCLONE_CONFIG")" = 0:600
for file in "$RESTIC_PASSWORD_FILE" "$CONFIG_FILE"; do
  test ! -e "$file" && test ! -L "$file" || {
    echo "ERROR: config o clave Restic YA EXISTE; no sobrescribir ni repetir"
    exit 4
  }
done
# El token y secreto OAuth nunca se muestran.
python3 - "$RCLONE_CONFIG" <<'PY'
import configparser
import json
import sys

parser = configparser.ConfigParser(interpolation=None)
if not parser.read(sys.argv[1]) or not parser.has_section("vencira_google"):
    raise SystemExit("ERROR: remoto OAuth no existe")
c = parser["vencira_google"]
if c.get("type") != "drive" or c.get("scope") != "drive.file":
    raise SystemExit("ERROR: remoto no es drive o tiene scope excesivo")
if not c.get("client_id") or not c.get("client_secret"):
    raise SystemExit("ERROR: falta cliente OAuth propio")
try:
    t = json.loads(c.get("token", ""))
except (TypeError, ValueError):
    raise SystemExit("ERROR: JSON OAuth no válido")
if not isinstance(t, dict) or not t.get("refresh_token"):
    raise SystemExit("ERROR: no hay token OAuth de renovación")
print("RCLONE_PRIVADO_SCOPE_Y_TOKEN=OK")
PY

PHASE=ACCESO_GOOGLE
echo "=== DRIVE CON ACCESO VALIDO ==="
if timeout 90s rclone --contimeout 15s --timeout 40s lsd vencira_google: >/dev/null 2>&1; then
  echo "GOOGLE_DRIVE_ACCESIBLE=OK"
else
  echo "ERROR: Drive OAuth no accesible"
  exit 5
fi

PHASE=RUTA_EXISTENTE
# Rechazar una inicialización sobre repositorio ya creado.
if rclone lsjson vencira_google:VENCIRA-Backups/PostgreSQL/config >/dev/null 2>&1; then
  echo "ERROR: repo Restic detectado; no crear ni sobrescribir"
  exit 6
fi

PHASE=CUSTODIA_CLAVE
echo "=== CLAVE RECUPERACION: NO PEGAR SALIDA EN CHAT ==="
echo "Se generara una clave aleatoria de 256 bits."
echo "Debes copiarla en un gestor de contraseñas INDEPENDIENTE de Ubuntu y Drive."
echo "Sin esta clave NO se podran recuperar respaldos tras perder el servidor."
echo "No actives registros ni compartas captura/transcripcion de esta fase."
python3 - "$RESTIC_PASSWORD_FILE" <<'PY'
import getpass
import os
import secrets
import sys

path = sys.argv[1]
key = secrets.token_hex(32)
with open("/dev/tty", "r+") as tty:
    tty.write("\nCLAVE CIFRADO RESTIC (GUARDAR FUERA DEL SERVIDOR):\n")
    tty.write(key + "\n\n")
    tty.write("GUARDA AHORA LA CLAVE EN TU GESTOR DE CONTRASENAS.\n")
    tty.flush()
    repeat = getpass.getpass("Vuelve a pegar la clave guardada (no se mostrara): ")
    if not secrets.compare_digest(key, repeat):
        tty.write("ERROR: no coincide. Ninguna clave se ha guardado.\n")
        tty.flush()
        raise SystemExit(7)
    tty.write("Escribe GUARDADA si tienes una copia fuera de Ubuntu y Drive: ")
    tty.flush()
    if tty.readline().strip() != "GUARDADA":
        tty.write("Cancelado: no declaraste custodia externa.\n")
        tty.flush()
        raise SystemExit(7)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, "w") as output:
    output.write(key + "\n")
os.chmod(path, 0o600)
print("CLAVE_GUARDADA_FUERA_DEL_SERVIDOR=CONFIRMADA_POR_USUARIO")
print("CLAVE_EN_ARCHIVO_PRIVADO_ROOT_0600=OK")
PY
KEY_SAVED=1

PHASE=CONFIG_RESTIC
# Archivo raíz sin contraseña embebida; rutas invariables y conocidas.
(
  set -C
  cat > "$CONFIG_FILE" <<'EOF'
RESTIC_REPOSITORY="rclone:vencira_google:VENCIRA-Backups/PostgreSQL"
RESTIC_PASSWORD_FILE="/etc/vencira-backup/restic-password"
RCLONE_CONFIG="/etc/vencira-backup/rclone.conf"
EOF
)
chmod 0600 "$CONFIG_FILE"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG

PHASE=REPO_INIT
echo "=== CREAR REPOSITORIO CIFRADO DRIVE ==="
restic init --quiet
REPO_READY=1
echo "RESTIC_REPOSITORIO_REMOTO=CREADO"

PHASE=PRUEBA_SINTETICA
echo "=== PRUEBA CIFRADO + LECTURA DESDE DRIVE ==="
restic backup --quiet --tag o5-synthetic-proof \
  --stdin-filename o5-synthetic-proof.txt \
  --stdin-from-command -- sh -c 'printf "VENCIRA-O5-PRUEBA-SINTETICA\n"'
value="$(restic dump latest o5-synthetic-proof.txt)"
test "$value" = VENCIRA-O5-PRUEBA-SINTETICA || {
  echo "ERROR: contenido de prueba recuperado incorrecto"; exit 8;
}
restic check >/dev/null
test "$(stat -c '%u:%a' "$RESTIC_PASSWORD_FILE")" = 0:600
test "$(stat -c '%u:%a' "$CONFIG_FILE")" = 0:600
PROOF_OK=1
echo "PRUEBA_CIFRADA_DRIVE_RESTAURACION=OK"
echo "RESTIC_CHECK=OK"
echo "SECRETO_RECUPERACION_CUSTODIADO=CONFIRMADO_POR_USUARIO"
