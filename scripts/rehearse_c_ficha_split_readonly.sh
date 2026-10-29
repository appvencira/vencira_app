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
phase=INDEPENDENT_EVIDENCE_SCHEMA
# Extend the independent path through signed evidence and anti-replay
# BEFORE the disposable MFA coexistence rehearsal.
"${DCMD[@]}" migrate renewal_attachments 0004_attachmentdiscardjob --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c '
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
from django.db.migrations.loader import MigrationLoader
applied = MigrationRecorder(connection).applied_migrations()
path = set(MigrationLoader(None).graph.forwards_plan(
    ("renewal_attachments", "0004_attachmentdiscardjob")))
blocked = {f"{n:04d}" for n in range(19, 28)}
assert not any(app == "reminders" and name[:4] in blocked for app, name in path)
assert not any(app == "reminders" and name[:4] in blocked for app, name in applied)
assert ("renewal_attachments", "0004_attachmentdiscardjob") in applied
tables = set(connection.introspection.table_names())
assert "renewal_attachments_attachmentscanevidence" in tables
assert "renewal_attachments_attachmentdiscardjob" in tables
print("INDEPENDENT_EVIDENCE_GRAPH_NO_MFA=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_OUTBOX_0004_WITHOUT_MFA=OK"
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
phase=RECOVERY_SCHEMA_READY
# D10 tests require AttachmentRecoveryCase (0005). Confirm the complete
# independent schema in disposable PG17 before invoking the test runner.
"${DCMD[@]}" migrate renewal_attachments 0006_ed25519_signature_length --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c '
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
applied = MigrationRecorder(connection).applied_migrations()
assert ("renewal_attachments", "0005_recoverycase") in applied
assert ("renewal_attachments", "0006_ed25519_signature_length") in applied
assert "renewal_attachments_attachmentrecoverycase" in connection.introspection.table_names()
' >>"$LOG" 2>&1
echo "B18B_RECOVERY_SCHEMA_READY=OK"
phase=TRANSITION_SYNTHETIC
"${DCMD[@]}" shell -c '
from datetime import date
from reminders.models import Workspace, Renewal, RenewalAttachment as Legacy
from renewal_attachments.models import RenewalAttachment as New
from renewal_attachments.transition_preflight import inspect_attachment_transition
initial = inspect_attachment_transition()
assert initial.safe_empty_transition and initial.reason == "EMPTY_SCHEMAS_ONLY"
ws = Workspace.objects.create(name="SYNTHETIC_SPLIT_ONLY")
renewal = Renewal.objects.create(
    workspace=ws, customer_reference="SYNTHETIC-001",
    full_name="Synthetic", expires_on=date(2027, 5, 1))
row = Legacy.objects.create(renewal=renewal, display_name="synthetic.pdf",
    content_type="application/pdf", byte_size=10, sha256="a"*64)
blocked = inspect_attachment_transition()
assert not blocked.safe_empty_transition
assert blocked.reason == "LEGACY_RECORDS_REQUIRE_VERIFIED_RECONCILIATION"
row.delete()
new_row = New.objects.create(renewal=renewal, display_name="synthetic.png",
    content_type="image/png", byte_size=10, sha256="b"*64)
blocked_new = inspect_attachment_transition()
assert not blocked_new.safe_empty_transition
assert blocked_new.reason == "INDEPENDENT_RECORDS_REQUIRE_VERIFIED_RECONCILIATION"
new_row.delete()
assert inspect_attachment_transition().safe_empty_transition
print("C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK"
phase=RECONCILIATION_SYNTHETIC
"${DCMD[@]}" shell -c '
from datetime import date
from reminders.models import Workspace, Renewal, RenewalAttachment as Legacy
from renewal_attachments.models import RenewalAttachment as New
from renewal_attachments.transition_reconciliation import inspect_reconciliation
from django.db import transaction
with transaction.atomic():
    baseline = inspect_reconciliation()
    assert baseline.legacy_count == 0 and baseline.independent_count == 0
    assert not baseline.release_authorized
    ws = Workspace.objects.create(name="SYNTHETIC_RECONCILIATION")
    ren = Renewal.objects.create(workspace=ws, customer_reference="SYNTHETIC-REC",
        full_name="Synthetic", expires_on=date(2027, 5, 2))
    legacy = Legacy.objects.create(renewal=ren, display_name="synthetic.pdf",
        content_type="application/pdf", byte_size=10, sha256="c"*64)
    only_old = inspect_reconciliation()
    assert only_old.missing_in_independent == 1
    assert only_old.conflicting_records == 0
    copy = New.objects.create(id=legacy.id, renewal=ren,
        storage_key=legacy.storage_key, display_name=legacy.display_name,
        content_type=legacy.content_type, byte_size=legacy.byte_size,
        sha256=legacy.sha256, state=legacy.state)
    matching = inspect_reconciliation()
    assert matching.missing_in_independent == 0
    assert matching.missing_in_legacy == 0
    assert matching.conflicting_records == 0
    assert matching.reused_storage_keys == 0
    assert matching.release_authorized is False
    copy.display_name = "different.pdf"
    copy.save(update_fields=["display_name"])
    conflict = inspect_reconciliation()
    assert conflict.conflicting_records == 1
    copy.delete()
    legacy.delete()
print("C_FICHA_SPLIT_RECONCILIATION_READONLY=OK")
' >>"$LOG" 2>&1
echo "C_FICHA_SPLIT_RECONCILIATION_READONLY=OK"
phase=INDEPENDENT_APP_TESTS
# The test runner creates its own temporary test database; never use the live DB.
if [ "${B18B_FOCUSED:-0}" = 1 ]; then
  # The broad suite includes B14EF real clamd and B17C2 two-container
  # networking, which need their own already-established harnesses.
  # Do NOT skip them in a full C-FICHA release gate.
  "${DCMD[@]}" test renewal_attachments.test_recovery_persistence_d10 \
    --noinput --verbosity 2 >>"$LOG" 2>&1
  echo "B18B_D10_PG17_TESTS=OK"
  echo "B18B_FOCUSED_ONLY=1"
  echo "C_FICHA_FULL_SUITE=NOT_RUN"
else
  "${DCMD[@]}" test renewal_attachments --noinput --verbosity 1 >>"$LOG" 2>&1
  echo "C_FICHA_SPLIT_OBJECT_AUDIT_TESTS=OK"
fi
echo "C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO"
