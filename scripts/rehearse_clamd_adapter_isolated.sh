#!/usr/bin/env bash
# C-FICHA: real clamd Unix-socket INSTREAM adapter rehearsal, isolated.
# Entirely synthetic data; no persistent DB, secrets or app deployment.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
LOG="$(mktemp /tmp/vencira-clamd-adapter.XXXXXXXX.log)"
ROOT="$(mktemp -d /tmp/vencira-clamd-socket.XXXXXXXX)"
NAME="vencira_clamd_rehearsal_$$"
STARTED=0
cleanup() {
  rc=$?
  trap - EXIT
  if [ "$STARTED" -eq 1 ]; then
    sudo docker rm -f "$NAME" >>"$LOG" 2>&1 || rc=1
  fi
  rm -rf -- "$ROOT"
  if [ "$rc" -ne 0 ]; then tail -n 40 "$LOG"; fi
  echo "C_FICHA_REAL_CLAMD_ADAPTER_RESULT=$rc"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "LOG_LOCAL=$LOG"
  exit "$rc"
}
trap cleanup EXIT
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
# The official image provides signatures; network is disabled at runtime.
sudo docker pull clamav/clamav:stable >>"$LOG" 2>&1
sudo docker build -q -t vencira-clamd-test:local ./backend >>"$LOG" 2>&1
sudo chgrp 101 "$ROOT"
chmod 2770 "$ROOT" # restricted shared group
# Use clamav image signatures and run clamd with its default configuration;
# the local socket is set explicitly. No port is published and no network exists.
sudo docker run -d --name "$NAME" --network none \
  --memory 4g --cpus 2 --pids-limit 128 \
  --cap-drop ALL --security-opt no-new-privileges \
  --mount "type=bind,src=$ROOT,dst=/scan-socket" \
  --user clamav --entrypoint /bin/sh clamav/clamav:stable \
  -c 'sed -e "/^LogFile /d" -e "/^User /d" -e "/^LocalSocket /d" -e "/^TCPSocket /d" -e "/^LocalSocketMode /d" /etc/clamav/clamd.conf > /tmp/vencira-clamd.conf && printf "\nLocalSocket /scan-socket/clamd.sock\nLocalSocketMode 660\n" >> /tmp/vencira-clamd.conf && exec clamd --foreground --config-file=/tmp/vencira-clamd.conf' >>"$LOG" 2>&1
STARTED=1
# Require the explicitly configured Unix socket; never fall back to TCP.
READY=0
for _ in $(seq 1 45); do
  if [ -S "$ROOT/clamd.sock" ]; then READY=1; break; fi
  if [ "$(sudo docker inspect -f "{{.State.Running}}" "$NAME")" != "true" ]; then
    echo "CLAMD_CONTAINER_EXITED_EARLY=1"
    exit 1
  fi
  sleep 2
done
if [ "$READY" -ne 1 ]; then
  echo "CLAMD_EXPECTED_SOCKET_NOT_READY=1"
  exit 1
fi
sudo docker run --rm --network none \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
  -e DJANGO_SECRET_KEY=synthetic-only-clamd-test-key-long-2026 \
  -e DJANGO_ALLOWED_HOSTS=localhost \
  --group-add 101 \
  --mount "type=bind,src=$ROOT,dst=/scan-socket,readonly" \
  vencira-clamd-test:local python -c '
from reminders.attachment_clamav_adapter import scan_with_clamd
path = "/scan-socket/clamd.sock"
clean = scan_with_clamd(payload=b"VENCIRA synthetic clean fixture", unix_socket=path,
                        timeout_seconds=15)
assert clean.verdict == "clean", clean
eicar = b"X5O!P%@AP[4" + bytes([92]) + b"PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
assert len(eicar) == 68, len(eicar)
infected = scan_with_clamd(payload=eicar, unix_socket=path,
                           timeout_seconds=15)
assert infected.verdict == "infected", infected
print("C_FICHA_REAL_CLAMD_INSTREAM_CLEAN=OK")
print("C_FICHA_REAL_CLAMD_INSTREAM_EICAR=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_REAL_CLAMD_ADAPTER=OK"
echo "C_FICHA_REAL_CLAMD_FILE_RELEASE=DISABLED"
