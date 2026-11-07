#!/usr/bin/env bash
# HTTPS transport + Django password/cookie/CSRF against an isolated attachment candidate.
# No host ports, no live database, no production credential, no deploy.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for program in docker openssl git python3; do command -v "$program" >/dev/null || exit 2; done
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() {
  if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi
}
IMAGE="vencira-attachment-api-candidate:f8efc90a2647"
BASE_SHA="4eb0130d9d1cb191b6e6654a9d8037e5b178cf50"
SOURCE_SHA="f8efc90a26474ca2f88897c1e9c563749dba1174"
test "$(D image inspect -f '{{index .Config.Labels "es.vencira.attachment.base"}}' "$IMAGE")" = "$BASE_SHA" || exit 3
test "$(D image inspect -f '{{index .Config.Labels "es.vencira.attachment.source"}}' "$IMAGE")" = "$SOURCE_SHA" || exit 3
echo "ATT_HTTPS_EXACT_CANDIDATE_IMAGE=OK"
declare -A BEFORE
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service")" = vencira_localcheck || exit 4
  test "$(D inspect -f '{{.State.Health.Status}}' "$service")" = healthy || exit 4
  BEFORE[$service]="$(D inspect -f '{{.Id}}:{{.Image}}' "$service")"
done

TMP="$(mktemp -d /tmp/vencira-attachment-https.XXXXXXXX)"
chmod 700 "$TMP"
NETWORK="vencira-att-https-$$"
DB="vencira-att-https-db-$$"
SERVER="vencira-att-https-srv-$$"
network_created=0
pass="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
cleanup() {
  local status=$?
  trap - EXIT
  D rm -f "$SERVER" "$DB" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$NETWORK" >/dev/null 2>&1 || true; fi
  local stable=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" != "${BEFORE[$service]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then
    echo "ATT_HTTPS_LIVE_CONTAINERS_UNCHANGED=OK"
  else
    echo "ATT_HTTPS_LIVE_CONTAINERS_UNCHANGED=FAIL"
    status=9
  fi
  if [[ "$TMP" == /tmp/vencira-attachment-https.* && -d "$TMP" ]]; then
    rm -f "$TMP/app.env" "$TMP/cert.pem" "$TMP/key.pem"
    rmdir "$TMP" || true
  fi
  echo "ATT_HTTPS_DEPLOY_EXECUTED=NO"
  echo "ATT_HTTPS_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "ATT_HTTPS_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

cat > "$TMP/app.env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=attachment.test
DJANGO_HTTPS_BEHIND_PROXY=1
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_HOST=$DB
POSTGRES_DB=attlab
POSTGRES_USER=attlab
POSTGRES_PASSWORD=$pass
EOF
chmod 600 "$TMP/app.env"
openssl req -x509 -nodes -newkey rsa:2048 \
 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
 -days 1 -subj "/CN=attachment.test" \
 -addext "subjectAltName=DNS:attachment.test" >/dev/null 2>&1
# TLS key remains inside private 0700 host temp directory, mounted only into disposable server.
chmod 644 "$TMP/key.pem" "$TMP/cert.pem"

D network create --internal "$NETWORK" >/dev/null
network_created=1
test "$(D network inspect -f '{{.Internal}}' "$NETWORK")" = true || exit 5
echo "ATT_HTTPS_DOCKER_INTERNAL_ONLY=OK"
D run --rm -d --name "$DB" --network "$NETWORK" \
  --tmpfs /var/lib/postgresql/data:rw,size=256m \
  -e POSTGRES_DB=attlab -e POSTGRES_USER=attlab -e POSTGRES_PASSWORD="$pass" \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$DB" pg_isready -U attlab -d attlab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" = YES || exit 6
echo "ATT_HTTPS_PG17_READY=YES"
django() {
  D run --rm --network "$NETWORK" --env-file "$TMP/app.env" "$IMAGE" python manage.py "$@"
}
django check >/dev/null
django migrate renewal_attachments --noinput >/dev/null
django migrate sessions --noinput >/dev/null
echo "ATT_HTTPS_PG17_SCHEMA_PREPARED=OK"
FIXTURE="$(cat <<'PY'
from datetime import date
from uuid import UUID
from django.contrib.auth import get_user_model
from django.utils import timezone
from reminders.models import Workspace,WorkspaceMember,Renewal
from renewal_attachments.models import RenewalAttachment
from django.db.migrations.recorder import MigrationRecorder
u=get_user_model().objects.create_user(username="att-https-owner",password="disposable-only-attachment-https-password-2026",last_login=timezone.now())
w=Workspace.objects.create(id=UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),name="attachment-https-disposable")
WorkspaceMember.objects.create(user=u,workspace=w,role="owner")
r=Renewal.objects.create(id=UUID("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"),workspace=w,assigned_to=u,customer_reference="https-lab-only",expires_on=date(2027,1,20))
a=RenewalAttachment.objects.create(id=UUID("cccccccc-cccc-4ccc-8ccc-cccccccccccc"),renewal=r,uploaded_by=u,display_name="synthetic.txt",content_type="text/plain",byte_size=3,sha256="a"*64)
assert not [n for x,n in MigrationRecorder.Migration.objects.values_list("app","name") if x=="reminders" and n[:4].isdigit() and int(n[:4])>=19]
print("ATT_HTTPS_SYNTHETIC_FIXTURE=OK")
PY
)"
django shell -c "$FIXTURE" | grep -Fx "ATT_HTTPS_SYNTHETIC_FIXTURE=OK"
D run -d --name "$SERVER" --network "$NETWORK" \
  --network-alias attachment.test --env-file "$TMP/app.env" \
  -e PYTHONPATH=/app \
  --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$ROOT/scripts/attachment_https_lab_server.py:/opt/attachment_https_lab_server.py:ro" \
  -v "$TMP/cert.pem:/tmp/attachment-lab-cert.pem:ro" \
  -v "$TMP/key.pem:/tmp/attachment-lab-key.pem:ro" \
  "$IMAGE" python -u /opt/attachment_https_lab_server.py >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$SERVER" python -c 'import socket;s=socket.create_connection(("127.0.0.1",8443),timeout=1);s.close()' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
if [[ "$ready" != YES ]]; then
  echo "ATT_HTTPS_LAB_SERVER_READY=FAIL"
  echo "ATT_HTTPS_LAB_SERVER_DIAGNOSTICS_BEGIN"
  D inspect -f 'ATT_HTTPS_LAB_CONTAINER_STATUS={{.State.Status}} EXIT={{.State.ExitCode}}' "$SERVER" || true
  D logs --tail 50 "$SERVER" || true
  echo "ATT_HTTPS_LAB_SERVER_DIAGNOSTICS_END"
  exit 7
fi
echo "ATT_HTTPS_LAB_SERVER_READY=YES"

D run --rm --network "$NETWORK" \
  --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$ROOT/scripts/attachment_https_lab_probe.py:/opt/attachment_https_lab_probe.py:ro" \
  -v "$TMP/cert.pem:/tmp/attachment-lab-cert.pem:ro" \
  "$IMAGE" python -u /opt/attachment_https_lab_probe.py
D rm -f "$SERVER" >/dev/null
django shell -c 'from renewal_attachments.models import RenewalAttachment; assert RenewalAttachment.objects.count()==1; RenewalAttachment.objects.all().delete(); assert RenewalAttachment.objects.count()==0; print("ATT_HTTPS_FIXTURE_CLEANUP=OK")' | grep -Fx "ATT_HTTPS_FIXTURE_CLEANUP=OK"
django migrate renewal_attachments zero --noinput >/dev/null
REVERSE="$(cat <<'PY'
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
assert not MigrationRecorder.Migration.objects.filter(app="renewal_attachments").exists()
assert "renewal_attachments_renewalattachment" not in connection.introspection.table_names()
print("ATT_HTTPS_PG17_ROLLBACK=OK")
PY
)"
django shell -c "$REVERSE" | grep -Fx "ATT_HTTPS_PG17_ROLLBACK=OK"
echo "ATT_HTTPS_GATE_RESULT=PASS"
