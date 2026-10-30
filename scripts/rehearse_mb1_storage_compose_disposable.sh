#!/usr/bin/env bash
# Disposable Docker Compose named-volume survival test: NO DEV API, DB, or mounts.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
COMPOSE="$PWD/deploy/mb1/compose.storage-lab.yaml"
PROJECT="mb1_lab_$$_$RANDOM"
case "$PROJECT" in mb1_lab_*) ;; *) exit 2;; esac
command -v docker >/dev/null
docker compose version >/dev/null
phase=PRECHECK
# Never operate against VENCIRA's persistent compose projects.
case "$PROJECT" in vencira_*|vencira-*|vencira|vencira_localcheck|vencira_preview) exit 2;; esac
dc() { docker compose -p "$PROJECT" -f "$COMPOSE" "$@"; }
cleanup() {
  rc=$?
  trap - EXIT
  if ! dc down --volumes --remove-orphans >/dev/null 2>&1; then
    echo "MB1_STORAGE_LAB_CLEANUP=FAILED"
    rc=1
  fi
  echo "MB1_STORAGE_LAB_RESULT=$rc"
  echo "MB1_STORAGE_OPERATIONAL_RELEASE=NO"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
phase=CREATE
dc up -d --quiet-pull >/dev/null
# Opaque synthetic bytes only; these are NOT actual encrypted production objects.
phase=WRITE
dc exec -T storage_probe python - <<'PY'
from pathlib import Path
import hashlib, json, os
obj=Path("/lab/objects")
journal=Path("/lab/journal")
for folder in (obj,journal):
    folder.chmod(0o700)
key="a"*32
data=b"MB1_SYNTHETIC_CIPHERTEXT_ONLY"
(obj/key).write_bytes(data)
(journal/(key+".json")).write_text(json.dumps({
    "version":1,"storage_key":key,"state":"pending",
    "sha256":hashlib.sha256(data).hexdigest()
},sort_keys=True))
for p in (obj/key,journal/(key+".json")):
    p.chmod(0o600)
    with p.open("rb") as fh: os.fsync(fh.fileno())
for folder in (obj,journal):
    fd=os.open(folder,os.O_RDONLY|os.O_DIRECTORY)
    os.fsync(fd)
    os.close(fd)
PY
echo "MB1_STORAGE_LAB_INITIAL_WRITE=OK"
phase=RECREATE
# A container recreation must not destroy named-volume contents.
dc up -d --force-recreate --no-deps storage_probe >/dev/null
phase=VERIFY
dc exec -T storage_probe python - <<'PY'
from pathlib import Path
import hashlib,json,stat
key="a"*32
obj=Path("/lab/objects")
journal=Path("/lab/journal")
assert stat.S_IMODE(obj.stat().st_mode)==0o700
assert stat.S_IMODE(journal.stat().st_mode)==0o700
data=(obj/key).read_bytes()
entry=json.loads((journal/(key+".json")).read_text())
assert data==b"MB1_SYNTHETIC_CIPHERTEXT_ONLY"
assert entry=={"version":1,"storage_key":key,"state":"pending","sha256":hashlib.sha256(data).hexdigest()}
assert stat.S_IMODE((obj/key).stat().st_mode)==0o600
assert stat.S_IMODE((journal/(key+".json")).stat().st_mode)==0o600
PY
echo "MB1_STORAGE_LAB_CONTAINER_RECREATE_PERSISTENCE=OK"
echo "MB1_STORAGE_LAB_OBJECT_JOURNAL_HASH=OK"
