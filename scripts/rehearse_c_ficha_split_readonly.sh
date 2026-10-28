#!/usr/bin/env bash
# Isolated PostgreSQL 17 schema rehearsal. NO connection to live database.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
LOG="$(mktemp /tmp/vencira-c-ficha-split.XXXXXXXX.log)"
NET="vencira_csplit_net_$$"; DB="vencira_csplit_db_$$"
net_ok=0; db_ok=0; phase=PREFLIGHT
finish() {
  rc=$?; trap - EXIT
  if [ "$db_ok" = 1 ]; then sudo docker rm -f "$DB" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$net_ok" = 1 ]; then sudo docker network rm "$NET" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$rc" -ne 0 ]; then echo "FAILED_PHASE=$phase"; tail -n 35 "$LOG"; fi
  echo "C_FICHA_SPLIT_PG17_RESULT=$rc"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "LOG_LOCAL=$LOG"
  exit "$rc"
}
trap finish EXIT
echo "COMMIT=$(git rev-parse HEAD)"
IMG="vencira-csplit:$(git rev-parse --short=12 HEAD)"
phase=BUILD
sudo docker build -t "$IMG" ./backend >>"$LOG" 2>&1
phase=PG17
sudo docker network create --internal "$NET" >>"$LOG" 2>&1; net_ok=1
sudo docker run -d --name "$DB" --network "$NET" \
  -e POSTGRES_DB=split_test -e POSTGRES_USER=split_test \
  -e POSTGRES_PASSWORD=synthetic-split-only postgres:17-alpine >>"$LOG" 2>&1
db_ok=1
ready=0
for _ in $(seq 1 40); do
  if sudo docker exec "$DB" pg_isready -U split_test -d split_test >>"$LOG" 2>&1; then ready=1; break; fi
  sleep 2
done
test "$ready" = 1
echo "C_FICHA_SPLIT_PG17_EPHEMERAL=OK"
DCMD=(sudo docker run --rm --network "$NET" \
  -e VENCIRA_ENV=test -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e VENCIRA_DB_ENGINE=postgresql \
  -e DJANGO_SECRET_KEY=synthetic-split-only-django-secret-2026-long \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=split_test \
  -e POSTGRES_USER=split_test -e POSTGRES_PASSWORD=synthetic-split-only \
  "$IMG" python manage.py)
phase=GRAPH
"${DCMD[@]}" shell -c '
from django.db.migrations.loader import MigrationLoader
graph=MigrationLoader(None).graph
path=set(graph.forwards_plan(("renewal_attachments","0001_initial")))
assert ("reminders","0018_draft_reasons") in path
assert not any(app=="reminders" and name[:4] in {
"0019","0020","0021","0022","0023","0024","0025","0026","0027"
} for app,name in path), path
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK"
phase=BASELINE
"${DCMD[@]}" migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
phase=INDEPENDENT_SCHEMA
"${DCMD[@]}" migrate renewal_attachments 0001_initial --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c '
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
applied=MigrationRecorder(connection).applied_migrations()
assert ("reminders","0018_draft_reasons") in applied
assert ("renewal_attachments","0001_initial") in applied
assert not any(app=="reminders" and name[:4] in {
"0019","0020","0021","0022","0023","0024","0025","0026","0027"
} for app,name in applied)
assert "renewal_attachments_renewalattachment" in connection.introspection.table_names()
assert "reminders_usermfastate" not in connection.introspection.table_names()
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_0001_WITHOUT_MFA=OK"
echo "C_FICHA_SPLIT_NO_MFA_TABLES=OK"
phase=ORM_ROUTING
"${DCMD[@]}" shell -c '
from django.apps import apps
from reminders.attachment_model_router import attachment_model
from reminders.attachment_gate import accessible_attachment_queryset
from django.test import override_settings
from django.core.exceptions import ImproperlyConfigured
class Membership:
    workspace_id = "00000000-0000-4000-8000-000000000001"
    user_id = 99999
    role = "owner"
assert attachment_model()._meta.label_lower == "renewal_attachments.renewalattachment"
assert accessible_attachment_queryset(Membership()).model is attachment_model()
assert attachment_model().objects.count() == 0
with override_settings(VENCIRA_ENV="production"):
    try:
        attachment_model()
        raise AssertionError("Test-only router was usable in production")
    except ImproperlyConfigured:
        pass
print("C_FICHA_SPLIT_ORM_ROUTING=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_ORM_ROUTING=OK"
phase=COEXISTENCE_EPHEMERAL_ONLY
# Historical MFA migrations are rehearsed ONLY in the disposable database.
# This does not grant permission to apply them to DEV or production.
"${DCMD[@]}" migrate reminders 0027_renewal_attachment_metadata --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c '
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
from reminders.models import RenewalAttachment as HistoricalAttachment
from renewal_attachments.models import RenewalAttachment as IndependentAttachment
from reminders.attachment_model_router import attachment_model
tables=set(connection.introspection.table_names())
assert HistoricalAttachment._meta.db_table == "reminders_renewalattachment"
assert IndependentAttachment._meta.db_table == "renewal_attachments_renewalattachment"
assert HistoricalAttachment._meta.db_table in tables
assert IndependentAttachment._meta.db_table in tables
assert HistoricalAttachment.objects.count() == 0
assert IndependentAttachment.objects.count() == 0
assert attachment_model() is IndependentAttachment
applied=MigrationRecorder(connection).applied_migrations()
assert ("reminders","0027_renewal_attachment_metadata") in applied
assert ("renewal_attachments","0001_initial") in applied
print("C_FICHA_SPLIT_BOTH_SCHEMAS_COEXIST=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_BOTH_SCHEMAS_COEXIST=OK"
echo "C_FICHA_SPLIT_HISTORICAL_MFA_EPHEMERAL_ONLY=OK"
echo "C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO"
