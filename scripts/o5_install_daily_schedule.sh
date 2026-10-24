#!/usr/bin/env bash
# O5: instalación controlada de backups DEV diarios. Requiere reconnect OAuth postproduction.
# No tocar DEV DB, servicios Docker, Caddy, contraseñas Restic ni datos reales.
set -Eeuo pipefail
umask 077
PHASE=IDENTIDAD
BASE=/home/vencira/vencira-localcheck
SRC=$BASE/deploy/o5
DST=/usr/local/libexec/vencira
UNITDIR=/etc/systemd/system
CREATED=0
STARTED=0
DONE=0

finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    if [ "$CREATED" -eq 1 ]; then
      # Rollback SOLO de unidades de esta operación. Nunca borra backups.
      systemctl disable --now vencira-o5-backup.timer vencira-o5-health.timer >/dev/null 2>&1 || true
      for u in backup.service backup.timer health.service health.timer; do
        rm -f -- "$UNITDIR/vencira-o5-$u"
      done
      systemctl daemon-reload >/dev/null 2>&1 || true
      rm -rf -- "$DST"
      echo "REVERSION_UNIDADES_O5=OK"
    fi
    if [ "$STARTED" -eq 1 ]; then
      echo "COPIA_PRUEBA_EJECUTADA_REVISAR_SNAPSHOT=1"
    fi
  else
    echo "O5_TIMERS_INSTALADOS=OK"
  fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT

test "$(id -u)" -eq 0 || { echo "ERROR=SOLO_ROOT"; exit 2; }
cd "$BASE"
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
echo "COMMIT=$(git rev-parse HEAD)"

PHASE=RESTRICCIONES
test ! -e "$DST" && test ! -L "$DST"
for u in backup.service backup.timer health.service health.timer; do
  test ! -e "$UNITDIR/vencira-o5-$u"
  test ! -L "$UNITDIR/vencira-o5-$u"
  test -s "$SRC/vencira-o5-$u"
done
for s in o5_backup_to_drive.sh o5_scheduled_backup.sh o5_backup_health.sh o5_verify_existing_drive.sh; do
  test -s "$BASE/scripts/$s"
  bash -n "$BASE/scripts/$s"
done
test -d /var/lib/vencira-o5
test ! -L /var/lib/vencira-o5
test "$(stat -c '%u:%a' /var/lib/vencira-o5)" = 0:700
test -f /var/lib/vencira-o5/oauth-postproduction.epoch
test ! -L /var/lib/vencira-o5/oauth-postproduction.epoch
test "$(stat -c '%u:%a' /var/lib/vencira-o5/oauth-postproduction.epoch)" = 0:600
systemd-analyze calendar '*-*-* 03:00:00 Europe/Madrid' >/dev/null
systemd-analyze calendar '*-*-* 08:00:00 Europe/Madrid' >/dev/null
echo "PREFLIGHT_O5=OK"

PHASE=STACK_DEV
for svc in api db web_preview; do
  container="vencira_localcheck-$svc-1"
  test "$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
  test "$(docker inspect "$container" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy
done
echo "STACK_DEV_HEALTHY=OK"

PHASE=VERIFICAR_REPO
bash scripts/o5_verify_existing_drive.sh
echo "REPOSITORIO_PREEXISTENTE_VERIFICADO=OK"

PHASE=INSTALAR_SCRIPTS
install -d -o root -g root -m 0755 /usr/local/libexec
install -d -o root -g root -m 0700 "$DST"
CREATED=1
for s in o5_backup_to_drive.sh o5_scheduled_backup.sh o5_backup_health.sh; do
  install -o root -g root -m 0700 "$BASE/scripts/$s" "$DST/$s"
done
for u in backup.service backup.timer health.service health.timer; do
  install -o root -g root -m 0644 "$SRC/vencira-o5-$u" "$UNITDIR/vencira-o5-$u"
done

PHASE=VALIDAR_SYSTEMD
systemctl daemon-reload
systemd-analyze verify \
  "$UNITDIR/vencira-o5-backup.service" \
  "$UNITDIR/vencira-o5-backup.timer" \
  "$UNITDIR/vencira-o5-health.service" \
  "$UNITDIR/vencira-o5-health.timer"
echo "UNIDADES_SYSTEMD_VALIDAS=OK"

PHASE=COPIA_PRUEBA
STARTED=1
systemctl start vencira-o5-backup.service
echo "PRIMERA_COPIA_AUTOMATIZABLE=OK"

PHASE=COMPROBAR_FRESCURA
systemctl start vencira-o5-health.service
echo "O5_FRESCURA_COPIA=OK"

PHASE=ACTIVAR_TIMERS
systemctl enable --now vencira-o5-backup.timer vencira-o5-health.timer
systemctl is-active --quiet vencira-o5-backup.timer
systemctl is-active --quiet vencira-o5-health.timer
systemctl is-enabled --quiet vencira-o5-backup.timer
systemctl is-enabled --quiet vencira-o5-health.timer
echo "O5_BACKUP_DIARIO_03_MADRID=ACTIVO"
echo "O5_CHECK_DIARIO_08_MADRID=ACTIVO"
echo "ALERTA_JOURNAL_LOCAL=ACTIVA"
echo "NOTIFICACION_EXTERNA=NO_CONFIGURADA"
echo "RETENCION_DESTRUCTIVA=NO_ACTIVADA"
echo "SIN_MIGRACIONES_CAMBIOS_DB_DOCKER_CADDY=1"
PHASE=OK
DONE=1
