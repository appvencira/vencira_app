#!/usr/bin/env bash
# D2-A: true isolated Caddy TLS reverse proxy -> Gunicorn Django -> PG17 tmpfs.
# Does NOT use operational Caddy, DEV credentials, DEV volumes or host ports.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D2A_%s=%s\n' "$1" "$2"; }
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
ast.parse(Path("scripts/main_d2a_flutter_caddy_probe.py").read_text())
print("D2A_PROBE_SYNTAX=PASS")
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
net="vencira-d2a-$nonce-net"
db="vencira-d2a-$nonce-db"
api="vencira-d2a-$nonce-api"
proxy="vencira-d2a-$nonce-proxy"
web="vencira-d2a-$nonce-web"
img="vencira-d2a-$nonce-django"
browser_img="vencira-d2a-$nonce-chromium"
work="$(mktemp -d /tmp/vencira-d2a.XXXXXXXX)"
chmod 700 "$work"
network_created=NO
db_created=NO
api_created=NO
proxy_created=NO
web_created=NO
image_created=NO
browser_image_created=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$proxy_created" == YES ]]; then D rm -f "$proxy" >/dev/null 2>&1 || rc=9; fi
  if [[ "$web_created" == YES ]]; then D rm -f "$web" >/dev/null 2>&1 || rc=9; fi
  if [[ "$api_created" == YES ]]; then D rm -f "$api" >/dev/null 2>&1 || rc=9; fi
  if [[ "$db_created" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$network_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  if [[ "$image_created" == YES ]]; then D image rm "$img" >/dev/null 2>&1 || rc=9; fi
  if [[ "$browser_image_created" == YES ]]; then D image rm "$browser_img" >/dev/null 2>&1 || rc=9; fi
  rm -f "$work"/env "$work"/lab.pem "$work"/lab.key "$work"/Caddyfile || rc=9
  # Flutter build containers may export root-owned assets. Remove those from
  # a disposable root container, mounting ONLY this mktemp web subdirectory.
  if [[ -d "$work/web" && ! -L "$work/web" && "$work" == /tmp/vencira-d2a.* ]]; then
    D run --rm --network none --user 0 --security-opt no-new-privileges \
      --entrypoint sh -v "$work/web:/cleanup" nginx:1.27-alpine \
      -c 'rm -rf /cleanup/* /cleanup/.[!.]* /cleanup/..?*' >/dev/null 2>&1 || rc=9
    rmdir "$work/web" >/dev/null 2>&1 || rc=9
  else
    rc=9
  fi
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
D run -d --name "$db" --network "$net" --network-alias d2a-db \
  --security-opt no-new-privileges --pids-limit 256 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB=d2a -e POSTGRES_USER=d2a -e POSTGRES_PASSWORD="$secret" \
  postgres:17-alpine >/dev/null
db_created=YES
ready=NO
for _ in $(seq 1 60); do
  if D exec "$db" pg_isready -U d2a -d d2a >/dev/null 2>&1; then ready=YES; break; fi
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
DJANGO_ALLOWED_HOSTS=d2a-proxy,localhost,testserver
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d2a
POSTGRES_USER=d2a
POSTGRES_PASSWORD=$secret
POSTGRES_HOST=d2a-db
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
D run -d --name "$api" --network "$net" --network-alias d2a-api \
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
    test -s build/web/canvaskit/canvaskit.js
    test -s build/web/canvaskit/canvaskit.wasm
    grep -Fq "canvasKitBaseUrl" build/web/flutter_bootstrap.js
    grep -Fq "/canvaskit/" build/web/flutter_bootstrap.js
    cp -a build/web/. /export/
  ' || { mark FLUTTER_RELEASE_BUILD FAIL; exit 6; }
[[ -s "$work/web/index.html" && -s "$work/web/main.dart.js" ]] || {
  mark FLUTTER_RELEASE_ARTIFACT FAIL; exit 6;
}
mark FLUTTER_RELEASE_BUILD PASS
mark LOCAL_CANVASKIT_BUNDLED PASS
mark BOOTSTRAP_LOCAL_CANVASKIT_CONFIG PASS
# Nginx serves the actual candidate artifacts on the same isolated network.
D run -d --name "$web" --network "$net" --network-alias d2a-web \
  --security-opt no-new-privileges --pids-limit 128 --memory 256m \
  -v "$work/web:/usr/share/nginx/html:ro" nginx:1.27-alpine >/dev/null
web_created=YES
mark NGINX_WEB_CONTAINER_STARTED YES
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
  -keyout "$work/lab.key" -out "$work/lab.pem" \
  -subj '/CN=d2a-proxy' -addext 'subjectAltName=DNS:d2a-proxy' \
  >/dev/null 2>&1
chmod 644 "$work/lab.pem" "$work/lab.key"
cat > "$work/Caddyfile" <<'CADDY'
d2a-proxy {
  tls /etc/caddy/lab.pem /etc/caddy/lab.key
  @django path /api/* /accounts/* /admin/*
  handle @django {
    reverse_proxy d2a-api:8000
  }
  handle {
    reverse_proxy d2a-web:80
  }
}
CADDY
chmod 644 "$work/Caddyfile"
D run -d --name "$proxy" --network "$net" --network-alias d2a-proxy \
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
    python -c 'import socket; socket.create_connection(("d2a-proxy",443),2).close()' >/dev/null 2>&1; then
    started=YES; break
  fi
  sleep 1
done
[[ "$started" == YES ]] || { mark CADDY_SOCKET_READY FAIL; exit 7; }
mark CADDY_SOCKET_READY PASS
# Only one full request contract run after socket readiness.
D run --rm --network "$net" --security-opt no-new-privileges \
  -v "$root/scripts/main_d2a_flutter_caddy_probe.py:/opt/probe.py:ro" \
  -v "$work/lab.pem:/opt/lab.pem:ro" "$img" \
  python /opt/probe.py --cert /opt/lab.pem || {
    mark CADDY_HTTPS_PROBE FAIL
    exit 7
  }
mark CADDY_HTTPS_PROBE PASS
mark CADDY_PROXY_CANDIDATE_LAB PASS
# Playwright/Chromium image is built before use in the internal-only network.
# The runner sees NO Django credentials, database connection or host ports.
D build -q -t "$browser_img" -f "$root/scripts/Dockerfile.d2a-playwright" \
  "$root/scripts" >/dev/null || { mark CHROMIUM_IMAGE_BUILD FAIL; exit 8; }
browser_image_created=YES
mark CHROMIUM_IMAGE_BUILD PASS
D run --rm --network none --security-opt no-new-privileges \
  -v "$root/scripts/main_d2a_chromium_visual_smoke.js:/opt/d2a/smoke.js:ro" \
  "$browser_img" node --check /opt/d2a/smoke.js >/dev/null || {
    mark CHROMIUM_SMOKE_SYNTAX FAIL; exit 8;
  }
mark CHROMIUM_SMOKE_SYNTAX PASS
D run --rm --network "$net" --security-opt no-new-privileges \
  --pids-limit 512 --memory 2g --shm-size=512m \
  -v "$root/scripts/main_d2a_chromium_visual_smoke.js:/opt/d2a/smoke.js:ro" \
  "$browser_img" node /opt/d2a/smoke.js || {
  mark CHROMIUM_RENDER_GATE FAIL
  exit 8
}
mark CHROMIUM_RENDER_GATE PASS
# Simulate availability loss and recovery by recreating ONLY the disposable
# Nginx lab container with the SAME immutable build/web assets.
D rm -f "$web" >/dev/null || { mark WEB_RECOVERY_RESTART FAIL; exit 9; }
web_created=NO
D run -d --name "$web" --network "$net" --network-alias d2a-web \
  --security-opt no-new-privileges --pids-limit 128 --memory 256m \
  -v "$work/web:/usr/share/nginx/html:ro" nginx:1.27-alpine >/dev/null || {
    mark WEB_RECOVERY_RESTART FAIL; exit 9;
  }
web_created=YES
ready_web=NO
for _ in $(seq 1 30); do
  if D run --rm --network "$net" --security-opt no-new-privileges "$img" \
    python -c 'import urllib.request; assert urllib.request.urlopen("http://d2a-web/",timeout=2).status==200' \
    >/dev/null 2>&1; then ready_web=YES; break; fi
  sleep 1
done
[[ "$ready_web" == YES ]] || { mark WEB_RECOVERY_RESTART FAIL; exit 9; }
mark WEB_RECOVERY_RESTART PASS
D run --rm --network "$net" --security-opt no-new-privileges \
  --pids-limit 512 --memory 2g --shm-size=512m \
  -v "$root/scripts/main_d2a_chromium_visual_smoke.js:/opt/d2a/smoke.js:ro" \
  "$browser_img" node /opt/d2a/smoke.js || {
  mark CHROMIUM_AFTER_WEB_RESTART FAIL; exit 9;
}
mark CHROMIUM_AFTER_WEB_RESTART PASS
# Recovery exercise in a dedicated synthetic schema, never in DEV and never
# against existing reminders/authorized business tables.
D exec "$db" psql -U d2a -d d2a -v ON_ERROR_STOP=1 \
  -c "CREATE SCHEMA d2a_rollback_fixture; CREATE TABLE d2a_rollback_fixture.marker (id integer PRIMARY KEY, state text NOT NULL); INSERT INTO d2a_rollback_fixture.marker VALUES (1, 'before');" >/dev/null || {
  mark SYNTHETIC_ROLLBACK_FIXTURE FAIL; exit 8;
}
D exec "$db" pg_dump -U d2a -d d2a -Fc \
  --schema=d2a_rollback_fixture -f /tmp/d2a-rollback.dump >/dev/null || {
  mark SYNTHETIC_BACKUP FAIL; exit 8;
}
D exec "$db" psql -U d2a -d d2a -v ON_ERROR_STOP=1 \
  -c "UPDATE d2a_rollback_fixture.marker SET state='after'; DROP SCHEMA d2a_rollback_fixture CASCADE;" >/dev/null 2>&1 || {
  mark SYNTHETIC_MUTATION FAIL; exit 8;
}
D exec "$db" pg_restore -U d2a -d d2a --exit-on-error /tmp/d2a-rollback.dump >/dev/null || {
  mark SYNTHETIC_SCHEMA_RESTORE FAIL; exit 8;
}
recovered="$(D exec "$db" psql -U d2a -d d2a -At -v ON_ERROR_STOP=1 -c "SELECT state FROM d2a_rollback_fixture.marker WHERE id=1;")"
[[ "$recovered" == before ]] || { mark SYNTHETIC_SCHEMA_RESTORE FAIL; exit 8; }
mark SYNTHETIC_SCHEMA_BACKUP_RESTORE PASS
mark OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED NO
mark FLUTTER_ARTIFACT_BEHIND_CADDY_TESTED YES
mark CADDY_PRODUCTION_CONFIG_VERIFIED NO
mark ROLLBACK_EXECUTED NO
mark ROLLBACK_VERIFIED NO
mark CHROMIUM_DESKTOP_MOBILE_VISUAL_AND_RECOVERY_GATE PASS
