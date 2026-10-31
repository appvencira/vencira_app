#!/usr/bin/env bash
# MB1/M1-03 least-privilege SQL rehearsal. Isolated PG17, NO DEV/O5 contact.
# The app role has read/write rights on example tables but no DDL, admin or
# access to separate private tables. NOT an operational migration plan.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB=""
STARTED=0
cleanup() {
  rc=$?
  trap - EXIT
  if [ "$STARTED" = 1 ]; then
    docker rm -f "$DB" >/dev/null 2>&1 || rc=1
  fi
  echo "MB1_M103_LP_PHASE=$PHASE"
  echo "MB1_M103_LP_RESULT=$rc"
  echo "MB1_M103_LP_REAL_DJANGO_APP_COMPATIBILITY=NOT_VERIFIED"
  echo "MB1_M103_LP_DEV_ROLE_CHANGE=NOT_AUTHORIZED"
  echo "MB1_M103_LP_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT

[ "$(printenv MB1_M103_LP_DISPOSABLE || true)" = YES ] || {
  echo "MB1_M103_LP_EXPLICIT_OPT_IN=REQUIRED"; exit 2;
}
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
command -v docker >/dev/null
docker info >/dev/null
echo "MB1_M103_LP_SOURCE_PREFLIGHT=OK"

PHASE=ISOLATED_DB
DB="mb1_m103_lp_$$_$RANDOM"
docker run -d --name "$DB" --network none \
  -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
  -e POSTGRES_PASSWORD=synthetic-admin-pg17-only \
  postgres:17-alpine >/dev/null
STARTED=1
ready=0
for _ in $(seq 1 50); do
  if docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
[ "$ready" -eq 1 ]
echo "MB1_M103_LP_PG17_PRIVATE_NO_NETWORK=OK"

PHASE=FIXTURE
# All SQL below operates ONLY on a brand-new disposable database.
docker exec -i "$DB" psql -X -q -v ON_ERROR_STOP=1 -U mb1 -d mb1 >/dev/null <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE ROLE mb1_app_limited LOGIN PASSWORD 'synthetic-role-only';
GRANT CONNECT ON DATABASE mb1 TO mb1_app_limited;
CREATE SCHEMA mb1_fixture AUTHORIZATION mb1;
CREATE TABLE mb1_fixture.renewals (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference TEXT NOT NULL
);
CREATE TABLE mb1_fixture.audit_private (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    audit_value TEXT NOT NULL
);
GRANT USAGE ON SCHEMA mb1_fixture TO mb1_app_limited;
GRANT SELECT, INSERT, UPDATE, DELETE
    ON mb1_fixture.renewals TO mb1_app_limited;
GRANT USAGE, SELECT
    ON SEQUENCE mb1_fixture.renewals_id_seq TO mb1_app_limited;
SQL
echo "MB1_M103_LP_ADMIN_AND_APP_ROLES_SEPARATE=OK"

# Connect as the actual restricted login via TCP loopback, not using
# SET ROLE in a superuser session (which would test the wrong threat model).
app_sql() {
  docker exec -e PGPASSWORD=synthetic-role-only "$DB" \
    psql -X -A -t -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate \
    -h 127.0.0.1 -U mb1_app_limited -d mb1 -c "$1"
}
expect_privilege_denied() {
  label="$1"
  statement="$2"
  error=""
  if error="$(app_sql "$statement" 2>&1)"; then
    echo "MB1_M103_LP_UNEXPECTED_PRIVILEGE=$label"
    exit 1
  fi
  case "$error" in
    *42501*) echo "MB1_M103_LP_REJECTED_$label=OK" ;;
    *) echo "MB1_M103_LP_UNEXPECTED_ERROR_CLASS=$label"; exit 1 ;;
  esac
}

PHASE=POSITIVE_DML
[ "$(app_sql 'SELECT CASE WHEN current_user = '\''mb1_app_limited'\'' AND NOT (SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication FROM pg_roles WHERE rolname=current_user) THEN '\''OK'\'' ELSE '\''FAIL'\'' END;')" = OK ]
app_sql "INSERT INTO mb1_fixture.renewals(reference) VALUES ('synthetic');" >/dev/null
app_sql "UPDATE mb1_fixture.renewals SET reference='updated' WHERE reference='synthetic';" >/dev/null
[ "$(app_sql "SELECT count(*) FROM mb1_fixture.renewals WHERE reference='updated';")" = 1 ]
app_sql "DELETE FROM mb1_fixture.renewals WHERE reference='updated';" >/dev/null
[ "$(app_sql "SELECT count(*) FROM mb1_fixture.renewals;")" = 0 ]
echo "MB1_M103_LP_RESTRICTED_ROLE_CRUD=OK"

PHASE=NEGATIVE_PRIVILEGES
expect_privilege_denied "PRIVATE_AUDIT_READ" \
  "SELECT count(*) FROM mb1_fixture.audit_private;"
expect_privilege_denied "DDL_ALTER" \
  "ALTER TABLE mb1_fixture.renewals ADD COLUMN exposed TEXT;"
expect_privilege_denied "DDL_CREATE" \
  "CREATE TABLE mb1_fixture.outside_permission (id int);"
expect_privilege_denied "TABLE_TRUNCATE" \
  "TRUNCATE mb1_fixture.renewals;"
expect_privilege_denied "ROLE_CREATE" \
  "CREATE ROLE mb1_rogue;"
expect_privilege_denied "ADMIN_ROLE_IMPERSONATION" \
  "SET ROLE mb1;"
echo "MB1_M103_LP_ADMIN_ESCALATION_DENIED=OK"

PHASE=RECHECK
# The app login is still usable after all negative authorization probes.
[ "$(app_sql "SELECT count(*) FROM mb1_fixture.renewals;")" = 0 ]
echo "MB1_M103_LP_RESTRICTED_ROLE_REMAINS_USABLE=OK"
PHASE=DONE
echo "MB1_M103_LP_DISPOSABLE_ROLE_SEPARATION=OK"
