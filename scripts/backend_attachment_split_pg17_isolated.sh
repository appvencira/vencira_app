#!/usr/bin/env bash
# PG17 disposable migration rehearsal for the already-separated attachments app.
# No live Compose services, database volumes, host ports, or customer records.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then sudo -v; DOCKER=(sudo docker); fi
for c in docker openssl git; do command -v "$c" >/dev/null || exit 2; done

API=vencira_localcheck-api-1
DB=vencira_localcheck-db-1
WEB=vencira_localcheck-web_preview-1
declare -A BEFORE
for srv in "$API" "$DB" "$WEB"; do
  test "$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$srv")" = vencira_localcheck || exit 3
  test "$("${DOCKER[@]}" inspect -f '{{.State.Health.Status}}' "$srv")" = healthy || exit 3
  BEFORE[$srv]="$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$srv")"
done
SHA="$(git rev-parse HEAD)"
IMAGE="vencira-attachment-pg17-lab:${SHA:0:12}"
NETWORK="vencira-att-pg17-$$"
POSTGRES="vencira-att-pg17-db-$$"
PASS="$(openssl rand -hex 28)"
SECRET="lab-only-$(openssl rand -hex 36)"
cleanup() {
  "${DOCKER[@]}" rm -f "$POSTGRES" >/dev/null 2>&1 || true
  "${DOCKER[@]}" network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT
echo "ATTACHMENT_PG17_LAB=DISPOSABLE_NO_LIVE_DATA"
"${DOCKER[@]}" build --pull=false -f backend/Dockerfile -t "$IMAGE" backend >/dev/null
echo "ATTACHMENT_PG17_IMAGE_BUILD=OK"
"${DOCKER[@]}" network create --internal "$NETWORK" >/dev/null
"${DOCKER[@]}" run -d --rm --name "$POSTGRES" --network "$NETWORK" \
  -e POSTGRES_DB=attlab -e POSTGRES_USER=attlab -e POSTGRES_PASSWORD="$PASS" \
  --tmpfs /var/lib/postgresql/data:rw,size=256m \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if "${DOCKER[@]}" exec "$POSTGRES" pg_isready -U attlab -d attlab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" = YES || { echo "ATTACHMENT_PG17_READY=FAIL"; exit 4; }
echo "ATTACHMENT_PG17_READY=YES"
# All Django commands use only the disposable network and credentials.
APP_ENV=(
  -e DJANGO_SECRET_KEY="$SECRET"
  -e VENCIRA_ENV=test
  -e VENCIRA_DB_ENGINE=postgresql
  -e POSTGRES_HOST="$POSTGRES"
  -e POSTGRES_DB=attlab
  -e POSTGRES_USER=attlab
  -e POSTGRES_PASSWORD="$PASS"
  -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1
  -e VENCIRA_M103_SPLIT_DELETE_LAB=1
)
run_django() {
  "${DOCKER[@]}" run --rm --network "$NETWORK" "${APP_ENV[@]}" "$IMAGE" python manage.py "$@"
}
# Targeting the independent app must require reminders 0018 but not 0019–27.
run_django migrate renewal_attachments --noinput >/dev/null || {
  echo "ATTACHMENT_PG17_MIGRATE=FAIL"; exit 5;
}
echo "ATTACHMENT_PG17_INDEPENDENT_MIGRATE=OK"
# Introspect the migration recorder; fail if any of the historical MFA chain
# or its MFA-gated 0027 attachment table has been applied.
CHECK=$(cat <<'PY'
from django.db.migrations.recorder import MigrationRecorder
from django.db import connection
rows = set(MigrationRecorder.Migration.objects.values_list("app", "name"))
rem = sorted(n for app,n in rows if app == "reminders")
att = sorted(n for app,n in rows if app == "renewal_attachments")
bad = [n for n in rem if n[:4].isdigit() and int(n[:4]) >= 19]
tables = set(connection.introspection.table_names())
assert len(rem) == 18 and rem[-1] == "0018_draft_reasons", rem
assert att and att[0] == "0001_initial", att
assert not bad, bad
assert "renewal_attachments_renewalattachment" in tables, tables
assert "reminders_usermfastate" not in tables, tables
assert "reminders_renewalattachment" not in tables, tables
print("ATTACHMENT_PG17_BASELINE_0018=OK")
print("ATTACHMENT_PG17_MFA_MIGRATIONS_APPLIED=0")
print("ATTACHMENT_PG17_INDEPENDENT_ATTACHMENT_TABLE=OK")
PY
)
run_django shell -c "$CHECK" | grep '^ATTACHMENT_PG17_' || {
  echo "ATTACHMENT_PG17_ISOLATION=FAIL"; exit 6;
}
# Test reversal only against disposable DB. Leaves real Django untouched.
run_django migrate renewal_attachments zero --noinput >/dev/null || {
  echo "ATTACHMENT_PG17_REVERSE=FAIL"; exit 7;
}
REVERSE_CHECK=$(cat <<'PY'
from django.db.migrations.recorder import MigrationRecorder
from django.db import connection
assert not MigrationRecorder.Migration.objects.filter(app="renewal_attachments").exists()
assert "renewal_attachments_renewalattachment" not in connection.introspection.table_names()
print("ATTACHMENT_PG17_ROLLBACK_SCHEMA=OK")
PY
)
run_django shell -c "$REVERSE_CHECK" | grep '^ATTACHMENT_PG17_ROLLBACK_SCHEMA=OK$' || exit 7
for srv in "$API" "$DB" "$WEB"; do
  test "$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$srv")" = "${BEFORE[$srv]}" || {
    echo "ATTACHMENT_PG17_LIVE_CHANGED=$srv"; exit 8; }
done
echo "ATTACHMENT_PG17_LIVE_CONTAINERS_UNCHANGED=OK"
echo "ATTACHMENT_PG17_REHEARSAL=PASS"
echo "ATTACHMENT_PG17_OPERATIONAL_RELEASE=NO"
echo "ATTACHMENT_PG17_LIVE_DB_MIGRATED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
