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
phase=VOLUME_PERMISSIONS
# Docker creates named-volume roots as root. The Django image runs as a
# non-root user; initialize ONLY these newly created disposable volumes.
APP_UID="$(docker run --rm --network none "$IMG" id -u)"
APP_GID="$(docker run --rm --network none "$IMG" id -g)"
[[ "$APP_UID" =~ ^[0-9]+$ && "$APP_GID" =~ ^[0-9]+$ ]]
docker run --rm --network none --user 0:0 \
 --mount "type=volume,source=$VOL_OBJ,target=/lab/objects" \
 --mount "type=volume,source=$VOL_JOURNAL,target=/lab/journal" \
 -e LAB_UID="$APP_UID" -e LAB_GID="$APP_GID" \
 python:3.12-alpine sh -ec '
   chown "$LAB_UID:$LAB_GID" /lab/objects /lab/journal
   chmod 0700 /lab/objects /lab/journal
 ' >/dev/null
echo "MB1_INTEGRATED_PRIVATE_VOLUME_PERMISSIONS=OK"
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
for root in roots:
    assert root.is_dir() and root.stat().st_mode & 0o077 == 0
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
phase=CLASSIFIER_PG17
# Deliberately create three incomplete *synthetic* states in the disposable
# PG17 / object and journal volumes; classify by read-only enumeration.
app shell -c '
import hashlib, uuid
from pathlib import Path
from cryptography.fernet import Fernet
from renewal_attachments.offline_intake_journal import IntakeJournal
from renewal_attachments.offline_recovery_classifier_mb1 import classify_recovery_inventory
from renewal_attachments.models import RenewalAttachment
from reminders.attachment_private_store import PrivateQuarantineStore
root=Path("/lab/objects")
journal_root=Path("/lab/journal")
store=PrivateQuarantineStore(root,(root/".lab-key").read_bytes())
journal=IntakeJournal(str(journal_root))
base=RenewalAttachment.objects.get(display_name="synthetic.pdf")
intent_only=uuid.uuid4()
object_only=uuid.uuid4()
metadata_only=uuid.uuid4()
payload=b"MB1_INTEGRATED_ORPHAN_SYNTHETIC"
sha=hashlib.sha256(payload).hexdigest()
journal.record_intent(intent_only,sha)
store.put_quarantine(object_only,payload)
RenewalAttachment.objects.create(
    renewal=base.renewal,display_name="missing-object.pdf",
    content_type="application/pdf",byte_size=len(payload),
    sha256=sha,state="quarantined",storage_key=metadata_only)
# Exclude the private lab key, which is not a stored attachment object.
intents={uuid.UUID(hex=p.stem) for p in journal_root.iterdir() if p.suffix==".json"}
objects={uuid.UUID(hex=p.name) for p in root.iterdir() if len(p.name)==32 and all(c in "0123456789abcdef" for c in p.name)}
metadata=set(RenewalAttachment.objects.values_list("storage_key",flat=True))
report=classify_recovery_inventory(intents=intents,objects=objects,metadata=metadata)
assert report["complete"]==1, report
assert report["intent_only"]==1, report
assert report["object_only"]==1, report
assert report["metadata_only"]==1, report
assert report["requires_review"] is True
assert report["repair_authorized"] is False
assert report["deletion_authorized"] is False
assert report["release_authorized"] is False
print("MB1_INTEGRATED_PG17_ORPHAN_CLASSIFICATION=OK")
print("MB1_INTEGRATED_AUTOMATIC_REPAIR=DISABLED")
'
phase=SIGKILL_PG17
# Real process death while a PostgreSQL transaction remains uncommitted.
# The journal/object have been fsync'd by the actual production primitives.
# Run Python directly as Docker PID 1; avoid Django shell exit handling.
# Set up Django explicitly. SIGKILL of PID 1 must return Docker exit 137.
if docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
 -e VENCIRA_DB_ENGINE=postgresql \
 -e DJANGO_SETTINGS_MODULE=config.settings \
 -e DJANGO_SECRET_KEY=synthetic-only-mb1-integration-secret \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=synthetic-only \
 --mount "type=volume,source=$VOL_OBJ,target=/lab/objects" \
 --mount "type=volume,source=$VOL_JOURNAL,target=/lab/journal" \
 "$IMG" python -c '
import django
django.setup()
import hashlib, os, signal, uuid
from pathlib import Path
from django.db import transaction
from reminders.attachment_private_store import PrivateQuarantineStore
from renewal_attachments.offline_intake_journal import IntakeJournal
from renewal_attachments.models import RenewalAttachment
key=uuid.UUID(hex="b17b17b17b1741178117811781178117")
payload=b"MB1_SIGKILL_PG17_SYNTHETIC"
sha=hashlib.sha256(payload).hexdigest()
journal=IntakeJournal("/lab/journal")
store=PrivateQuarantineStore(Path("/lab/objects"),Path("/lab/objects/.lab-key").read_bytes())
journal.record_intent(key,sha)
store.put_quarantine(key,payload)
with transaction.atomic():
    base=RenewalAttachment.objects.get(display_name="synthetic.pdf")
    RenewalAttachment.objects.create(
        renewal=base.renewal,display_name="killed-transaction.pdf",
        content_type="application/pdf",byte_size=len(payload),
        sha256=sha,state="quarantined",storage_key=key)
    # Persisted on filesystem but NOT committed in PG17.
    os.kill(os.getpid(),signal.SIGKILL)
'; then
  echo "MB1_SIGKILL_UNEXPECTED_SUCCESS=1" >&2
  exit 1
else
  kill_rc=$?
  if [ "$kill_rc" -ne 137 ]; then
    echo "MB1_SIGKILL_UNEXPECTED_EXIT=$kill_rc" >&2
    exit 1
  fi
fi
phase=SIGKILL_RECOVER
app shell -c '
import hashlib, uuid
from pathlib import Path
from renewal_attachments.offline_recovery_classifier_mb1 import classify_recovery_inventory
from renewal_attachments.models import RenewalAttachment
from renewal_attachments.offline_intake_journal import IntakeJournal
from reminders.attachment_private_store import PrivateQuarantineStore
key=uuid.UUID(hex="b17b17b17b1741178117811781178117")
root=Path("/lab/objects")
journal_root=Path("/lab/journal")
store=PrivateQuarantineStore(root,(root/".lab-key").read_bytes())
payload=store.read_quarantine_for_scanner_only(key)
intent=IntakeJournal(str(journal_root)).read_intent(key)
assert payload==b"MB1_SIGKILL_PG17_SYNTHETIC"
assert intent["sha256"]==hashlib.sha256(payload).hexdigest()
assert not RenewalAttachment.objects.filter(storage_key=key).exists()
intents={uuid.UUID(hex=p.stem) for p in journal_root.iterdir() if p.suffix==".json"}
objects={uuid.UUID(hex=p.name) for p in root.iterdir() if len(p.name)==32 and all(ch in "0123456789abcdef" for ch in p.name)}
metadata=set(RenewalAttachment.objects.values_list("storage_key",flat=True))
report=classify_recovery_inventory(intents=intents,objects=objects,metadata=metadata)
assert report["intent_and_object_without_metadata"]==1,report
assert report["repair_authorized"] is False
assert report["deletion_authorized"] is False
assert report["release_authorized"] is False
print("MB1_SIGKILL_PG17_ROLLBACK=OK")
print("MB1_SIGKILL_ENCRYPTED_OBJECT_JOURNAL_PRESERVED=OK")
print("MB1_SIGKILL_READONLY_RECONCILIATION=OK")
'
echo "MB1_INTEGRATED_PG17_PRIVATESTORE_JOURNAL_PERSISTENCE=OK"
