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
export MB1_FENCE_LAB_UID="$uid"
export MB1_FENCE_LAB_GID="$gid"
python3 - <<'PY'
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

from renewal_attachments.offline_multiprocess_fence_mb1 import IsolatedProcessFence

root = Path(os.environ["MB1_FENCE_LAB_ROOT"])
db = os.environ["MB1_FENCE_LAB_DB"]
image = os.environ["MB1_FENCE_LAB_IMAGE"]
uid, gid = int(os.environ["MB1_FENCE_LAB_UID"]), int(os.environ["MB1_FENCE_LAB_GID"])
key_hex = "b17b17b17b1741178117811781178117"
payload = b"MB1_REAL_ENCRYPTED_CAPTURE_SYNTHETIC"
expected_sha = hashlib.sha256(payload).hexdigest()
fence = IsolatedProcessFence(root / "capture.lock")

app_source = """
import hashlib, os, uuid
from pathlib import Path
from cryptography.fernet import Fernet
from reminders.attachment_private_store import PrivateQuarantineStore
from renewal_attachments.offline_intake_journal import IntakeJournal
key = uuid.UUID(hex=os.environ["MB1_STORAGE_KEY"])
objects = Path("/lab/objects")
journal = Path("/lab/journal")
keyfile = objects / ".synthetic-key"
if os.environ["MB1_ACTION"] == "write":
    if keyfile.exists():
        raise RuntimeError("SYNTHETIC_KEY_ALREADY_EXISTS")
    keyfile.write_bytes(Fernet.generate_key())
    keyfile.chmod(0o600)
store = PrivateQuarantineStore(objects, keyfile.read_bytes())
ledger = IntakeJournal(str(journal))
payload = b"MB1_REAL_ENCRYPTED_CAPTURE_SYNTHETIC"
digest = hashlib.sha256(payload).hexdigest()
if os.environ["MB1_ACTION"] == "write":
    ledger.record_intent(key, digest)
    store.put_quarantine(key, payload)
else:
    if store.read_quarantine_for_scanner_only(key) != payload:
        raise RuntimeError("DECRYPTED_CONTENT_MISMATCH")
    if ledger.read_intent(key)["sha256"] != digest:
        raise RuntimeError("INTAKE_JOURNAL_MISMATCH")
print("MB1_REAL_ENCRYPTED_STORE_JOURNAL=" + os.environ["MB1_ACTION"].upper())
"""

def app(action, objects=None, journal=None):
    objects = objects or root / "objects"
    journal = journal or root / "journal"
    subprocess.run([
        "docker", "run", "--rm", "--network", "none",
        "-e", "VENCIRA_ENV=test",
        "-e", "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1",
        "-e", "DJANGO_SETTINGS_MODULE=config.settings",
        "-e", "DJANGO_SECRET_KEY=mb1-synthetic-private-capture-secret-long",
        "-e", "POSTGRES_DB=mb1_disconnected",
        "-e", "POSTGRES_USER=mb1_synthetic",
        "-e", "POSTGRES_PASSWORD=mb1-synthetic-not-secret",
        "-e", "POSTGRES_HOST=127.0.0.1",
        "-e", "MB1_STORAGE_KEY=" + key_hex,
        "-e", "MB1_ACTION=" + action,
        "--mount", "type=bind,src=" + str(objects) + ",dst=/lab/objects",
        "--mount", "type=bind,src=" + str(journal) + ",dst=/lab/journal",
        image, "python", "-c", "import django;django.setup();" + app_source
    ], check=True, timeout=45)

def sql(database, statement):
    result = subprocess.run([
        "docker", "exec", db, "psql", "-X", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-U", "mb1admin", "-d", database,
        "-c", statement
    ], check=True, capture_output=True, text=True, timeout=20)
    return result.stdout.strip()

# A cooperative writer owns the same on-host inode while writing the
# real VENCIRA encrypted store and journal. Database metadata is synthetic.
with fence.writer(timeout=2):
    app("write")
    sql("mb1fence", "CREATE TABLE mb1_real_attachment "
        "(storage_key text PRIMARY KEY, sha256 text NOT NULL)")
    sql("mb1fence", "INSERT INTO mb1_real_attachment VALUES "
        "('" + key_hex + "','" + expected_sha + "')")
print("MB1_REAL_ENCRYPTED_WRITER_COOPERATIVE=OK")

writer_script = (
    "import sys; from renewal_attachments.offline_multiprocess_fence_mb1 "
    "import IsolatedProcessFence; "
    "f=IsolatedProcessFence(sys.argv[1]); "
    "ctx=f.writer(timeout=0.2); ctx.__enter__(); ctx.__exit__(None,None,None)"
)
snapshot = root / "consistent-snapshot"
snapshot.mkdir(mode=0o700)

def checksum_tree(path):
    return {
        str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(path.rglob("*"))
        if p.is_file()
    }

with fence.capture(timeout=3):
    blocked = subprocess.run(
        [sys.executable, "-c", writer_script, str(root / "capture.lock")],
        capture_output=True, timeout=5
    )
    if blocked.returncode == 0:
        raise RuntimeError("COOPERATIVE_WRITER_BYPASSED_CAPTURE")
    if sql("mb1fence", "SELECT count(*) FROM pg_stat_activity "
           "WHERE usename='mb1writer'") != "0":
        raise RuntimeError("SQL_WRITER_NOT_DRAINED")
    print("MB1_REAL_JOINT_WRITERS_BLOCKED=OK", flush=True)
    with (snapshot / "database.dump").open("wb") as output:
        subprocess.run(
            ["docker", "exec", db, "pg_dump", "-Fc",
             "-U", "mb1admin", "-d", "mb1fence"],
            stdout=output, check=True, timeout=30
        )
    shutil.copytree(root / "objects", snapshot / "objects")
    shutil.copytree(root / "journal", snapshot / "journal")
    copied = checksum_tree(snapshot / "objects")
    copied.update({"journal/" + k: v for k, v in
                   checksum_tree(snapshot / "journal").items()})
    if key_hex not in copied or ("journal/" + key_hex + ".json") not in copied:
        raise RuntimeError("CAPTURE_MISSING_ATTACHMENT_OR_JOURNAL")
    if not (snapshot / "database.dump").stat().st_size:
        raise RuntimeError("EMPTY_DATABASE_DUMP")
    print("MB1_REAL_JOINT_SINGLE_CAPTURE_WINDOW=OK", flush=True)

# Release the barrier before verifying the independent restoration.
if subprocess.run(
    [sys.executable, "-c", writer_script, str(root / "capture.lock")],
    capture_output=True, timeout=5
).returncode != 0:
    raise RuntimeError("COOPERATIVE_WRITER_NOT_RELEASED")

# Snapshot material is synthetic; in production encryption keys need
# separate off-site custody and must NOT be bundled with objects.
for folder in (snapshot / "objects", snapshot / "journal"):
    for path in [folder, *folder.rglob("*")]:
        os.chown(path, uid, gid)

subprocess.run(
    ["docker", "exec", db, "createdb", "-U", "mb1admin", "mb1realrestore"],
    check=True, timeout=20
)
with (snapshot / "database.dump").open("rb") as input_stream:
    subprocess.run(
        ["docker", "exec", "-i", db, "pg_restore",
         "-U", "mb1admin", "-d", "mb1realrestore", "--no-owner"],
        stdin=input_stream, check=True, timeout=30
    )
row = sql("mb1realrestore",
          "SELECT storage_key || '|' || sha256 "
          "FROM mb1_real_attachment")
if row != key_hex + "|" + expected_sha:
    raise RuntimeError("RESTORED_METADATA_MISMATCH")
app("read", snapshot / "objects", snapshot / "journal")
if copied != {
    **checksum_tree(snapshot / "objects"),
    **{"journal/" + k: v for k, v in
       checksum_tree(snapshot / "journal").items()}
}:
    raise RuntimeError("SNAPSHOT_FILES_CHANGED")
print("MB1_REAL_JOINT_PG17_OBJECT_JOURNAL_RESTORED=OK")
print("MB1_REAL_JOINT_HASH_AND_DECRYPT_VERIFIED=OK")
PY
echo "MB1_JOINT_CAPTURE_LAB=OK"
echo "MB1_UNIVERSAL_CAPTURE=NOT_VERIFIED"
