#!/usr/bin/env bash
# I8-M: real TLS + Django test-only boundary, no auth material or public ports.
# Never contacts operational HTTP endpoints, DEV DB or any external service.
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
tag="vencira-i8m-tls-$$"
network="$tag-net"
database="$tag-db"
server="$tag-server"
image_name="$tag:lab"
network_created=0
image_created=0
cleanup() {
  local rc=$?
  trap - EXIT
  D rm -f "$server" "$database" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_created" == 1 ]]; then D image rm "$image_name" >/dev/null 2>&1 || true; fi
  rm -f "$tmp/env" "$tmp/cert.pem" "$tmp/key.pem"
  rmdir "$tmp" 2>/dev/null || true
  local stable=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${original[$name]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "MAIN_I8M_TLS_DEV_CONTAINERS_UNCHANGED=OK"; else
    echo "MAIN_I8M_TLS_DEV_CONTAINERS_UNCHANGED=FAIL"; rc=9
  fi
  echo "MAIN_I8M_TLS_DEPLOY_EXECUTED=NO"
  echo "MAIN_I8M_TLS_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "MAIN_I8M_TLS_BOUNDARY_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT

D build -q -t "$image_name" ./backend >/dev/null
image_created=1
echo "MAIN_I8M_TLS_DISPOSABLE_IMAGE=OK"
db_password="$(openssl rand -hex 24)"
django_key="$(openssl rand -hex 36)"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=native-i8k.test
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
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_G5_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_G5_ABUSE_KEY=$(openssl rand -hex 36)
EOF
chmod 600 "$tmp/env"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
  -subj '/CN=native-i8k.test' \
  -addext 'subjectAltName=DNS:native-i8k.test' >/dev/null 2>&1
# Docker's non-root image user requires read permission on bind-mounted
# synthetic TLS keys. Parent host directory stays private (0700).
chmod 644 "$tmp/key.pem" "$tmp/cert.pem"

D network create --internal "$network" >/dev/null
network_created=1
[[ "$(D network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 4
echo "MAIN_I8M_TLS_DOCKER_NETWORK_INTERNAL=PASS"
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
echo "MAIN_I8M_TLS_PG17_EPHEMERAL_READY=PASS"
django() { D run --rm --network "$network" --env-file "$tmp/env" "$image_name" python manage.py "$@"; }
django check >/dev/null
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
django migrate --noinput >/dev/null
echo "MAIN_I8M_TLS_EPHEMERAL_MIGRATIONS=PASS"

D run -d --name "$server" --network "$network" \
  --network-alias native-i8k.test --env-file "$tmp/env" \
  -e PYTHONPATH=/app \
  --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$root/scripts/native_i8k_https_server.py:/opt/i8k_server.py:ro" \
  -v "$tmp/cert.pem:/tmp/i8k-cert.pem:ro" \
  -v "$tmp/key.pem:/tmp/i8k-key.pem:ro" \
  "$image_name" python -u /opt/i8k_server.py >/dev/null
server_ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket; s=socket.create_connection(("127.0.0.1",8443),1);s.close()' >/dev/null 2>&1; then
    server_ready=YES; break
  fi
  sleep 1
done
if [[ "$server_ready" != YES ]]; then
  echo "MAIN_I8M_TLS_SERVER_READY=FAIL" >&2
  D logs --tail 10 "$server" >&2 || true
  exit 6
fi
echo "MAIN_I8M_TLS_SERVER_READY=PASS"

D run --rm --network "$network" --env-file "$tmp/env" \
  -e VENCIRA_I8M_INTERNAL_TLS_PROBE=1 \
  --read-only --tmpfs /tmp:rw,size=32m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 64 \
  -v "$root/scripts/main_i8m_tls_boundary_probe.py:/opt/i8m_probe.py:ro" \
  -v "$tmp/cert.pem:/tmp/i8m-public-cert.pem:ro" \
  "$image_name" python -u /opt/i8m_probe.py

echo "MAIN_I8M_TLS_BOUNDARY_GATE=PASS"
