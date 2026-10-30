#!/usr/bin/env bash
# MB1 end-to-end disposable PG17+synthetic object/journal restore drill.
# NO connection to preview/dev DB, no keys or persistent mounts.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
RUN_ID="mb1e2e_$$"
NET="vencira_${RUN_ID}_net"
SRC="vencira_${RUN_ID}_source"
DST="vencira_${RUN_ID}_target"
ROOT="$(mktemp -d /tmp/vencira-mb1-e2e.XXXXXXXX)"
LOG="$ROOT/drill.log"
phase=SETUP; net=0; src=0; dst=0
cleanup() {
  rc=$?; trap - EXIT
  if [ "$src" = 1 ]; then sudo docker rm -f "$SRC" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$dst" = 1 ]; then sudo docker rm -f "$DST" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$net" = 1 ]; then sudo docker network rm "$NET" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$rc" != 0 ]; then echo "MB1_E2E_FAILED_PHASE=$phase"; tail -n 25 "$LOG"; fi
  echo "MB1_E2E_RESULT=$rc"
  echo "MB1_E2E_LOG_LOCAL=$LOG"
  echo "MB1_OPERATIONAL_RELEASE=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "C_FICHA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
echo "MB1_E2E_COMMIT=$(git rev-parse HEAD)"
IMG="vencira-mb1-e2e:$(git rev-parse --short=12 HEAD)"
phase=BUILD
sudo docker build -t "$IMG" ./backend >>"$LOG" 2>&1
phase=PG17_CREATE
sudo docker network create --internal "$NET" >>"$LOG" 2>&1; net=1
for pair in "$SRC" "$DST"; do
  sudo docker run -d --name "$pair" --network "$NET" \
    -e POSTGRES_DB=mb1 -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=synthetic-mb1-only \
    postgres:17-alpine >>"$LOG" 2>&1
  if [ "$pair" = "$SRC" ]; then src=1; else dst=1; fi
done
for pair in "$SRC" "$DST"; do
  ready=0
  for _ in $(seq 1 40); do
    if sudo docker exec "$pair" pg_isready -U mb1 -d mb1 >>"$LOG" 2>&1; then ready=1; break; fi
    sleep 2
  done
  test "$ready" = 1
done
app() {
  local db="$1"; shift
  sudo docker run --rm --network "$NET" \
    -e VENCIRA_ENV=test -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
    -e VENCIRA_DB_ENGINE=postgresql \
    -e DJANGO_SECRET_KEY=synthetic-mb1-only-long-django-secret \
    -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
    -e POSTGRES_HOST="$db" -e POSTGRES_DB=mb1 \
    -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=synthetic-mb1-only \
    "$IMG" python manage.py "$@"
}
phase=SCHEMA
app "$SRC" migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
app "$SRC" migrate renewal_attachments 0006_ed25519_signature_length --noinput >>"$LOG" 2>&1
phase=FIXTURE
app "$SRC" shell -c '
from datetime import date
from reminders.models import Workspace, Renewal
from renewal_attachments.models import RenewalAttachment
w=Workspace.objects.create(name="MB1_E2E_SYNTHETIC")
r=Renewal.objects.create(workspace=w,customer_reference="MB1-E2E",full_name="Synthetic",expires_on=date(2027,12,1))
RenewalAttachment.objects.create(renewal=r,storage_key="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",display_name="synthetic.pdf",content_type="application/pdf",byte_size=8,sha256="b"*64,state="quarantined")
assert RenewalAttachment.objects.filter(display_name="synthetic.pdf").count()==1
' >>"$LOG" 2>&1
mkdir -m 700 "$ROOT/objects" "$ROOT/journal"
printf 'CIPHER01' > "$ROOT/objects/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
printf '{"version":1,"storage_key":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"pending"}' > "$ROOT/journal/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json"
phase=FREEZE_CLONE
# Prove the synthetic DB's connection inventory is empty before cutting.
# This is NOT a universal writer freeze: host filesystem and other services
# remain outside the controlled disposable scope.
no_extra_sessions() {
  local count
  count="$(sudo docker exec "$SRC" psql -X -A -t -v ON_ERROR_STOP=1 \
    -U mb1 -d mb1 -c "SELECT count(*) FROM pg_stat_activity WHERE datname='mb1' AND backend_type='client backend' AND pid <> pg_backend_pid();")"
  [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -eq 0 ]
}
# Negative: an independently attached psql session must cause fail-closed.
sudo docker exec -d "$SRC" psql -X -v ON_ERROR_STOP=1 -U mb1 -d mb1 \
  -c "SELECT pg_sleep(8);" >>"$LOG" 2>&1
session_seen=0
for _ in $(seq 1 30); do
  if ! no_extra_sessions; then session_seen=1; break; fi
  sleep 0.1
done
test "$session_seen" = 1
# Never terminate unknown connections; wait for our disposable probe to exit.
idle_cut=0
for _ in $(seq 1 120); do
  if no_extra_sessions; then idle_cut=1; break; fi
  sleep 0.1
done
test "$idle_cut" = 1
echo "MB1_E2E_FOREIGN_DB_SESSION_REJECTED=OK"
phase=SOURCE_NETWORK_ISOLATION
# Do not merely inspect connection state: physically disconnect the disposable
# database from its only application network for the whole backup window.
# docker exec still reaches PostgreSQL over its local Unix socket.
sudo docker network disconnect "$NET" "$SRC" >>"$LOG" 2>&1
# Verify no remaining client sessions after network isolation.
no_extra_sessions
echo "MB1_E2E_SOURCE_DB_SESSION_DRAIN=OK"
phase=DENY_NEW_DB_SESSIONS
# Fresh client on the same internal network MUST fail to connect.
if sudo docker run --rm --network "$NET" \
  -e PGPASSWORD=synthetic-mb1-only -e PGCONNECT_TIMEOUT=2 \
  postgres:17-alpine psql -X -v ON_ERROR_STOP=1 \
    -h "$SRC" -U mb1 -d mb1 -c 'SELECT 1' >>"$LOG" 2>&1; then
  echo "MB1_E2E_UNEXPECTED_SOURCE_RECONNECT=1"
  exit 1
fi
# Local maintenance remains available for the trusted pg_dump only.
sudo docker exec "$SRC" psql -X -A -t -v ON_ERROR_STOP=1 \
  -U mb1 -d mb1 -c 'SELECT 1' | grep -qx '1'
echo "MB1_E2E_SOURCE_NETWORK_INGRESS_DENIED=OK"
phase=BACKUP
sudo docker exec "$SRC" pg_dump -Fc -U mb1 -d mb1 > "$ROOT/source.dump"
test -s "$ROOT/source.dump"
sha256sum "$ROOT/objects/"* "$ROOT/journal/"* > "$ROOT/inventory.sha256"
phase=AUTHENTICATED_PACKAGE
# Local fixture and keys are mounted only into an ephemeral no-network
# backend process; no DEV keys or services are involved.
packtool() {
  sudo docker run --rm --network none --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=$ROOT,target=/capture" \
    -e VENCIRA_ENV=test -e MB1_DISPOSABLE_ONLY=1 \
    "$IMG" python -m renewal_attachments.mb1_e2e_authenticated_pack "$1" /capture
}
# Capture a bounded filesystem inventory before packaging. This detects
# noncooperative modifications that persist across the packaging window,
# but cannot prevent changes or detect change-and-revert races.
phase=FILESYSTEM_INVENTORY_PRE
(cd "$ROOT" && find objects journal -type f -print0 | sort -z | xargs -0 sha256sum) > "$ROOT/fs.before"
test "$(wc -l < "$ROOT/fs.before")" -eq 2
phase=AUTHENTICATED_PACK
packtool pack >>"$LOG" 2>&1
phase=FILESYSTEM_INVENTORY_POST
(cd "$ROOT" && find objects journal -type f -print0 | sort -z | xargs -0 sha256sum) > "$ROOT/fs.after"
cmp -s "$ROOT/fs.before" "$ROOT/fs.after"
echo "MB1_E2E_FILESYSTEM_INVENTORY_STABLE=OK"
packtool negative >>"$LOG" 2>&1
rm -f "$ROOT/source.dump"
phase=RESTORE_VERIFIED
# Pipefail rejects authentication/decryption errors before a successful
# restore, and pg_restore rejects an invalid custom-format dump.
packtool stream | sudo docker exec -i "$DST" pg_restore --exit-on-error --no-owner --no-privileges -U mb1 -d mb1 >>"$LOG" 2>&1
phase=VERIFY
app "$DST" shell -c '
from renewal_attachments.models import RenewalAttachment
q=RenewalAttachment.objects.filter(display_name="synthetic.pdf",state="quarantined")
assert q.count()==1
r=q.get()
assert r.storage_key.hex=="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
assert r.sha256=="b"*64 and r.byte_size==8
' >>"$LOG" 2>&1
(cd "$ROOT" && sha256sum --check inventory.sha256) >>"$LOG" 2>&1
echo "MB1_E2E_PG17_SOURCE_TARGET=OK"
echo "MB1_E2E_REAL_PG_DUMP_RESTORE=OK"
echo "MB1_E2E_SYNTHETIC_OBJECT_JOURNAL_HASH=OK"
echo "MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=OK"
echo "MB1_E2E_WRONG_KEY_AND_TAMPER_REJECTED=OK"
echo "MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED"
echo "MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED"
