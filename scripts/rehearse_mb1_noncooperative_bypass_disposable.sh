#!/usr/bin/env bash
# MB1 M1-04 adversarial negative control. Success means BYPASS FOUND,
# not that a global freeze is safe. No interaction with VENCIRA containers.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
if [ "${MB1_NONCOOPERATIVE_LAB:-}" != YES ]; then
  echo "MB1_NONCOOPERATIVE_OPT_IN=REQUIRED"; exit 2
fi
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
lab_root="$(mktemp -d /tmp/mb1-bypass.XXXXXXXX)"
db="mb1_noncooperative_$$_$RANDOM"
db_started=0
cleanup() {
  rc=$?; trap - EXIT
  if [ "$db_started" = 1 ]; then docker rm -f "$db" >/dev/null 2>&1 || rc=1; fi
  rm -rf -- "$lab_root" || rc=1
  echo "MB1_NONCOOPERATIVE_BYPASS_RESULT=$rc"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
export MB1_BYPASS_LAB_ROOT="$lab_root"
export PYTHONPATH="$PWD/backend"
python3 - <<'PY'
import hashlib
import os
import subprocess
import sys
from pathlib import Path
from renewal_attachments.offline_multiprocess_fence_mb1 import IsolatedProcessFence
root=Path(os.environ["MB1_BYPASS_LAB_ROOT"])
lock=IsolatedProcessFence(root/"capture.lock")
target=root/"not_protected.bin"
target.write_bytes(b"initial")
before=hashlib.sha256(target.read_bytes()).hexdigest()
# The direct writer never acquires the advisory lock.
with lock.capture(timeout=2):
    subprocess.run([sys.executable,"-c",
                    "from pathlib import Path; import sys; "
                    "Path(sys.argv[1]).write_bytes(b'UNCOOPERATIVE_WRITE')",
                    str(target)],check=True,timeout=5)
    after=hashlib.sha256(target.read_bytes()).hexdigest()
    if before==after:
        raise RuntimeError("EXPECTED_FILESYSTEM_BYPASS_NOT_OBSERVED")
print("MB1_UNCOOPERATIVE_FS_WRITE_BYPASS=CONFIRMED")
PY
docker run -d --name "$db" --network none \
  -e POSTGRES_USER=mb1admin -e POSTGRES_DB=mb1adversarial \
  -e POSTGRES_PASSWORD=synthetic-only postgres:17-alpine >/dev/null
db_started=1
ready=0
for _ in $(seq 1 40); do
 if docker exec "$db" pg_isready -U mb1admin -d mb1adversarial >/dev/null 2>&1; then
    ready=1; break
 fi
 sleep 1
done
[ "$ready" = 1 ]
sql() { docker exec "$db" psql -X -A -t -v ON_ERROR_STOP=1 -U mb1admin -d mb1adversarial -c "$1"; }
sql "CREATE TABLE mb1_probe (value integer NOT NULL);" >/dev/null
sql "CREATE ROLE mb1ordinary LOGIN PASSWORD 'synthetic-only';" >/dev/null
sql "ALTER ROLE mb1ordinary NOLOGIN;" >/dev/null
if docker exec "$db" sh -ec 'PGPASSWORD=synthetic-only psql -h 127.0.0.1 -X -U mb1ordinary -d mb1adversarial -c "SELECT 1"' >/dev/null 2>&1; then
 echo "MB1_EXPECTED_ORDINARY_LOGIN_DENIAL=FAILED" >&2; exit 1
fi
echo "MB1_ORDINARY_LOGIN_DENIED=OK"
# A superuser can write while ordinary login is denied. This is deliberately
# proof that NOLOGIN does not provide writer exclusion.
sql "INSERT INTO mb1_probe VALUES (37);" >/dev/null
if [ "$(sql 'SELECT value FROM mb1_probe;')" != 37 ]; then
  echo "MB1_EXPECTED_SQL_BYPASS_NOT_OBSERVED=1" >&2; exit 1
fi
echo "MB1_NONCOOPERATIVE_SQL_ADMIN_WRITE_BYPASS=CONFIRMED"
echo "MB1_UNIVERSAL_FREEZE_FAIL_CLOSED=OK"
