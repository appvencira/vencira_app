#!/usr/bin/env bash
# O5: validar repositorio Restic EXISTENTE y el snapshot original. Solo lectura.
set -Eeuo pipefail
umask 077
PHASE=IDENTIDAD
finish(){ rc=$?; trap - EXIT; echo "RESULTADO_GLOBAL=$rc"; if [ "$rc" -ne 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi; exit "$rc"; }
trap finish EXIT
test "$(id -u)" -eq 0 || { echo "ERROR=SOLO_ROOT"; exit 2; }
CFG=/etc/vencira-backup
test -d "$CFG" && test ! -L "$CFG" && test "$(stat -c %u:%a "$CFG")" = 0:700
for f in config.env restic-password rclone.conf; do
  test -f "$CFG/$f" && test ! -L "$CFG/$f"
  test "$(stat -c %u:%a "$CFG/$f")" = 0:600
done
PHASE=CONFIG
# shellcheck disable=SC1091
. "$CFG/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = "$CFG/restic-password"
test "$RCLONE_CONFIG" = "$CFG/rclone.conf"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
command -v restic >/dev/null
command -v python3 >/dev/null
PHASE=RESTIC_SNAPSHOT
restic snapshots --json --tag vencira-postgresql |
 python3 -c 'import json,sys
rows=json.load(sys.stdin)
if not isinstance(rows,list) or not any(
    isinstance(x,dict) and str(x.get("id","")).startswith("7a2f5018")
    and "vencira-postgresql" in x.get("tags",[])
    for x in rows):
    raise SystemExit("ERROR=SNAPSHOT_7a2f5018_NO_ACCESIBLE")
print("RESTIC_SNAPSHOT_ORIGINAL=OK")'
echo "RESTIC_REPOSITORIO_EXISTENTE=OK"
