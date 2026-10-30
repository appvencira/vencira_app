#!/usr/bin/env bash
# MB1 disposable PG17 + actual Django encrypted store/journal + persistent Docker volumes.
# No app services, no DEV database or existing named volumes.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
PROJECT="mb1_integrated_$$_$RANDOM"
DB="mb1_integrated_db_$$_$RANDOM"
NET="mb1_integrated_net_$$_$RANDOM"
VOL_OBJ="${PROJECT}_objects"
VOL_JOURNAL="${PROJECT}_journal"
IMG="vencira-mb1-integration:$(git rev-parse --short=12 HEAD)"
phase=PRECHECK
command -v docker >/dev/null
docker info >/dev/null
[ -f backend/Dockerfile ]
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
# Name cannot match production compose prefixes.
case "$PROJECT" in mb1_integrated_*) ;; *) exit 2;; esac
created_db=0; created_net=0; created_obj=0; created_journal=0
cleanup() {
  rc=$?; trap - EXIT
  if [ "$created_db" = 1 ]; then docker rm -f "$DB" >/dev/null 2>&1 || rc=1; fi
  if [ "$created_net" = 1 ]; then docker network rm "$NET" >/dev/null 2>&1 || rc=1; fi
  if [ "$created_obj" = 1 ]; then docker volume rm "$VOL_OBJ" >/dev/null 2>&1 || rc=1; fi
  if [ "$created_journal" = 1 ]; then docker volume rm "$VOL_JOURNAL" >/dev/null 2>&1 || rc=1; fi
  echo "MB1_INTEGRATED_PHASE=$phase"
  echo "MB1_INTEGRATED_RESULT=$rc"
  echo "MB1_OPERATIONAL_RELEASE=NO"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
phase=BUILD
docker build -q -t "$IMG" ./backend >/dev/null
phase=CREATE
docker volume create "$VOL_OBJ" >/dev/null; created_obj=1
docker volume create "$VOL_JOURNAL" >/dev/null; created_journal=1
docker network create --internal "$NET" >/dev/null; created_net=1
docker run -d --name "$DB" --network "$NET" \
 -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
 -e POSTGRES_PASSWORD=synthetic-only \
 postgres:17-alpine >/dev/null
created_db=1
ready=0
for _ in $(seq 1 40); do
 if docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
 sleep 1
done
[ "$ready" = 1 ]
app() {
 docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
 -e VENCIRA_DB_ENGINE=postgresql \
 -e DJANGO_SECRET_KEY=synthetic-only-mb1-integration-secret \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=synthetic-only \
 --mount "type=volume,source=$VOL_OBJ,target=/lab/objects" \
 --mount "type=volume,source=$VOL_JOURNAL,target=/lab/journal" \
 "$IMG" python manage.py "$@"
}
phase=SCHEMA
app migrate reminders 0018_draft_reasons --noinput >/dev/null
app migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
phase=WRITE
app shell -c '
import hashlib, os
from pathlib import Path
from datetime import date
from cryptography.fernet import Fernet
from reminders.models import Workspace, Renewal
from reminders.attachment_private_store import PrivateQuarantineStore
from renewal_attachments.models import RenewalAttachment
from renewal_attachments.offline_intake_journal import IntakeJournal
roots=(Path("/lab/objects"),Path("/lab/journal"))
for root in roots: root.chmod(0o700)
payload=b"MB1_REAL_FERNET_SYNTHETIC"
key=Fernet.generate_key()
# Test-only fixed key file stored INSIDE disposable object volume, not host.
# Avoid leaving any operational secrets; volume is deleted in trap.
Path("/lab/objects/.lab-key").write_bytes(key)
Path("/lab/objects/.lab-key").chmod(0o600)
w=Workspace.objects.create(name="MB1_INTEGRATED_SYNTHETIC")
r=Renewal.objects.create(workspace=w,customer_reference="MB1-INTEGRATED",full_name="Synthetic",expires_on=date(2027,12,1))
item=RenewalAttachment.objects.create(renewal=r,display_name="synthetic.pdf",content_type="application/pdf",byte_size=len(payload),sha256=hashlib.sha256(payload).hexdigest(),state="quarantined")
journal=IntakeJournal("/lab/journal")
journal.record_intent(item.storage_key, item.sha256)
store=PrivateQuarantineStore(Path("/lab/objects"),key)
store.put_quarantine(item.storage_key,payload)
assert store.read_quarantine_for_scanner_only(item.storage_key)==payload
assert journal.read_intent(item.storage_key)["sha256"]==item.sha256
print("MB1_INTEGRATED_REAL_STORE_JOURNAL_PG17=OK")
'
phase=RECREATE
# Recreate the *application* container by launching a new one against the
# same named volumes and same ephemeral PG17 DB; the first exited already.
app shell -c '
import hashlib
from pathlib import Path
from reminders.attachment_private_store import PrivateQuarantineStore
from renewal_attachments.offline_intake_journal import IntakeJournal
from renewal_attachments.models import RenewalAttachment
item=RenewalAttachment.objects.get(display_name="synthetic.pdf")
key=Path("/lab/objects/.lab-key").read_bytes()
store=PrivateQuarantineStore(Path("/lab/objects"),key)
payload=store.read_quarantine_for_scanner_only(item.storage_key)
journal=IntakeJournal("/lab/journal").read_intent(item.storage_key)
assert payload==b"MB1_REAL_FERNET_SYNTHETIC"
assert hashlib.sha256(payload).hexdigest()==item.sha256==journal["sha256"]
assert journal["storage_key"]==item.storage_key.hex
print("MB1_INTEGRATED_RECREATED_APP_CONSISTENT=OK")
'
echo "MB1_INTEGRATED_PG17_PRIVATESTORE_JOURNAL_PERSISTENCE=OK"
