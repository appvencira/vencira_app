#!/usr/bin/env bash
# O5: envoltorio root de copia manual existente; graba estado sin secretos.
set -Eeuo pipefail
umask 077
STATE=/var/lib/vencira-o5
PHASE=PRECHECK
finish(){
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    if [ -d "$STATE" ] && [ "$(stat -c '%u:%a' "$STATE")" = 0:700 ]; then
      tmp="$(mktemp "$STATE/.failure.XXXXXXXX")"
      printf '%s\n' "$(date -u +%s)" > "$tmp"
      chmod 0600 "$tmp"
      mv -f "$tmp" "$STATE/last-failure.epoch"
    fi
    echo "O5_BACKUP_DIARIO=ERROR"
    echo "FASE_FALLIDA=$PHASE"
  fi
  echo "RESULTADO_GLOBAL=$rc"
  exit "$rc"
}
trap finish EXIT
test "$(id -u)" -eq 0
test -d "$STATE" && test ! -L "$STATE"
test "$(stat -c '%u:%a' "$STATE")" = 0:700
test -f "$STATE/oauth-postproduction.epoch" && test ! -L "$STATE/oauth-postproduction.epoch"
test "$(stat -c '%u:%a' "$STATE/oauth-postproduction.epoch")" = 0:600
test -r /usr/local/libexec/vencira/o5_backup_to_drive.sh
PHASE=BACKUP_CIFRADO
bash /usr/local/libexec/vencira/o5_backup_to_drive.sh
PHASE=MARCADOR_EXITO
tmp="$(mktemp "$STATE/.success.XXXXXXXX")"
printf '%s\n' "$(date -u +%s)" > "$tmp"
chmod 0600 "$tmp"
mv -f "$tmp" "$STATE/last-success.epoch"
rm -f -- "$STATE/last-failure.epoch"
echo "O5_BACKUP_DIARIO=OK"
