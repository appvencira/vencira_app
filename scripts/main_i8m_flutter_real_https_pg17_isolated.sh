#!/usr/bin/env bash
# I8-M: real Flutter HTTPS recovery with synthetic MFA + disposable PG17.
# Only internal Docker containers contact test-only Django; no host ports.
set -Eeuo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for bin in docker openssl; do command -v "$bin" >/dev/null || exit 2; done
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }

declare -A original
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  [[ "$(D inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]] || exit 3
  original["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
tmp="$(mktemp -d /tmp/vencira-i8m-tls.XXXXXXXX)"
chmod 700 "$tmp"
tag="vencira-i8m-flutter-$"
network="$tag-net"
database="$tag-db"
server="$tag-server"
image_name="$tag:lab"
network_created=0
image_created=0
flutter_volume_created=0
pub_volume_created=0
flutter_volume="$tag-flutter"
pub_volume="$tag-pub"
cleanup() {
  local rc=$?
  trap - EXIT
  D rm -f "$server" "$database" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_created" == 1 ]]; then D image rm "$image_name" >/dev/null 2>&1 || true; fi
  if [[ "$flutter_volume_created" == 1 ]]; then D volume rm "$flutter_volume" >/dev/null 2>&1 || true; fi
  if [[ "$pub_volume_created" == 1 ]]; then D volume rm "$pub_volume" >/dev/null 2>&1 || true; fi
  rm -f "$tmp/env" "$tmp/cert.pem" "$tmp/key.pem"
  rmdir "$tmp" 2>/dev/null || true
  local stable=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${original[$name]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "MAIN_I8M_FLUTTER_TLS_DEV_CONTAINERS_UNCHANGED=OK"; else
    echo "MAIN_I8M_FLUTTER_TLS_DEV_CONTAINERS_UNCHANGED=FAIL"; rc=9
  fi
  echo "MAIN_I8M_FLUTTER_TLS_DEPLOY_EXECUTED=NO"
  echo "MAIN_I8M_FLUTTER_TLS_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "MAIN_I8M_FLUTTER_TLS_BOUNDARY_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT

D build -q -t "$image_name" ./backend >/dev/null
image_created=1
echo "MAIN_I8M_FLUTTER_TLS_DISPOSABLE_IMAGE=OK"
db_password="$(openssl rand -hex 24)"
django_key="$(openssl rand -hex 36)"
mfa_key="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\\n')"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=dev.vencira.es
DJANGO_SECRET_KEY=$django_key
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=i8klab
POSTGRES_USER=i8klab
POSTGRES_PASSWORD=$db_password
POSTGRES_HOST=$database
VENCIRA_NATIVE_SERVICE_CANDIDATE=1
VENCIRA_I8D_HTTP_LAB=1
VENCIRA_I8K_RECOVERY_LAB=1
VENCIRA_I8K_NETWORK_ISOLATED=1
VENCIRA_I8M_FLUTTER_INTERNAL_ONLY=1
VENCIRA_I8D_MFA_KEY=$mfa_key
VENCIRA_MFA_FERNET_KEYS=$mfa_key
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_G5_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_G5_ABUSE_KEY=$(openssl rand -hex 36)
EOF
chmod 600 "$tmp/env"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
  -subj '/CN=dev.vencira.es' \
  -addext 'subjectAltName=DNS:dev.vencira.es' >/dev/null 2>&1
# Docker's non-root image user requires read permission on bind-mounted
# synthetic TLS keys. Parent host directory stays private (0700).
chmod 644 "$tmp/key.pem" "$tmp/cert.pem"

D network create --internal "$network" >/dev/null
network_created=1
[[ "$(D network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 4
echo "MAIN_I8M_FLUTTER_TLS_DOCKER_NETWORK_INTERNAL=PASS"
D run --rm -d --name "$database" --network "$network" \
  --tmpfs /var/lib/postgresql/data:rw,size=384m \
  -e POSTGRES_DB=i8klab -e POSTGRES_USER=i8klab -e POSTGRES_PASSWORD="$db_password" \
  postgres:17-alpine >/dev/null
pg_ready=NO
for _ in $(seq 1 45); do
  if D exec "$database" pg_isready -U i8klab -d i8klab >/dev/null 2>&1; then pg_ready=YES; break; fi
  sleep 1
done
[[ "$pg_ready" == YES ]] || exit 5
echo "MAIN_I8M_FLUTTER_TLS_PG17_EPHEMERAL_READY=PASS"
django() { D run --rm --network "$network" --env-file "$tmp/env" "$image_name" python manage.py "$@"; }
django check >/dev/null
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
django migrate --noinput >/dev/null
echo "MAIN_I8M_FLUTTER_TLS_EPHEMERAL_MIGRATIONS=PASS"

D run -d --name "$server" --network "$network" \
  --network-alias dev.vencira.es --env-file "$tmp/env" \
  --sysctl net.ipv4.ip_unprivileged_port_start=0 \
  -e PYTHONPATH=/app \
  --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$root/scripts/native_i8k_https_server.py:/opt/i8k_server.py:ro" \
  -v "$tmp/cert.pem:/tmp/i8k-cert.pem:ro" \
  -v "$tmp/key.pem:/tmp/i8k-key.pem:ro" \
  "$image_name" python -u /opt/i8k_server.py >/dev/null
server_ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket; s=socket.create_connection(("127.0.0.1",443),1);s.close()' >/dev/null 2>&1; then
    server_ready=YES; break
  fi
  sleep 1
done
if [[ "$server_ready" != YES ]]; then
  echo "MAIN_I8M_FLUTTER_TLS_SERVER_READY=FAIL" >&2
  D logs --tail 10 "$server" >&2 || true
  exit 6
fi
echo "MAIN_I8M_FLUTTER_TLS_SERVER_READY=PASS"

# Public dependency bootstrap occurs BEFORE test authentication; only
# the Flutter SDK and public pub packages can access the internet. Source
# checkout is mounted read-only. The actual test runs --network internal.
D volume create "$flutter_volume" >/dev/null
flutter_volume_created=1
D volume create "$pub_volume" >/dev/null
pub_volume_created=1
D run --rm \
  -v "$root/clients/flutter:/source:ro" \
  -v "$flutter_volume:/work" -v "$pub_volume:/pub" \
  -e PUB_CACHE=/pub -w /work \
  ghcr.io/cirruslabs/flutter:3.44.0 \
  sh -c 'cp -a /source/. /work/ && flutter pub get && flutter analyze test/native_i8m_real_https_pg17_test.dart' 
echo "MAIN_I8M_FLUTTER_TLS_ANALYZE=PASS"

fixture="$(cat <<'PY'
import os
import time
import uuid
from django.contrib.auth import get_user_model
from reminders.models import UserMfaState
from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import totp_at
from native_mobile_service.candidate_two_step_issuer import (
    candidate_password_to_challenge, candidate_mfa_challenge_to_session,
)

secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
key = os.environ['VENCIRA_I8D_MFA_KEY']
User = get_user_model()
for name in ('i8m-recovery', 'i8m-failedstore'):
    user = User.objects.create_user(
        username=name, password='synthetic-i8m-password',
    )
    UserMfaState.objects.create(
        user=user, enabled=True, session_epoch=1,
        encrypted_totp_secret=encrypt_totp_secret(
            secret, user_id=user.pk, keys=[key],
        ),
    )
user = User.objects.get(username='i8m-recovery')
wire = candidate_password_to_challenge(
    username=user.username, password='synthetic-i8m-password',
    request_meta={'REMOTE_ADDR': '198.51.100.44'},
    event_id=uuid.uuid4(),
)
assert wire is not None
old = candidate_mfa_challenge_to_session(
    wire=wire, code=totp_at(secret, int(time.time()) - 30),
    keys=[key], event_id=uuid.uuid4(),
    timestamp=int(time.time()) - 30,
)
assert old is not None
print('MAIN_I8M_FLUTTER_TLS_FIXTURE_READY=PASS')
PY
)"
django shell -c "$fixture" | grep -Fx 'MAIN_I8M_FLUTTER_TLS_FIXTURE_READY=PASS'

# The Flutter test process sees no PostgreSQL credentials and no private
# TLS key. The synthetic public CA is the only certificate mounted in.
D run --rm --network "$network" \
  --read-only --tmpfs /tmp:rw,size=128m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$flutter_volume:/work" -v "$pub_volume:/pub" \
  -v "$tmp/cert.pem:/tmp/i8m-lab-ca.pem:ro" \
  -e PUB_CACHE=/pub -e VENCIRA_I8M_PUBLIC_CA_FILE=/tmp/i8m-lab-ca.pem \
  -e VENCIRA_ENV=test -e POSTGRES_DB=i8klab \
  -e VENCIRA_I8M_FLUTTER_INTERNAL_ONLY=1 \
  -w /work ghcr.io/cirruslabs/flutter:3.44.0 \
  flutter test --no-pub test/native_i8m_real_https_pg17_test.dart --reporter expanded
echo "MAIN_I8M_FLUTTER_TLS_REAL_CLIENT=PASS"

postcheck="$(cat <<'PY'
from django.contrib.auth import get_user_model
from native_mobile_service.models import MobileAccountFence, MobileDeviceSession
User = get_user_model()
recovered = User.objects.get(username='i8m-recovery')
failed = User.objects.get(username='i8m-failedstore')
assert MobileAccountFence.objects.get(user=recovered).generation == 1
assert MobileDeviceSession.objects.filter(
    user=recovered, revoked_at__isnull=True).count() == 1
assert MobileDeviceSession.objects.filter(
    user=recovered, revoked_at__isnull=False).count() == 1
print('MAIN_I8M_FLUTTER_TLS_ACCOUNT_RECOVERY_REVOCATION=PASS')
assert MobileAccountFence.objects.get(user=failed).generation == 1
assert MobileDeviceSession.objects.filter(
    user=failed, revoked_at__isnull=True).count() == 0
assert MobileDeviceSession.objects.filter(
    user=failed, revoked_at__isnull=False).count() == 1
print('MAIN_I8M_FLUTTER_TLS_STORAGE_FAILURE_REMOTE_REVOKE=PASS')
PY
)"
django shell -c "$postcheck" | grep -E '^MAIN_I8M_FLUTTER_TLS_(ACCOUNT_RECOVERY_REVOCATION|STORAGE_FAILURE_REMOTE_REVOKE)=PASS | grep -c '^MAIN_I8M_' | grep -Fx '2' >/dev/null
echo "MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS"
