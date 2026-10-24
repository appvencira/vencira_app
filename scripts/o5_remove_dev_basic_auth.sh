#!/usr/bin/env bash
# VENCIRA DEV: quitar SOLO la autenticación HTTP Basic Auth del sitio
# dev.vencira.es. Preserva un respaldo privado para rollback.
# Ejecución manual por titular desde SSH: sudo bash scripts/o5_remove_dev_basic_auth.sh
# No toca Django, Docker, Postgres, Restic, Google OAuth ni DNS.
set -Eeuo pipefail
umask 077

CONFIG=/etc/caddy/Caddyfile
PHASE=INICIO
CHANGED=0
BACKUP=""
BACKUP_DIR=""
CANDIDATE=""

finish() {
  local rc=$?
  local recover=0
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$CHANGED" -eq 1 ]; then
    echo "=== REVERSION DE CADDY ==="
    if [ -n "$BACKUP" ] && [ -f "$BACKUP" ] && \
       install -o "$OWNER" -g "$GROUP" -m "$MODE" "$BACKUP" "$CANDIDATE" && \
       mv -f -- "$CANDIDATE" "$CONFIG" && \
       caddy validate --config "$CONFIG" --adapter caddyfile >/dev/null 2>&1 && \
       systemctl reload caddy >/dev/null 2>&1; then
      echo "CADDY_CONFIG_ORIGINAL_RESTAURADA=1"
      echo "CADDY_RECARGA_REVERSION=OK"
    else
      echo "ATENCION=REVISION_MANUAL_DE_CADDY_NECESARIA"
      recover=1
    fi
  fi
  if [ -n "$CANDIDATE" ] && [ -e "$CANDIDATE" ]; then
    rm -f -- "$CANDIDATE" || recover=1
  fi
  if [ "$recover" -ne 0 ]; then rc=9; fi
  if [ "$rc" -eq 0 ]; then
    echo "BASIC_AUTH_DEV_RETIRADA=OK"
    echo "CADDY_RECARGADO=OK"
  else
    echo "FASE_FALLIDA=$PHASE"
  fi
  echo "NO_DOCKER_NI_POSTGRES_NI_RESTIC_MODIFICADOS=1"
  echo "RESULTADO_GLOBAL=$rc"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=PREVIO
test "$EUID" -eq 0 || { echo "ERROR=EJECUTAR_CON_SUDO"; exit 2; }
command -v caddy >/dev/null
command -v curl >/dev/null
command -v python3 >/dev/null
systemctl is-active --quiet caddy
test -f "$CONFIG" && test ! -L "$CONFIG"
OWNER="$(stat -c %u "$CONFIG")"
GROUP="$(stat -c %g "$CONFIG")"
MODE="$(stat -c %a "$CONFIG")"
SERVICE_USER="$(systemctl show caddy -p User --value)"
test -n "$SERVICE_USER" || { echo "ERROR=SERVICIO_CADDY_SIN_USUARIO_IDENTIFICABLE"; exit 2; }
command -v runuser >/dev/null
if ! runuser -u "$SERVICE_USER" -- test -r "$CONFIG"; then
  echo "ERROR=CADDY_NO_PUEDE_LEER_CONFIG_CORREGIR_PERMISOS_ANTES"
  exit 2
fi
echo "CADDY_SERVICIO_PUEDE_LEER_CONFIG=OK"
echo "CADDY_ACTIVO=1"
echo "CONFIG_ESTRUCTURA_L1_L19=PREVALIDACION"

PHASE=RESPALDO_PRIVADO
BACKUP_DIR="$(mktemp -d /etc/caddy/.vencira-dev-auth-rollback.XXXXXXXX)"
chmod 0700 "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/Caddyfile.original"
install -o root -g root -m 0600 "$CONFIG" "$BACKUP"
test "$(stat -c '%u:%a' "$BACKUP_DIR")" = "0:700"
test "$(stat -c '%u:%a' "$BACKUP")" = "0:600"
echo "CONFIG_CADDY_COPIA_PRIVADA=OK"
echo "BACKUP_PRIVADO_LOCAL=$BACKUP_DIR"

PHASE=PREPARAR_CAMBIO_MINIMO
CANDIDATE="$(mktemp /etc/caddy/.vencira-candidate.XXXXXXXX)"
python3 - "$CONFIG" "$CANDIDATE" <<'PY'
import pathlib, re, sys
src = pathlib.Path(sys.argv[1]).read_bytes()
lines = src.splitlines(keepends=True)
def s(index):
    return lines[index].decode("utf-8").strip()
valid = len(lines) >= 19
if valid:
    valid = (
        s(0) == "dev.vencira.es {"
        and re.fullmatch(r"(?:basic_auth|basicauth)\s*\{", s(1)) is not None
        and len(s(2).split()) == 2
        and s(3) == "}"
        and s(5).startswith("respond ")
        and s(7).startswith("handle ")
        and s(8).startswith("reverse_proxy ")
        and s(11).startswith("handle ")
        and s(12).startswith("reverse_proxy ")
        and s(15).startswith("handle ")
        and s(16).startswith("reverse_proxy ")
        and s(18) == "}"
    )
if not valid:
    raise SystemExit("ERROR=ESTRUCTURA_NO_COINCIDE_NO_SE_MODIFICA")
# Excluir estrictamente las líneas 2, 3 y 4; el resto es byte a byte idéntico.
pathlib.Path(sys.argv[2]).write_bytes(b"".join(lines[:1] + lines[4:]))
print("CAMBIO_LIMITADO_A_L2_L4=OK")
PY
chown "$OWNER:$GROUP" "$CANDIDATE"
chmod "$MODE" "$CANDIDATE"
if ! runuser -u "$SERVICE_USER" -- test -r "$CANDIDATE"; then
  echo "ERROR=CADDY_NO_PUEDE_LEER_CONFIG_CANDIDATA"
  exit 2
fi

PHASE=VALIDAR_CANDIDATO
if ! caddy validate --config "$CANDIDATE" --adapter caddyfile >/dev/null 2>&1; then
  echo "ERROR=CONFIG_CANDIDATA_NO_VALIDADA"
  exit 3
fi
echo "CADDY_CANDIDATO_VALIDADO=OK"

PHASE=APLICAR_Y_RECARGAR
mv -f -- "$CANDIDATE" "$CONFIG"
CHANGED=1
if ! systemctl reload caddy >/dev/null 2>&1; then
  echo "ERROR=RECARGA_CADDY"
  exit 4
fi
echo "CADDY_RELOAD_INICIAL=OK"

PHASE=VERIFICAR_PUBLICO_Y_ACCESO_APP
check() {
  curl --noproxy '*' -sS --max-time 15 --connect-timeout 5 -o /dev/null \
     -w '%{http_code}' "https://dev.vencira.es$1" 2>/dev/null || true
}
ROOT_HTTP="$(check /)"
ME_HTTP="$(check /api/v1/me/)"
ADMIN_HTTP="$(check /admin/)"
echo "DEV_RAIZ_HTTP=$ROOT_HTTP"
echo "DEV_ME_ANONIMO_HTTP=$ME_HTTP"
echo "DEV_ADMIN_ANONIMO_HTTP=$ADMIN_HTTP"
case "$ROOT_HTTP" in 200|301|302|303|307|308) ;; *) echo "ERROR=DEV_NO_PUBLICA_RAIZ"; exit 5;; esac
case "$ME_HTTP" in 401|403) ;; *) echo "ERROR=API_NO_RECHAZA_ANONIMO"; exit 5;; esac
test "$ADMIN_HTTP" = 404 || { echo "ERROR=ADMIN_NO_BLOQUEADO"; exit 5; }
echo "INICIO_SESION_APP_Y_ADMIN_PROTEGIDOS=OK"
PHASE=OK
