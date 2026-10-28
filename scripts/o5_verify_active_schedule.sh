#!/usr/bin/env bash
# O5: validación final sin cambios, sin imprimir secretos ni datos de clientes.
set -Eeuo pipefail
umask 077
PHASE=TIMERS
finish() {
  rc=$?
  trap - EXIT
  echo "RESULTADO_GLOBAL=$rc"
  if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
  echo "SIN_CAMBIOS_EN_TIMERS_POSTGRES_O_RESTIC=1"
  echo "CONSOLA_ABIERTA"
  exit "$rc"
}
trap finish EXIT
test "$(id -u)" -eq 0 || { echo "ERROR=REQUIERE_ROOT"; exit 2; }
for u in vencira-o5-backup.timer vencira-o5-health.timer; do
  test "$(systemctl is-active "$u" 2>/dev/null)" = active
  test "$(systemctl is-enabled "$u" 2>/dev/null)" = enabled
done
echo "TIMERS_ACTIVOS_Y_HABILITADOS=OK"
for u in vencira-o5-backup.service vencira-o5-health.service; do
  test "$(systemctl is-failed "$u" 2>/dev/null || true)" != failed
done
echo "SERVICIOS_SIN_ESTADO_FAILED=OK"

PHASE=MARCADOR
DIR=/var/lib/vencira-o5
test -d "$DIR" && test ! -L "$DIR"
test "$(stat -c %u:%a "$DIR")" = 0:700
for f in last-success.epoch oauth-postproduction.epoch; do
  test -f "$DIR/$f" && test ! -L "$DIR/$f"
  test "$(stat -c %u:%a "$DIR/$f")" = 0:600
done
test ! -e "$DIR/last-failure.epoch"
success_epoch="$(cat "$DIR/last-success.epoch")"
oauth_epoch="$(cat "$DIR/oauth-postproduction.epoch")"
[[ "$success_epoch" =~ ^[0-9]{10}$ ]]
[[ "$oauth_epoch" =~ ^[0-9]{10}$ ]]
now="$(date -u +%s)"
test "$success_epoch" -le "$now" && test "$((now-success_epoch))" -le 129600
test "$oauth_epoch" -le "$now"
echo "MARCADOR_EXITO_MENOS_36H=OK"
if [ "$success_epoch" -ge "$oauth_epoch" ]; then
  echo "COPIA_TRAS_REAUTORIZACION=SI"
else
  echo "COPIA_TRAS_REAUTORIZACION=NO"
fi

PHASE=CONFIG_RESTIC
CFG=/etc/vencira-backup
test -d "$CFG" && test ! -L "$CFG" && test "$(stat -c %u:%a "$CFG")" = 0:700
for f in config.env restic-password rclone.conf; do
  test -f "$CFG/$f" && test ! -L "$CFG/$f"
  test "$(stat -c %u:%a "$CFG/$f")" = 0:600
done
# shellcheck disable=SC1091
. "$CFG/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = "$CFG/restic-password"
test "$RCLONE_CONFIG" = "$CFG/rclone.conf"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG

PHASE=SNAPSHOT_REMOTO
restic snapshots --json --tag vencira-postgresql |
python3 -c 'import json,sys,time,datetime
data=json.load(sys.stdin)
if not isinstance(data,list) or not data:
    raise SystemExit("ERROR=NO_HAY_SNAPSHOTS_POSTGRES")
rows=[]
for obj in data:
    if not isinstance(obj,dict): continue
    if "vencira-postgresql" not in obj.get("tags",[]): continue
    raw=obj.get("time")
    try:
        stamp=int(datetime.datetime.fromisoformat(raw.replace("Z","+00:00")).timestamp())
        rows.append(stamp)
    except (TypeError,AttributeError,ValueError): continue
if not rows:
    raise SystemExit("ERROR=NO_HAY_FECHAS_SNAPSHOT_VALIDAS")
age=int(time.time())-max(rows)
if age<0: raise SystemExit("ERROR=SNAPSHOT_FECHA_FUTURA")
print("SNAPSHOTS_POSTGRES_EN_RESTIC=OK")
print("ULTIMO_SNAPSHOT_ANTIGUEDAD_SEGUNDOS="+str(age))
print("ULTIMO_SNAPSHOT_MENOS_36H="+("SI" if age<=129600 else "NO"))'
echo "ACCESO_RESTIC_READ_ONLY=OK"

PHASE=CALENDARIO
echo "=== PROXIMAS_EJECUCIONES ==="
systemctl list-timers --all --no-pager --no-legend \
  vencira-o5-backup.timer vencira-o5-health.timer |
  sed -E 's/[[:space:]]+/ /g'
echo "AUDITORIA_FINAL_O5=OK"
