#!/usr/bin/env bash
# O5 — solo diagnóstico del gate RESTRICCIONES; NO modifica el servidor.
set -u
BASE=/home/vencira/vencira-localcheck
DST=/usr/local/libexec/vencira
SRC="$BASE/deploy/o5"
UNITDIR=/etc/systemd/system
FALLAS=0
check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "$name=OK"
  else
    echo "$name=FALLO"
    FALLAS=$((FALLAS + 1))
  fi
}
check ROOT_ACTUAL test "$(id -u)" -eq 0
check RAMA_ESPERADA sh -c 'cd /home/vencira/vencira-localcheck && test "$(git branch --show-current)" = integration/local-e2e-prep'
check GIT_TRACKED_LIMPIO sh -c 'cd /home/vencira/vencira-localcheck && git diff --quiet && git diff --cached --quiet'
check DESTINO_INSTALACION_LIBRE sh -c 'test ! -e /usr/local/libexec/vencira && test ! -L /usr/local/libexec/vencira'
for u in backup.service backup.timer health.service health.timer; do
  case "$u" in
    backup.service) TAG=BACKUP_SERVICE ;;
    backup.timer) TAG=BACKUP_TIMER ;;
    health.service) TAG=HEALTH_SERVICE ;;
    health.timer) TAG=HEALTH_TIMER ;;
  esac
  check "UNIDAD_LIBRE_$TAG" sh -c 'test ! -e "$1" && test ! -L "$1"' sh "$UNITDIR/vencira-o5-$u"
  check "UNIDAD_FUENTE_$TAG" test -s "$SRC/vencira-o5-$u"
done
for s in o5_backup_to_drive.sh o5_scheduled_backup.sh o5_backup_health.sh o5_verify_existing_drive.sh; do
  check "FUENTE_$s" test -s "$BASE/scripts/$s"
  check "SINTAXIS_$s" bash -n "$BASE/scripts/$s"
done
check DIRECTORIO_ESTADO_ROOT_700 sh -c 'test -d /var/lib/vencira-o5 && test ! -L /var/lib/vencira-o5 && test "$(stat -c "%u:%a" /var/lib/vencira-o5)" = 0:700'
check MARCADOR_OAUTH_ROOT_600 sh -c 'test -f /var/lib/vencira-o5/oauth-postproduction.epoch && test ! -L /var/lib/vencira-o5/oauth-postproduction.epoch && test "$(stat -c "%u:%a" /var/lib/vencira-o5/oauth-postproduction.epoch)" = 0:600'
check CALENDARIO_BACKUP_03 systemd-analyze calendar '*-*-* 03:00:00 Europe/Madrid'
check CALENDARIO_SALUD_08 systemd-analyze calendar '*-*-* 08:00:00 Europe/Madrid'
echo "DIAGNOSTICO_PRECHECK_FALLAS=$FALLAS"
echo "NO_SE_MODIFICO_CADDY_DOCKER_PG_OAUTH_RESTIC=1"
echo "NO_SE_INSTALARON_UNIDADES_NI_TIMERS=1"
echo "CONSOLA_ABIERTA"
test "$FALLAS" -eq 0
