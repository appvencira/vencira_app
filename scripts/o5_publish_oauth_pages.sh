#!/usr/bin/env bash
# VENCIRA O5: publica solo paginas estaticas en oauth.vencira.es.
# Precondicion: DNS A oauth.vencira.es -> 93.93.112.172, sin AAAA incorrecto.
# Sin cambios en Docker, PostgreSQL, Restic, OAuth ni en la app DEV.
set -Eeuo pipefail
umask 077

CONFIG=/etc/caddy/Caddyfile
SITE=/srv/vencira-oauth-site
SOURCE=/home/vencira/vencira-localcheck/public/oauth-backups
PHASE=INICIO
CHANGED=0
SITE_CREATED=0
STAGING=""
CANDIDATE=""
BACKUP=""
BACKUP_DIR=""

finish() {
  local rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ] && [ "$CHANGED" -eq 1 ]; then
    local tmp=""
    tmp="$(mktemp /etc/caddy/.vencira-oauth-restore.XXXXXXXX)" || true
    if [ -n "$tmp" ] && [ -f "$BACKUP" ] && \
       install -o root -g caddy -m 0640 "$BACKUP" "$tmp" && \
       mv -f -- "$tmp" "$CONFIG" && \
       caddy validate --config "$CONFIG" --adapter caddyfile >/dev/null 2>&1 && \
       systemctl reload caddy >/dev/null 2>&1; then
      echo "CADDY_REVERSION=OK"
    else
      echo "CADDY_REVERSION=REVISION_MANUAL_NECESARIA"
      echo "COPIA_CADDY_PRIVADA=$BACKUP"
      rc=9
    fi
    if [ -n "$tmp" ] && [ -f "$tmp" ]; then rm -f -- "$tmp"; fi
  fi
  if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE" ]; then rm -f -- "$CANDIDATE"; fi
  if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then rm -rf -- "$STAGING"; fi
  if [ "$rc" -eq 0 ]; then
    echo "SITIO_OAUTH_PUBLICADO=OK"
    echo "HTTPS_OAUTH_PUBLICO=OK"
  else
    echo "FASE_FALLIDA=$PHASE"
    if [ "$SITE_CREATED" -eq 1 ]; then echo "STATIC_SITE_LOCAL=$SITE"; fi
  fi
  echo "DOCKER_PG_RESTIC_DEV_NO_MODIFICADOS=1"
  echo "RESULTADO_GLOBAL=$rc"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

PHASE=IDENTIDAD
test "$EUID" -eq 0 || { echo "ERROR=EJECUTAR_CON_SUDO"; exit 2; }
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -f "$SOURCE/index.html"
test -f "$SOURCE/privacidad/index.html"
test -f "$SOURCE/condiciones/index.html"
test -f "$SOURCE/assets/site.css"
test -f "$CONFIG" && test ! -L "$CONFIG"
test ! -e "$SITE"
systemctl is-active --quiet caddy
test "$(systemctl show caddy -p User --value)" = caddy
test "$(stat -c '%U:%G:%a' "$CONFIG")" = root:caddy:640
runuser -u caddy -- test -r "$CONFIG"
grep -Fxq "dev.vencira.es {" "$CONFIG"
if grep -Eq '^[[:space:]]*oauth[.]vencira[.]es[[:space:]]*[{]' "$CONFIG"; then
  echo "ERROR=OAUTH_YA_CONFIGURADO"
  exit 3
fi
echo "COMMIT=$(git rev-parse HEAD)"
echo "CADDY_PRECHECK=OK"

PHASE=DNS
python3 - <<'PY'
import socket
try:
    addresses = {i[4][0] for i in socket.getaddrinfo(
        "oauth.vencira.es", 443, type=socket.SOCK_STREAM)}
except socket.gaierror:
    addresses = set()
if addresses != {"93.93.112.172"}:
    print("DNS_OAUTH_NO_LISTO=1")
    print("ACCION=VERIFICAR_REGISTROS_A_Y_AAAA")
    raise SystemExit(4)
print("DNS_OAUTH=OK")
PY

PHASE=PROTECCIONES_PREVIAS
dev_code() {
  curl --noproxy '*' -sS -o /dev/null --connect-timeout 4 --max-time 12 \
    -w '%{http_code}' "https://dev.vencira.es$1" 2>/dev/null || true
}
test "$(dev_code /)" = 200 || { echo "ERROR=DEV_RAIZ_PREVIA"; exit 5; }
test "$(dev_code /api/v1/me/)" = 403 || { echo "ERROR=DEV_API_PREVIA"; exit 5; }
test "$(dev_code /admin/)" = 404 || { echo "ERROR=DEV_ADMIN_PREVIO"; exit 5; }
echo "DEV_PRECHECK=OK"

PHASE=RESPALDO
BACKUP_DIR="$(mktemp -d /etc/caddy/.vencira-oauth-rollback.XXXXXXXX)"
chmod 0700 "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/Caddyfile.original"
install -o root -g root -m 0600 "$CONFIG" "$BACKUP"
echo "CADDY_RESPALDO_PRIVADO=OK"
echo "COPIA_CADDY_PRIVADA=$BACKUP"

PHASE=STATIC
STAGING="$(mktemp -d /srv/.vencira-oauth-staging.XXXXXXXX)"
cp -a "$SOURCE/." "$STAGING/"
find "$STAGING" -type d -exec chmod 0755 {} +
find "$STAGING" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGING"
test -s "$STAGING/index.html"
test -s "$STAGING/privacidad/index.html"
test -s "$STAGING/condiciones/index.html"
mv -T -- "$STAGING" "$SITE"
STAGING=""
SITE_CREATED=1
runuser -u caddy -- test -r "$SITE/index.html"
runuser -u caddy -- test -r "$SITE/privacidad/index.html"
echo "STATIC_SITE=OK"

PHASE=CADDY_CANDIDATO
CANDIDATE="$(mktemp /etc/caddy/.vencira-oauth-candidate.XXXXXXXX)"
cat "$CONFIG" > "$CANDIDATE"
cat >> "$CANDIDATE" <<'CADDY'

# Sitio informativo OAuth del sistema interno de backups.
oauth.vencira.es {
    root * /srv/vencira-oauth-site
    encode zstd gzip
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "no-referrer"
        Content-Security-Policy "default-src 'none'; style-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    }
    file_server
}
CADDY
chown root:caddy "$CANDIDATE"
chmod 0640 "$CANDIDATE"
runuser -u caddy -- test -r "$CANDIDATE"
runuser -u caddy -- caddy validate --config "$CANDIDATE" --adapter caddyfile >/dev/null 2>&1
echo "CADDY_CANDIDATO_VALIDADO=OK"

PHASE=RECARGA
mv -f -- "$CANDIDATE" "$CONFIG"
CHANGED=1
systemctl reload caddy >/dev/null 2>&1 || { echo "ERROR=RECARGA_CADDY"; exit 6; }
echo "CADDY_RELOAD=OK"

PHASE=HTTPS_Y_AISLAMIENTO
oauth_code() {
  curl --noproxy '*' -sS -o /dev/null --connect-timeout 4 --max-time 12 \
    -w '%{http_code}' "https://oauth.vencira.es$1" 2>/dev/null || true
}
HOME=000
PRIV=000
COND=000
for i in 1 2 3 4 5 6 7 8; do
  HOME="$(oauth_code /)"
  PRIV="$(oauth_code /privacidad/)"
  COND="$(oauth_code /condiciones/)"
  if [ "$HOME:$PRIV:$COND" = "200:200:200" ]; then break; fi
  sleep 5
done
echo "OAUTH_HOME_HTTP=$HOME"
echo "OAUTH_PRIVACIDAD_HTTP=$PRIV"
echo "OAUTH_CONDICIONES_HTTP=$COND"
test "$HOME:$PRIV:$COND" = 200:200:200 || {
  echo "ERROR=HTTPS_OAUTH_SIN_CONFIRMAR"
  exit 7
}
test "$(dev_code /)" = 200
test "$(dev_code /api/v1/me/)" = 403
test "$(dev_code /admin/)" = 404
echo "DEV_SIN_REGRESIONES=OK"
PHASE=OK
