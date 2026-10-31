#!/usr/bin/env bash
# MB1 M1-06: O5 PostgreSQL disaster-recovery probe on a SECOND, independent host.
# The operator provisions /etc/vencira-recovery OFF the VPS. Never use
# the source VPS, even to fetch credentials, while running this test.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB=""
STARTED=0
finish() {
  rc=$?
  trap - EXIT
  if [ "$STARTED" = 1 ]; then
    docker rm -f "$DB" >/dev/null 2>&1 || rc=1
  fi
  echo "MB1_DR_SECOND_HOST_PHASE=$PHASE"
  echo "MB1_DR_SECOND_HOST_RESULT=$rc"
  echo "MB1_DR_RECOVERY_INDEPENDENCE=REQUIRES_MANUAL_ATTESTATION"
  echo "MB1_DR_EXTERNAL_CUSTODY=REQUIRES_MANUAL_ATTESTATION"
  echo "MB1_DR_PACKAGE_SCOPE=PG17_ONLY"
  echo "MB1_DR_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "$(printenv MB1_SECOND_HOST_O5_RECOVERY || true)" = YES_INDEPENDENT_HOST ] || {
  echo "MB1_DR_INDEPENDENT_HOST_OPT_IN_REQUIRED=1"; exit 2;
}
[ "$(id -u)" -eq 0 ]
for cmd in docker restic rclone python3 git flock; do command -v "$cmd" >/dev/null; done
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
[ "$(git -c safe.directory="$HERE" branch --show-current)" = feature/c-ficha-independent-attachments ]
test -f scripts/o5_restore_schema_contract.py
# Refuse to operate on known DEV or preview origin containers.
for origin in vencira_localcheck-db-1 vencira_preview-db-1; do
  if docker inspect "$origin" >/dev/null 2>&1; then
    echo "MB1_DR_ORIGIN_CONTAINER_PRESENT=ABORT"; exit 2
  fi
done
if [ -d /home/vencira/vencira-localcheck ]; then
  echo "MB1_DR_ORIGIN_PATH_PRESENT=ABORT"; exit 2
fi
echo "MB1_DR_NO_KNOWN_SOURCE_SIGNATURE=OK"

PHASE=CUSTODY_PRECHECK
CFG_DIR=/etc/vencira-recovery
[ -d "$CFG_DIR" ] && [ ! -L "$CFG_DIR" ]
[ "$(stat -c '%u:%a' "$CFG_DIR")" = 0:700 ]
# Fixed non-secret repository locator. Do NOT source any credential script
# with root privilege: only read two root-owned secret files.
RESTIC_REPOSITORY=rclone:vencira_google:VENCIRA-Backups/PostgreSQL
RESTIC_PASSWORD_FILE=/etc/vencira-recovery/restic-password
RCLONE_CONFIG=/etc/vencira-recovery/rclone.conf
for f in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  [ -f "$f" ] && [ ! -L "$f" ] && [ -s "$f" ]
  [ "$(stat -c '%u:%a' "$f")" = 0:600 ]
done
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
echo "MB1_DR_OFFHOST_CREDENTIAL_FILES_PRESENT=OK"

PHASE=REPOSITORY
exec 8>/run/lock/vencira-mb1-second-host-o5.lock
flock -n 8
restic snapshots --quiet >/dev/null 2>&1
echo "MB1_DR_INDEPENDENT_RESTIC_ACCESS=OK"

PHASE=PG17
DB="mb1_second_o5_$$_$RANDOM"
docker run -d --name "$DB" --network none \
 -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
 -e POSTGRES_PASSWORD=synthetic-only-temporary \
 postgres:17-alpine >/dev/null
STARTED=1
ready=0
for attempt in $(seq 1 50); do
  if docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
[ "$ready" = 1 ]
echo "MB1_DR_INDEPENDENT_PG17_ISOLATED=OK"

PHASE=RESTORE
# Streaming bytes: no unencrypted host dump and no network on PG container.
restic dump --tag vencira-postgresql latest vencira-postgres.dump 2>/dev/null |
  docker exec -i "$DB" pg_restore \
    --exit-on-error --no-owner --no-privileges \
    -U mb1 -d mb1 >/dev/null 2>&1
echo "MB1_DR_INDEPENDENT_DRIVE_PG17_RESTORE=OK"

PHASE=SCHEMA
migrations="$(docker exec "$DB" psql -X -A -t -v ON_ERROR_STOP=1 \
  -U mb1 -d mb1 -c "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name;")"
tables="$(docker exec "$DB" psql -X -A -t -v ON_ERROR_STOP=1 \
  -U mb1 -d mb1 -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;")"
python3 "$HERE/scripts/o5_restore_schema_contract.py" \
  --migrations "$migrations" --tables "$tables" >/dev/null
echo "MB1_DR_INDEPENDENT_BASELINE_SCHEMA=OK"
echo "MB1_DR_INDEPENDENT_RECOVERY_DRILL=OK"
PHASE=DONE
