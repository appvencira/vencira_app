#!/usr/bin/env bash
# Exact prebuilt attachment API candidate: disposable PG17 + authenticated authorization smoke.
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
from datetime import date
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.test import Client
from reminders.models import Workspace, WorkspaceMember, Renewal
from renewal_attachments.models import RenewalAttachment
from django.db.migrations.recorder import MigrationRecorder

User = get_user_model()
users = [User.objects.create_user(username=n, password="disposable-only-test-password-2026", last_login=timezone.now()) for n in ("aowner","bowner","assigned","unassigned","outsider")]
ao,bo,assigned,unassigned,outsider = users
wa = Workspace.objects.create(name="fixture-A")
wb = Workspace.objects.create(name="fixture-B")
for u,w,role in [(ao,wa,"owner"),(bo,wb,"owner"),(assigned,wa,"member"),(unassigned,wa,"member")]:
    WorkspaceMember.objects.create(user=u, workspace=w, role=role)
ra = Renewal.objects.create(workspace=wa, assigned_to=assigned, customer_reference="fixture-A1", expires_on=date(2027,1,20))
ra2 = Renewal.objects.create(workspace=wa, assigned_to=unassigned, customer_reference="fixture-A2", expires_on=date(2027,1,21))
rb = Renewal.objects.create(workspace=wb, assigned_to=bo, customer_reference="fixture-B1", expires_on=date(2027,1,22))
def attach(r,u,name,digest):
    return RenewalAttachment.objects.create(renewal=r,uploaded_by=u,display_name=name,content_type="text/plain",byte_size=3,sha256=digest*64)
aa=attach(ra,ao,"fixture-a.txt","a")
aa2=attach(ra2,ao,"fixture-a2.txt","b")
ab=attach(rb,bo,"fixture-b.txt","c")
def url(w,r):
    return f"/api/v1/workspaces/{w.pk}/renewals/{r.pk}/attachments/"
def client(u):
    c=Client(HTTP_HOST="localhost")
    c.force_login(u)
    return c
def expect(c, method, path, status):
    response=getattr(c,method)(path)
    assert response.status_code == status, (method,response.status_code,status)
    return response
owner=client(ao)
member=client(assigned)
nonassigned=client(unassigned)
foreign=client(bo)
none=client(outsider)
p=url(wa,ra)
data=expect(owner,"get",p,200).json()
assert [i["id"] for i in data["results"]] == [str(aa.pk)],data
assert data["capabilities"]["upload"] is False
assert data["capabilities"]["download"] is False
assert data["capabilities"]["delete"] is False
assert data["results"][0]["download_enabled"] is False
assert data["results"][0]["delete_enabled"] is False
assert "storage_key" not in data["results"][0]
assert "sha256" not in data["results"][0]
assert expect(member,"get",p,200).json()["results"][0]["id"] == str(aa.pk)
print("ATT_API_AUTHORIZED_METADATA=PASS")
for c in (foreign,none,nonassigned):
    expect(c,"get",p,404)
expect(member,"get",url(wa,ra2),404)
expect(owner,"get",url(wb,rb),404)
expect(owner,"get",url(wa,rb),404)
expect(owner,"get",url(wb,ra),404)
print("ATT_API_CROSS_SCOPE_DENIED=PASS")
for c in (owner,member):
    expect(c,"post",p,403)
    expect(c,"get",p+str(aa.pk)+"/",403)
    expect(c,"delete",p+str(aa.pk)+"/",403)
    expect(c,"put",p,405)
    expect(c,"patch",p+str(aa.pk)+"/",405)
expect(owner,"get",p+str(ab.pk)+"/",404)
expect(owner,"delete",p+str(ab.pk)+"/",404)
expect(member,"get",p+str(aa2.pk)+"/",404)
assert RenewalAttachment.objects.count()==3
assert not [n for a,n in MigrationRecorder.Migration.objects.values_list("app","name") if a=="reminders" and n[:4].isdigit() and int(n[:4])>=19]
print("ATT_API_WRITES_AND_DOWNLOADS_FENCED=PASS")
print("ATT_API_FIXTURE_COUNTS_UNCHANGED=PASS")
PY
)"
django shell -c "$CHECK" | grep '^ATT_API_' || {
  echo "ATT_API_AUTH_SCOPE_GATE=FAIL"; exit 7; }
CLEANUP="$(cat <<'PY'
from renewal_attachments.models import RenewalAttachment
RenewalAttachment.objects.all().delete()
print("ATT_API_FIXTURE_CLEANUP=OK")
PY
)"
django shell -c "$CLEANUP" | grep '^ATT_API_FIXTURE_CLEANUP=OK$' || exit 8
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
echo "ATT_API_AUTH_SCOPE_RESULT=PASS"
echo "ATT_API_DEPLOY_EXECUTED=NO"
echo "ATT_API_LIVE_MIGRATIONS_EXECUTED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
