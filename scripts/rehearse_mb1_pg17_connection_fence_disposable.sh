#!/usr/bin/env bash
# MB1 M1-04: PostgreSQL connection fence rehearsal, isolated DB only.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
project="mb1_fence_$$_$RANDOM"
db="${project}_pg"
created=0
writer_pid=""
LAB_ROOT=""
cleanup() {
  rc=$?; trap - EXIT
  if [ "$created" = 1 ]; then docker rm -f "$db" >/dev/null 2>&1 || rc=1; fi
  if [ -n "$LAB_ROOT" ]; then rm -rf -- "$LAB_ROOT" || rc=1; fi
  if [ -n "$writer_pid" ]; then wait "$writer_pid" >/dev/null 2>&1 || true; fi
  echo "MB1_PG17_FENCE_RESULT=$rc"
  echo "MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED"
  echo "MB1_FILESYSTEM_WRITERS=NOT_BLOCKED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
docker run -d --name "$db" --network none \
 -e POSTGRES_USER=mb1admin -e POSTGRES_DB=mb1fence \
 -e POSTGRES_PASSWORD=synthetic-only \
 postgres:17-alpine >/dev/null
created=1
ready=0
for _ in $(seq 1 40); do
  if docker exec "$db" pg_isready -U mb1admin -d mb1fence >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ]
sql() {
  docker exec "$db" psql -X -A -t -v ON_ERROR_STOP=1 -U mb1admin -d mb1fence -c "$1"
}
sql "CREATE ROLE mb1writer LOGIN PASSWORD 'synthetic-only';" >/dev/null
sql "GRANT CONNECT ON DATABASE mb1fence TO mb1writer;" >/dev/null
# Hold an ordinary, non-superuser transaction open from a separate process.
# All SQL and container resources are exclusively disposable.
docker exec "$db" sh -ec '
  PGPASSWORD=synthetic-only exec psql -h 127.0.0.1 -X -q -v ON_ERROR_STOP=1 \
    -U mb1writer -d mb1fence -c "BEGIN; SELECT pg_sleep(18); COMMIT;"
' >/dev/null 2>&1 &
writer_pid=$!
active=0
for _ in $(seq 1 30); do
  count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer' AND state='active' AND query LIKE '%pg_sleep(18)%';")"
  if [ "$count" = 1 ]; then active=1; break; fi
  sleep 0.2
done
if [ "$active" != 1 ]; then echo "MB1_PG17_WRITER_SESSION_SETUP=FAILED" >&2; exit 1; fi
echo "MB1_PG17_EXISTING_WRITER_ACTIVE=OK"

sql "ALTER ROLE mb1writer NOLOGIN;" >/dev/null
if docker exec "$db" sh -ec 'PGPASSWORD=synthetic-only psql -h 127.0.0.1 -X -A -t -U mb1writer -d mb1fence -c "SELECT 1"' >/dev/null 2>&1; then
  echo "MB1_PG17_NEW_WRITER_DENIAL=FAILED" >&2; exit 1
fi
echo "MB1_PG17_NEW_WRITER_DENIAL=OK"
# A capture gate must fail while the pre-existing session is still active.
count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer' AND state IN ('active','idle in transaction');")"
if [ "$count" != 1 ]; then echo "MB1_PG17_PREEXISTING_SESSION_NOT_HELD=1" >&2; exit 1; fi
echo "MB1_PG17_CAPTURE_BLOCKED_WHILE_WRITER_ACTIVE=OK"

wait "$writer_pid"
writer_pid=""
count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer';")"
if [ "$count" != 0 ]; then echo "MB1_PG17_SESSION_DRAIN_FAILED=1" >&2; exit 1; fi
echo "MB1_PG17_EXISTING_WRITER_DRAIN=OK"
echo "MB1_PG17_CAPTURE_SQL_QUIESCENT_LAB=OK"
# Superuser remains able to write: this is not a global fence.
if [ "$(sql 'SELECT 1')" != 1 ]; then exit 1; fi
echo "MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK"

# Joint, cooperative lab capture: PG17 dump and real file-lock exclusion
# under one capture interval. This is NOT universal operational fencing.
LAB_ROOT="$(mktemp -d /tmp/mb1-fence-capture.XXXXXXXX)"
chmod 0700 "$LAB_ROOT"
mkdir -m 0700 "$LAB_ROOT/objects" "$LAB_ROOT/journal"
printf 'MB1_SYNTHETIC_CIPHERTEXT_ONLY' > "$LAB_ROOT/objects/object"
printf 'MB1_SYNTHETIC_JOURNAL_ONLY' > "$LAB_ROOT/journal/intent"
chmod 0600 "$LAB_ROOT/objects/object" "$LAB_ROOT/journal/intent"
sql "CREATE TABLE mb1_capture_probe (id integer PRIMARY KEY, value text NOT NULL);" >/dev/null
sql "INSERT INTO mb1_capture_probe VALUES (1,'MB1_SYNTHETIC');" >/dev/null
export MB1_FENCE_LAB_ROOT="$LAB_ROOT"
export PYTHONPATH="$PWD/backend"
export MB1_FENCE_LAB_DB="$db"
python3 - <<'PY'
import hashlib, os, subprocess, sys
from pathlib import Path
from renewal_attachments.offline_multiprocess_fence_mb1 import IsolatedProcessFence
root=Path(os.environ["MB1_FENCE_LAB_ROOT"])
lock=IsolatedProcessFence(root/"capture.lock")
writer_script=(
 "import sys; from renewal_attachments.offline_multiprocess_fence_mb1 import IsolatedProcessFence;"
 "f=IsolatedProcessFence(sys.argv[1]);"
 "ctx=f.writer(timeout=0.2); ctx.__enter__(); ctx.__exit__(None,None,None)"
)
with lock.capture(timeout=2):
    blocked=subprocess.run([sys.executable,"-c",writer_script,str(root/"capture.lock")],
                            capture_output=True,timeout=5)
    if blocked.returncode==0:
        raise RuntimeError("FILE_WRITER_WAS_NOT_BLOCKED")
    print("MB1_JOINT_FILE_WRITER_DENIED=OK",flush=True)
    # Database writers' ordinary login was already disabled and drained.
    dump=root/"snapshot.pg"
    with dump.open("wb") as out:
        subprocess.run(["docker","exec",os.environ["MB1_FENCE_LAB_DB"],
                        "pg_dump","-Fc","-U","mb1admin","-d","mb1fence"],
                        stdout=out,check=True,timeout=30)
    digest=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    manifest={p.name:digest(p) for p in (root/"objects/object",root/"journal/intent")}
    assert manifest["object"] and manifest["intent"]
    subprocess.run(["docker","exec",os.environ["MB1_FENCE_LAB_DB"],
                    "createdb","-U","mb1admin","mb1restore"],check=True,timeout=15)
    with dump.open("rb") as inp:
        subprocess.run(["docker","exec","-i",os.environ["MB1_FENCE_LAB_DB"],
                        "pg_restore","-U","mb1admin","-d","mb1restore","--no-owner"],
                        stdin=inp,check=True,timeout=30)
    result=subprocess.run(["docker","exec",os.environ["MB1_FENCE_LAB_DB"],
                           "psql","-X","-A","-t","-U","mb1admin","-d","mb1restore",
                           "-c","SELECT value FROM mb1_capture_probe WHERE id=1"],
                           capture_output=True,text=True,check=True,timeout=15)
    assert result.stdout.strip()=="MB1_SYNTHETIC"
    assert manifest=={p.name:digest(p) for p in (root/"objects/object",root/"journal/intent")}
    print("MB1_JOINT_PG17_DUMP_RESTORE=OK",flush=True)
    print("MB1_JOINT_FILES_HASH_STABLE=OK",flush=True)
assert subprocess.run([sys.executable,"-c",writer_script,str(root/"capture.lock")],
                      capture_output=True,timeout=5).returncode==0
print("MB1_JOINT_COOPERATIVE_FENCE_RELEASE=OK")
PY
# Second gate: actual VENCIRA encrypted store and intake journal on private,
# disposable host directories. Retain the same cooperative capture contract.
# This is intentionally a separate drill, not a universal writer freeze.
lab_image="vencira-mb1-actual-store:$(git rev-parse --short=12 HEAD)"
docker build -q -t "$lab_image" ./backend >/dev/null
uid="$(docker run --rm --network none "$lab_image" id -u)"
gid="$(docker run --rm --network none "$lab_image" id -g)"
chown "$uid:$gid" "$LAB_ROOT/objects" "$LAB_ROOT/journal"
export MB1_FENCE_LAB_IMAGE="$lab_image"
python3 - <<'PY'
import os, subprocess, sys
from pathlib import Path
from renewal_attachments.offline_multiprocess_fence_mb1 import IsolatedProcessFence
root=Path(os.environ["MB1_FENCE_LAB_ROOT"])
script="""
import hashlib,os,uuid
from pathlib import Path
from cryptography.fernet import Fernet
from django.conf import settings
from reminders.attachment_private_store import PrivateQuarantineStore
from renewal_attachments.offline_intake_journal import IntakeJournal
key=uuid.UUID(hex="b17b17b17b1741178117811781178117")
objects=Path("/lab/objects")
journal=Path("/lab/journal")
keyfile=objects/".synthetic-key"
if not keyfile.exists():
    keyfile.write_bytes(Fernet.generate_key())
    keyfile.chmod(0o600)
store=PrivateQuarantineStore(objects,keyfile.read_bytes())
ledger=IntakeJournal(str(journal))
payload=b"MB1_REAL_ENCRYPTED_CAPTURE_SYNTHETIC"
if os.environ["MB1_ACTION"]=="write":
    ledger.record_intent(key,hashlib.sha256(payload).hexdigest())
    store.put_quarantine(key,payload)
else:
    assert store.read_quarantine_for_scanner_only(key)==payload
    assert ledger.read_intent(key)["sha256"]==hashlib.sha256(payload).hexdigest()
print("MB1_REAL_ENCRYPTED_STORE_JOURNAL="+os.environ["MB1_ACTION"].upper())
"""
def app(action):
    subprocess.run([
        "docker","run","--rm","--network","none",
        "-e","VENCIRA_ENV=test","-e","VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1",
        "-e","DJANGO_SETTINGS_MODULE=config.settings",
        # Django requires a configured database even though this offline stage
        # never opens SQL. The sandbox has --network none; loopback has no DB.
        "-e","POSTGRES_DB=mb1_disconnected",
        "-e","POSTGRES_USER=mb1_synthetic",
        "-e","POSTGRES_PASSWORD=mb1-synthetic-not-secret",
        "-e","POSTGRES_HOST=127.0.0.1",
        "-e","DJANGO_SECRET_KEY=mb1-synthetic-private-capture-secret-long",
        "-e","MB1_ACTION="+action,
        "--mount","type=bind,src="+str(root/"objects")+",dst=/lab/objects",
        "--mount","type=bind,src="+str(root/"journal")+",dst=/lab/journal",
        os.environ["MB1_FENCE_LAB_IMAGE"],"python","-c",
        "import django;django.setup();"+script
    ],check=True,timeout=45)
app("write")
fence=IsolatedProcessFence(root/"capture.lock")
with fence.capture(timeout=2):
    app("read")
    print("MB1_ACTUAL_ENCRYPTED_OBJECT_JOURNAL_CAPTURE=OK",flush=True)
PY
echo "MB1_JOINT_CAPTURE_LAB=OK"
echo "MB1_UNIVERSAL_CAPTURE=NOT_VERIFIED"
