#!/usr/bin/env bash
# D1-U: candidate HTTPS over isolated synthetic PostgreSQL 17.
# HTTPS termination is a disposable Python WSGI lab, NOT Caddy.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D1U_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for tool in docker git openssl sudo; do command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }; done
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || { mark MAIN_HEAD_REQUIRED FAIL; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  sudo -v
  D(){ sudo docker "$@"; }
fi
declare -A dev_ids
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || { mark DEV_IDENTITY FAIL; exit 3; }
  dev_ids["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
nonce="$(openssl rand -hex 8)"
net="vencira-d1u-$nonce-net"
db="vencira-d1u-$nonce-db"
api="vencira-d1u-$nonce-api"
img="vencira-d1u-$nonce-django"
work="$(mktemp -d /tmp/vencira-d1u.XXXXXXXX)"
chmod 700 "$work"
network_created=NO
database_created=NO
api_created=NO
image_created=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$api_created" == YES ]]; then D rm -f "$api" >/dev/null 2>&1 || rc=9; fi
  if [[ "$database_created" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$network_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  if [[ "$image_created" == YES ]]; then D image rm "$img" >/dev/null 2>&1 || rc=9; fi
  rm -f "$work"/{env,server.pem,server.key} || rc=9
  rmdir "$work" >/dev/null 2>&1 || rc=9
  local intact=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" == "${dev_ids[$name]}" ]] || intact=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$intact" == YES ]] && echo OK || echo FAIL)"
  [[ "$intact" == YES ]] || rc=9
  mark EPHEMERAL_CLEANUP "$([[ "$rc" == 9 ]] && echo FAIL || echo DONE)"
  mark DEPLOY_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D network create --internal "$net" >/dev/null
network_created=YES
[[ "$(D network inspect -f '{{.Internal}}' "$net")" == true ]] || exit 4
mark INTERNAL_NETWORK PASS
password="$(openssl rand -hex 24)"
D run -d --name "$db" --network "$net" --security-opt no-new-privileges --pids-limit 256 \
  --memory 2g --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB=d1u -e POSTGRES_USER=d1u -e POSTGRES_PASSWORD="$password" \
  postgres:17-alpine >/dev/null
database_created=YES
[[ "$(D inspect -f '{{.HostConfig.NetworkMode}}' "$db")" == "$net" ]] || exit 4
[[ -z "$(D inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "$db")" ]] || exit 4
ready=NO
for _ in $(seq 1 60); do
  if D exec "$db" pg_isready -U d1u -d d1u >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark PG17_TMPFS FAIL; exit 4; }
mark PG17_TMPFS PASS
D build -q -t "$img" "$root/backend" >/dev/null
image_created=YES
mark CANDIDATE_IMAGE PASS
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
  -keyout "$work/server.key" -out "$work/server.pem" \
  -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost' \
  >/dev/null 2>&1
chmod 644 "$work/server.key" "$work/server.pem"
# Synthetic one-day key, held inside a 0700 temporary directory on host.
cat > "$work/env" <<EOF
VENCIRA_ENV=test
DJANGO_SETTINGS_MODULE=config.settings
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d1u
POSTGRES_USER=d1u
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
EOF
chmod 600 "$work/env"
django(){
  D run --rm --network "$net" --env-file "$work/env" \
    --security-opt no-new-privileges --pids-limit 256 --memory 2g \
    "$img" python manage.py "$@"
}
django check >/dev/null 2>&1 || { mark CHECK FAIL; exit 5; }
django makemigrations --check --dry-run --noinput >/dev/null 2>&1 || { mark MODEL_PARITY FAIL; exit 5; }
django migrate --noinput >/dev/null 2>&1 || { mark SYNTHETIC_MIGRATIONS FAIL; exit 5; }
mark SYNTHETIC_MIGRATIONS PASS
D run -d --name "$api" --network "$net" --env-file "$work/env" \
  --security-opt no-new-privileges --pids-limit 256 --memory 2g \
  --read-only --tmpfs /tmp:rw,size=128m,mode=1777 \
  -v "$root/scripts/main_d1u_https_candidate_lab.py:/opt/d1u.py:ro" \
  -v "$work/server.pem:/opt/server.pem:ro" \
  -v "$work/server.key:/opt/server.key:ro" \
  "$img" python /opt/d1u.py serve --cert /opt/server.pem --key /opt/server.key >/dev/null
api_created=YES
[[ "$(D inspect -f '{{.HostConfig.NetworkMode}}' "$api")" == "$net" ]] || exit 5
[[ -z "$(D inspect -f '{{.HostConfig.PortBindings}}' "$api")" || "$(D inspect -f '{{.HostConfig.PortBindings}}' "$api")" == 'map[]' ]] || exit 5
mark CANDIDATE_CONTAINER_INTERNAL PASS
started=NO
for _ in $(seq 1 30); do
  if [[ "$(D inspect -f '{{.State.Running}}' "$api" 2>/dev/null || true)" != true ]]; then
    mark HTTPS_SERVER_RUNNING FAIL
    exit 6
  fi
  if D exec "$api" python -c 'import socket; socket.create_connection(("127.0.0.1", 18443), 2).close()' >/dev/null 2>&1; then
    started=YES
    break
  fi
  sleep 1
done
[[ "$started" == YES ]] || { mark HTTPS_SERVER_READY FAIL; exit 6; }
mark HTTPS_SERVER_READY PASS
# Run once after TCP readiness; report only sanitized negative case/status.
D exec "$api" python /opt/d1u.py probe --cert /opt/server.pem || {
  mark HTTPS_CONTRACT_PROBE FAIL
  mark HTTPS_CANDIDATE FAIL
  exit 6
}
mark HTTPS_CONTRACT_PROBE PASS
mark HTTPS_CANDIDATE PASS
mark TRUSTED_CERT_AND_HOSTNAME PASS
mark UNTRUSTED_AND_HOSTNAME_NEGATIVE PASS
mark COMPOSE_SEMANTIC_REVIEW NOT_RUN
mark CADDY_OPERATIVE_CONFIG_REVIEW NOT_RUN
mark CADDY_CANDIDATE_HTTPS_VERIFIED NO
mark ROLLBACK_PRACTICED NO
mark CANDIDATE_HTTPS_LAB_GATE PASS
