#!/usr/bin/env bash
# D1-W: true isolated Caddy TLS reverse proxy -> Gunicorn Django -> PG17 tmpfs.
# Does NOT use operational Caddy, DEV credentials, DEV volumes or host ports.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D1W_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for tool in docker git openssl python3; do
  command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }
done
python3 - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d1w_caddy_candidate_probe.py").read_text())
print("D1W_PROBE_SYNTAX=PASS")
PY
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  mark MAIN_HEAD_REQUIRED FAIL; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  command -v sudo >/dev/null || { mark SUDO_REQUIRED YES; exit 2; }
  sudo -v
  D(){ sudo docker "$@"; }
fi
declare -A live
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service" 2>/dev/null)" == vencira_localcheck ]] || {
    mark DEV_IDENTITY FAIL; exit 3;
  }
  live["$service"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$service")"
done
mark DEV_IDENTITY PASS
nonce="$(openssl rand -hex 8)"
net="vencira-d1w-$nonce-net"
db="vencira-d1w-$nonce-db"
api="vencira-d1w-$nonce-api"
proxy="vencira-d1w-$nonce-proxy"
web="vencira-d1w-$nonce-web"
img="vencira-d1w-$nonce-django"
work="$(mktemp -d /tmp/vencira-d1w.XXXXXXXX)"
chmod 700 "$work"
network_created=NO
db_created=NO
api_created=NO
proxy_created=NO
web_created=NO
image_created=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$proxy_created" == YES ]]; then D rm -f "$proxy" >/dev/null 2>&1 || rc=9; fi
  if [[ "$web_created" == YES ]]; then D rm -f "$web" >/dev/null 2>&1 || rc=9; fi
  if [[ "$api_created" == YES ]]; then D rm -f "$api" >/dev/null 2>&1 || rc=9; fi
  if [[ "$db_created" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$network_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  if [[ "$image_created" == YES ]]; then D image rm "$img" >/dev/null 2>&1 || rc=9; fi
  rm -f "$work"/env "$work"/lab.pem "$work"/lab.key "$work"/Caddyfile || rc=9
  rm -rf "$work/web" || rc=9
  rmdir "$work" >/dev/null 2>&1 || rc=9
  local intact=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" == "${live[$service]}" ]] || intact=NO
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
secret="$(openssl rand -hex 24)"
D run -d --name "$db" --network "$net" --network-alias d1w-db \
  --security-opt no-new-privileges --pids-limit 256 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB=d1w -e POSTGRES_USER=d1w -e POSTGRES_PASSWORD="$secret" \
  postgres:17-alpine >/dev/null
db_created=YES
ready=NO
for _ in $(seq 1 60); do
  if D exec "$db" pg_isready -U d1w -d d1w >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark POSTGRES_READY FAIL; exit 4; }
mark PG17_TMPFS PASS
D build -q -t "$img" "$root/backend" >/dev/null
image_created=YES
mark CANDIDATE_IMAGE PASS
cat > "$work/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=d1w-proxy,localhost,testserver
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d1w
POSTGRES_USER=d1w
POSTGRES_PASSWORD=$secret
POSTGRES_HOST=d1w-db
DJANGO_HTTPS_BEHIND_PROXY=1
VENCIRA_MFA_ENROLLMENT_ENABLED=0
EOF
chmod 600 "$work/env"
django(){
  D run --rm --network "$net" --env-file "$work/env" \
    --security-opt no-new-privileges --pids-limit 256 --memory 2g \
    "$img" python manage.py "$@"
}
django check >/dev/null 2>&1 || { mark DJANGO_CHECK FAIL; exit 5; }
django makemigrations --check --dry-run --noinput >/dev/null 2>&1 || { mark MODEL_PARITY FAIL; exit 5; }
django migrate --noinput >/dev/null 2>&1 || { mark SYNTHETIC_MIGRATIONS FAIL; exit 5; }
mark SYNTHETIC_MIGRATIONS PASS
D run -d --name "$api" --network "$net" --network-alias d1w-api \
  --env-file "$work/env" --security-opt no-new-privileges \
  --pids-limit 256 --memory 2g "$img" >/dev/null
api_created=YES
mark GUNICORN_STARTED YES
# Build actual Flutter Web release in a disposable copy, then export assets only.
mkdir -p "$work/web"
chmod 755 "$work/web"
D run --rm --memory 4g --tmpfs /tmp:rw,size=3g,mode=1777 \
  -v "$root/clients/flutter:/source:ro" \
  -v "$work/web:/export" ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
    cp -a /source /tmp/flutter-app
    cd /tmp/flutter-app
    flutter pub get >/dev/null
    flutter build web --release >/dev/null
    test -s build/web/index.html
    test -s build/web/main.dart.js
    test -s build/web/flutter_bootstrap.js
    cp -a build/web/. /export/
  ' || { mark FLUTTER_RELEASE_BUILD FAIL; exit 6; }
[[ -s "$work/web/index.html" && -s "$work/web/main.dart.js" ]] || {
  mark FLUTTER_RELEASE_ARTIFACT FAIL; exit 6;
}
mark FLUTTER_RELEASE_BUILD PASS
# Nginx serves the actual candidate artifacts on the same isolated network.
D run -d --name "$web" --network "$net" --network-alias d1w-web \
  --security-opt no-new-privileges --pids-limit 128 --memory 256m \
  -v "$work/web:/usr/share/nginx/html:ro" nginx:1.27-alpine >/dev/null
web_created=YES
mark NGINX_WEB_CONTAINER_STARTED YES
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
  -keyout "$work/lab.key" -out "$work/lab.pem" \
  -subj '/CN=d1w-proxy' -addext 'subjectAltName=DNS:d1w-proxy' \
  >/dev/null 2>&1
chmod 644 "$work/lab.pem" "$work/lab.key"
cat > "$work/Caddyfile" <<'CADDY'
d1w-proxy {
  tls /etc/caddy/lab.pem /etc/caddy/lab.key
  @django path /api/* /accounts/* /admin/*
  handle @django {
    reverse_proxy d1w-api:8000
  }
  handle {
    reverse_proxy d1w-web:80
  }
}
CADDY
chmod 644 "$work/Caddyfile"
D run -d --name "$proxy" --network "$net" --network-alias d1w-proxy \
  --security-opt no-new-privileges --pids-limit 256 --memory 512m \
  -v "$work/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v "$work/lab.pem:/etc/caddy/lab.pem:ro" \
  -v "$work/lab.key:/etc/caddy/lab.key:ro" \
  caddy:2.11.7 >/dev/null
proxy_created=YES
D exec "$proxy" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || {
  mark CADDY_LAB_CONFIG_VALID FAIL
  exit 6
}
mark CADDY_LAB_CONFIG_VALID PASS
for service in "$api" "$proxy" "$web"; do
  [[ "$(D inspect -f '{{.HostConfig.PortBindings}}' "$service")" == 'map[]' ]] || {
    mark NO_HOST_PORTS FAIL; exit 6;
  }
done
mark NO_HOST_PORTS PASS
started=NO
for _ in $(seq 1 35); do
  [[ "$(D inspect -f '{{.State.Running}}' "$proxy" 2>/dev/null || true)" == true ]] || {
    mark CADDY_PROCESS_RUNNING FAIL; exit 6;
  }
  [[ "$(D inspect -f '{{.State.Running}}' "$api" 2>/dev/null || true)" == true ]] || {
    mark GUNICORN_PROCESS_RUNNING FAIL; exit 6;
  }
  [[ "$(D inspect -f '{{.State.Running}}' "$web" 2>/dev/null || true)" == true ]] || {
    mark NGINX_PROCESS_RUNNING FAIL; exit 6;
  }
  if D run --rm --network "$net" --security-opt no-new-privileges "$img" \
    python -c 'import socket; socket.create_connection(("d1w-proxy",443),2).close()' >/dev/null 2>&1; then
    started=YES; break
  fi
  sleep 1
done
[[ "$started" == YES ]] || { mark CADDY_SOCKET_READY FAIL; exit 7; }
mark CADDY_SOCKET_READY PASS
# Only one full request contract run after socket readiness.
D run --rm --network "$net" --security-opt no-new-privileges \
  -v "$root/scripts/main_d1w_caddy_candidate_probe.py:/opt/probe.py:ro" \
  -v "$work/lab.pem:/opt/lab.pem:ro" "$img" \
  python /opt/probe.py --cert /opt/lab.pem || {
    mark CADDY_HTTPS_PROBE FAIL
    exit 7
  }
mark CADDY_HTTPS_PROBE PASS
mark CADDY_PROXY_CANDIDATE_LAB PASS
# Recovery exercise in a dedicated synthetic schema, never in DEV and never
# against existing reminders/authorized business tables.
D exec "$db" psql -U d1w -d d1w -v ON_ERROR_STOP=1 \
  -c "CREATE SCHEMA d1w_rollback_fixture; CREATE TABLE d1w_rollback_fixture.marker (id integer PRIMARY KEY, state text NOT NULL); INSERT INTO d1w_rollback_fixture.marker VALUES (1, 'before');" >/dev/null || {
  mark SYNTHETIC_ROLLBACK_FIXTURE FAIL; exit 8;
}
D exec "$db" pg_dump -U d1w -d d1w -Fc \
  --schema=d1w_rollback_fixture -f /tmp/d1w-rollback.dump >/dev/null || {
  mark SYNTHETIC_BACKUP FAIL; exit 8;
}
D exec "$db" psql -U d1w -d d1w -v ON_ERROR_STOP=1 \
  -c "UPDATE d1w_rollback_fixture.marker SET state='after'; DROP SCHEMA d1w_rollback_fixture CASCADE;" >/dev/null 2>&1 || {
  mark SYNTHETIC_MUTATION FAIL; exit 8;
}
D exec "$db" pg_restore -U d1w -d d1w --exit-on-error /tmp/d1w-rollback.dump >/dev/null || {
  mark SYNTHETIC_SCHEMA_RESTORE FAIL; exit 8;
}
recovered="$(D exec "$db" psql -U d1w -d d1w -At -v ON_ERROR_STOP=1 -c "SELECT state FROM d1w_rollback_fixture.marker WHERE id=1;")"
[[ "$recovered" == before ]] || { mark SYNTHETIC_SCHEMA_RESTORE FAIL; exit 8; }
mark SYNTHETIC_SCHEMA_BACKUP_RESTORE PASS
mark OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED NO
mark FLUTTER_ARTIFACT_BEHIND_CADDY_TESTED YES
mark CADDY_PRODUCTION_CONFIG_VERIFIED NO
mark ROLLBACK_EXECUTED NO
mark ROLLBACK_VERIFIED NO
mark PROXY_AND_BACKEND_GATE PASS
