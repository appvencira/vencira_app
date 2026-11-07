#!/usr/bin/env bash
# Exact prebuilt attachment API candidate: disposable PG17 + anonymous HTTP smoke.
# NEVER deploy or connect to DEV PostgreSQL; deliberately no Compose up/migrate.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DOCKER=(docker)
if [[ "$(id -u)" -ne 0 ]]; then sudo -v; DOCKER=(sudo docker); fi
for c in git openssl; do command -v "$c" >/dev/null || exit 2; done
API=vencira_localcheck-api-1
DB=vencira_localcheck-db-1
WEB=vencira_localcheck-web_preview-1
IMAGE="vencira-attachment-api-candidate:f8efc90a2647"
BASE_SHA="4eb0130d9d1cb191b6e6654a9d8037e5b178cf50"
SOURCE_SHA="f8efc90a26474ca2f88897c1e9c563749dba1174"
declare -A BEFORE
for srv in "$API" "$DB" "$WEB"; do
  test "$("${DOCKER[@]}" inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$srv")" = vencira_localcheck || exit 3
  test "$("${DOCKER[@]}" inspect -f '{{.State.Health.Status}}' "$srv")" = healthy || exit 3
  BEFORE[$srv]="$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$srv")"
done
test "$("${DOCKER[@]}" image inspect -f '{{index .Config.Labels "es.vencira.attachment.base"}}' "$IMAGE")" = "$BASE_SHA" || {
  echo "ATT_API_EXACT_IMAGE_BASE_MISMATCH=DENIED"; exit 4; }
test "$("${DOCKER[@]}" image inspect -f '{{index .Config.Labels "es.vencira.attachment.source"}}' "$IMAGE")" = "$SOURCE_SHA" || {
  echo "ATT_API_EXACT_IMAGE_SOURCE_MISMATCH=DENIED"; exit 4; }
IMAGE_ID="$("${DOCKER[@]}" image inspect -f '{{.Id}}' "$IMAGE")"
echo "ATT_API_EXACT_IMAGE_VERIFIED=YES"
echo "ATT_API_EXACT_IMAGE_ID=$IMAGE_ID"
NETWORK="vencira-att-api-gate-$$"
POSTGRES="vencira-att-api-db-$$"
PASS="$(openssl rand -hex 28)"
SECRET="$(openssl rand -hex 36)"
cleanup() {
  "${DOCKER[@]}" rm -f "$POSTGRES" >/dev/null 2>&1 || true
  "${DOCKER[@]}" network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT
"${DOCKER[@]}" network create --internal "$NETWORK" >/dev/null
"${DOCKER[@]}" run -d --rm --name "$POSTGRES" --network "$NETWORK" \
  -e POSTGRES_DB=attlab -e POSTGRES_USER=attlab -e POSTGRES_PASSWORD="$PASS" \
  --tmpfs /var/lib/postgresql/data:rw,size=256m postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if "${DOCKER[@]}" exec "$POSTGRES" pg_isready -U attlab -d attlab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" = YES || { echo "ATT_API_PG17_READY=FAIL"; exit 5; }
echo "ATT_API_PG17_READY=YES"
APP_ENV=(
 -e DJANGO_SECRET_KEY="$SECRET" -e VENCIRA_ENV=test
 -e VENCIRA_DB_ENGINE=postgresql -e POSTGRES_HOST="$POSTGRES"
 -e POSTGRES_DB=attlab -e POSTGRES_USER=attlab -e POSTGRES_PASSWORD="$PASS"
)
django() {
  "${DOCKER[@]}" run --rm --network "$NETWORK" "${APP_ENV[@]}" "$IMAGE" python manage.py "$@"
}
django check >/dev/null
echo "ATT_API_PG17_DJANGO_CHECK=OK"
django migrate renewal_attachments --plan | grep -F 'renewal_attachments' >/dev/null || {
 echo "ATT_API_PG17_MIGRATION_PLAN=FAIL"; exit 6; }
echo "ATT_API_PG17_MIGRATION_PLAN=OK"
django migrate renewal_attachments --noinput >/dev/null
echo "ATT_API_PG17_MIGRATE=OK"
CHECK="$(cat <<'PY'
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
from django.test import Client
from uuid import uuid4
rows = set(MigrationRecorder.Migration.objects.values_list("app", "name"))
rem = sorted(n for app,n in rows if app == "reminders")
att = sorted(n for app,n in rows if app == "renewal_attachments")
assert len(rem) == 18 and rem[-1] == "0018_draft_reasons", rem
assert att and att[0] == "0001_initial", att
assert not [n for n in rem if n[:4].isdigit() and int(n[:4]) >= 19]
tables = set(connection.introspection.table_names())
assert "renewal_attachments_renewalattachment" in tables
assert "reminders_renewalattachment" not in tables
assert "reminders_usermfastate" not in tables
print("ATT_API_PG17_MFA_APPLIED=0")
print("ATT_API_PG17_INDEPENDENT_TABLE=OK")
client = Client(HTTP_HOST="localhost")
base = f"/api/v1/workspaces/{uuid4()}/renewals/{uuid4()}/attachments/"
for method in ("get", "post"):
    response = getattr(client, method)(base)
    assert response.status_code in (401,403), (method, response.status_code)
    assert response.get("Cache-Control") != "public"
print("ATT_API_HTTP_ANONYMOUS_DENIED=OK")
detail = base + f"{uuid4()}/"
for method in ("get","delete"):
    response = getattr(client, method)(detail)
    assert response.status_code in (401,403), (method, response.status_code)
print("ATT_API_HTTP_ANONYMOUS_DETAIL_DENIED=OK")
PY
)"
django shell -c "$CHECK" | grep '^ATT_API_' || {
  echo "ATT_API_PG17_HTTP_CHECK=FAIL"; exit 7; }
django migrate renewal_attachments zero --noinput >/dev/null
REVERSE="$(cat <<'PY'
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
assert not MigrationRecorder.Migration.objects.filter(app="renewal_attachments").exists()
assert "renewal_attachments_renewalattachment" not in connection.introspection.table_names()
print("ATT_API_PG17_ROLLBACK=OK")
PY
)"
django shell -c "$REVERSE" | grep '^ATT_API_PG17_ROLLBACK=OK$' || exit 8
for srv in "$API" "$DB" "$WEB"; do
 test "$("${DOCKER[@]}" inspect -f '{{.Id}}:{{.Image}}' "$srv")" = "${BEFORE[$srv]}" || {
   echo "ATT_API_LIVE_CHANGED=$srv"; exit 9; }
done
echo "ATT_API_LIVE_CONTAINERS_UNCHANGED=OK"
echo "ATT_API_PG17_EXACT_CANDIDATE_RESULT=PASS"
echo "ATT_API_DEPLOY_EXECUTED=NO"
echo "ATT_API_LIVE_MIGRATIONS_EXECUTED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
