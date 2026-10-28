#!/usr/bin/env bash
# O5: diagnóstico local sin credenciales. No manda emails ni push.
set -Eeuo pipefail
umask 077
STATE=/var/lib/vencira-o5
test "$(id -u)" -eq 0
test -d "$STATE" && test ! -L "$STATE"
test "$(stat -c '%u:%a' "$STATE")" = 0:700
test -f "$STATE/last-success.epoch" && test ! -L "$STATE/last-success.epoch" || { echo "O5_COPIA_RECIENTE=NO_EXISTE"; exit 2; }
test "$(stat -c '%u:%a' "$STATE/last-success.epoch")" = 0:600
last="$(cat "$STATE/last-success.epoch")"
case "$last" in ""|*[!0-9]*) echo "O5_MARCADOR_INVALIDO=1"; exit 2;; esac
now="$(date -u +%s)"
age="$((now-last))"
# 36 horas para la copia diaria a las 03:00, margen para cortes.
if [ "$age" -lt 0 ] || [ "$age" -gt 129600 ]; then
  echo "O5_COPIA_RECIENTE=NO"
  echo "ANTIGUEDAD_SEGUNDOS=$age"
  exit 1
fi
if systemctl is-failed --quiet vencira-o5-backup.service; then
  echo "O5_SERVICIO_COPIA=FAILED"
  exit 1
fi
if [ -f "$STATE/last-failure.epoch" ]; then
  echo "O5_ULTIMA_EJECUCION=ERROR"
  exit 1
fi
echo "O5_COPIA_RECIENTE=OK"
echo "ANTIGUEDAD_SEGUNDOS=$age"
