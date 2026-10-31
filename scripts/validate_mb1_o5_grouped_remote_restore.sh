#!/usr/bin/env bash
# MB1 O5 grouped verification: candidate schema contract + RESTORE INTO DISPOSABLE PG17.
# Reads an existing encrypted Restic snapshot from Drive; no upload, backup
# regeneration, service restart, migration or writes to the DEV PostgreSQL.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
REPO=/home/vencira/vencira-localcheck
finish() {
  rc=$?
  trap - EXIT
  echo "MB1_O5_GROUP_PHASE=$PHASE"
  echo "MB1_O5_GROUP_RESULT=$rc"
  echo "MB1_O5_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED"
  echo "MB1_O5_OBJECT_JOURNAL_BACKUP=NOT_INTEGRATED"
  echo "MB1_O5_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
if [ "${MB1_GROUPED_O5_RESTORE:-}" != YES ]; then
  echo "MB1_O5_GROUP_EXPLICIT_OPT_IN=REQUIRED"
  exit 2
fi
[ "$(id -u)" -eq 0 ]
cd "$REPO"
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
for command_name in docker python3 bash git; do command -v "$command_name" >/dev/null; done
test -f scripts/o5_restore_schema_contract.py
test -f scripts/test_o5_restore_schema_contract.py
test -f scripts/o5_restore_drill.sh
for syntax_file in scripts/o5_restore_drill.sh scripts/audit_mb1_o5_restore_contract_readonly.sh; do
  bash -n "$syntax_file"
done
echo "MB1_O5_GROUP_BASH_SYNTAX=OK"

PHASE=TESTS
# No production data or Docker used for these pure Python tests.
python3 -m unittest -q scripts.test_o5_restore_schema_contract
echo "MB1_O5_GROUP_SCHEMA_TESTS=OK"

PHASE=STATIC_BOUNDARY
# Assert this candidate restores ONLY into its private temporary container.
# Do not run any unknown or modified script as part of this grouped gate.
python3 - <<'PY'
from pathlib import Path
s=Path("scripts/o5_restore_drill.sh").read_text()
required=(
    'RESTORE_NAME="vencira_o5_pg_restore_$$"',
    'docker run -d --rm --name "$RESTORE_NAME" --network none',
    'restic dump --tag vencira-postgresql latest vencira-postgres.dump',
    'docker exec -i "$RESTORE_NAME" pg_restore',
    'python3 /home/vencira/vencira-localcheck/scripts/o5_restore_schema_contract.py',
    'test "$BEFORE_DB_ID" = "$(docker inspect "$DB" --format',
)
if any(x not in s for x in required):
    raise SystemExit("MB1_O5_GROUP_RESTORE_CONTRACT_DRIFT")
if ('test "$schema" = 0014_renewal_outcomes' in s or
        'docker compose' in s or
        'docker restart' in s or
        'docker stop "$DB"' in s or
        'docker exec -i "$DB" pg_restore' in s):
    raise SystemExit("MB1_O5_GROUP_UNSAFE_RESTORE_PATTERN")
print("MB1_O5_GROUP_STATIC_BOUNDARY=OK")
PY

PHASE=LIVE_PRECHECK
DB=vencira_localcheck-db-1
[ "$(docker inspect "$DB" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck ]
before="$(docker inspect "$DB" --format '{{.Id}}')"
[ "$(docker inspect "$DB" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy ]
echo "MB1_O5_GROUP_DEV_DB_PRECHECK=OK"

PHASE=REMOTE_RESTORE
# Existing O5 script holds its shared service lock and uses --network none.
# It only reads a remote encrypted snapshot and restores into PG17 ephemeral.
# If the backup timer owns the lock the test fails closed; do not stop timers.
bash scripts/o5_restore_drill.sh
echo "MB1_O5_GROUP_REMOTE_PG17_RESTORE=OK"

PHASE=POSTCHECK
[ "$before" = "$(docker inspect "$DB" --format '{{.Id}}')" ]
[ "$(docker inspect "$DB" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}')" = healthy ]
echo "MB1_O5_GROUP_DEV_CONTAINER_ID_AND_HEALTH_UNCHANGED=OK"
echo "MB1_O5_GROUP_DONE=OK"
