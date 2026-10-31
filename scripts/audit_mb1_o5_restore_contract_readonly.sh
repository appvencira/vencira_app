#!/usr/bin/env bash
# MB1 O5 boundary audit - READ ONLY. No credential files opened.
# Performs one SELECT in existing DEV database; never writes or restarts.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
if [ "${MB1_O5_READONLY_AUDIT:-}" != YES ]; then
  echo "MB1_O5_READONLY_OPT_IN=REQUIRED"; exit 2
fi
test "$(id -u)" -eq 0
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -f scripts/o5_restore_drill.sh
test -f scripts/o5_backup_to_drive.sh
# Ensure the operator is accessing precisely the expected DEV container.
db=vencira_localcheck-db-1
project="$(docker inspect "$db" --format '{{index .Config.Labels "com.docker.compose.project"}}')"
[ "$project" = vencira_localcheck ]
current="$(docker exec -i "$db" sh -s <<'MB1SQL'
 PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -A -t -v ON_ERROR_STOP=1 \
 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
 -c "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
MB1SQL
)"
test -n "$current"
case "$current" in *[!a-zA-Z0-9_]*)
 echo "MB1_O5_MIGRATION_QUERY=UNEXPECTED_RESULT"; exit 1;; esac
echo "MB1_O5_LIVE_SCHEMA_QUERY=OK"
export MB1_O5_ACTUAL_SCHEMA="$current"
python3 - <<'PY'
import os,re
from pathlib import Path
restore=Path("scripts/o5_restore_drill.sh").read_text()
backup=Path("scripts/o5_backup_to_drive.sh").read_text()
match=re.search(r'test "\$schema" = ([A-Za-z0-9_]+)',restore)
if match is None:
    raise SystemExit("MB1_O5_RESTORE_PIN_PARSE=FAILED")
print("MB1_O5_RESTORE_STATIC_PIN=FOUND")
print("MB1_O5_RESTORE_PIN_MATCHES_LIVE=" +
      ("YES" if match.group(1)==os.environ["MB1_O5_ACTUAL_SCHEMA"] else "NO"))
if ('pg_dump -Fc' not in backup or
        '--stdin-filename vencira-postgres.dump' not in backup):
    raise SystemExit("MB1_O5_BACKUP_SCOPE_PARSE=FAILED")
print("MB1_O5_BACKUP_SCOPE=POSTGRESQL_ONLY_IN_VERSIONED_SOURCE")
print("MB1_O5_OBJECT_JOURNAL_CAPTURE=NOT_IN_VERSIONED_O5")
print("MB1_O5_ANTIROLLBACK_PREFLIGHT=NOT_IN_VERSIONED_O5")
PY
state=/var/lib/vencira-o5/last-success.epoch
if [ -f "$state" ] && [ ! -L "$state" ]; then
 age="$(python3 - "$state" <<'PY'
import sys,time
from pathlib import Path
v=Path(sys.argv[1]).read_text().strip()
if not v.isdecimal():
    raise SystemExit("MB1_O5_BACKUP_TIMESTAMP_INVALID")
print(int(time.time())-int(v))
PY
)"
 if [ "$age" -ge 0 ] && [ "$age" -le 129600 ]; then
  echo "MB1_O5_SUCCESS_MARKER=RECENT"
 else
  echo "MB1_O5_SUCCESS_MARKER=STALE_OR_FUTURE"
 fi
else
 echo "MB1_O5_SUCCESS_MARKER=MISSING_OR_UNREADABLE"
fi
echo "MB1_O5_REMOTE_RESTORABILITY=NOT_VERIFIED_BY_THIS_AUDIT"
echo "MB1_O5_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED"
echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "MB1_O5_READONLY_AUDIT_RESULT=0"
