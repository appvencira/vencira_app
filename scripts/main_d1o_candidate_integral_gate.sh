#!/usr/bin/env bash
# D1-O: candidate Django/PostgreSQL17 + HTTP security + Flutter web regression.
# No DEV compose up, no access to live database, no live migrations.
set -Eeuo pipefail
set +x
umask 077
mark() { printf 'D1O_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for tool in docker openssl git; do command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }; done
[[ "$(git branch --show-current)" == main ]] || { mark MAIN_REQUIRED FAIL; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }
command -v sudo >/dev/null || { mark SUDO_REQUIRED YES; exit 2; }
if [[ "$(id -u)" == 0 ]]; then
  D() { docker "$@"; }
else
  sudo -v
  D() { sudo docker "$@"; }
fi

declare -A dev_ids
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || { mark DEV_IDENTITY FAIL; exit 3; }
  dev_ids["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
nonce="$(openssl rand -hex 8)"
net="vencira-d1o-$nonce-net"
db="vencira-d1o-$nonce-db"
img="vencira-d1o-$nonce-django"
work="$(mktemp -d /tmp/vencira-d1o.XXXXXXXX)"
chmod 700 "$work"
net_created=NO
db_created=NO
img_created=NO
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ "$db_created" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$net_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  if [[ "$img_created" == YES ]]; then D image rm "$img" >/dev/null 2>&1 || rc=9; fi
  rm -f "$work/env"
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

# Deliberately no credentials or networks from DEV; internal synthetic PG17.
D network create --internal "$net" >/dev/null
net_created=YES
[[ "$(D network inspect -f '{{.Internal}}' "$net")" == true ]] || exit 4
mark INTERNAL_NETWORK PASS
password="$(openssl rand -hex 24)"
D run -d --name "$db" --network "$net" --security-opt no-new-privileges \
  --pids-limit 256 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB=d1o -e POSTGRES_USER=d1o -e POSTGRES_PASSWORD="$password" \
  postgres:17-alpine >/dev/null
db_created=YES
[[ "$(D inspect -f '{{.HostConfig.NetworkMode}}' "$db")" == "$net" ]] || exit 4
[[ -z "$(D inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "$db")" ]] || exit 4
ready=NO
for _ in $(seq 1 60); do
  if D exec "$db" pg_isready -U d1o -d d1o >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark PG17_READY FAIL; exit 4; }
mark PG17_SYNTHETIC_TMPFS PASS

D build -q -t "$img" "$root/backend" >/dev/null
img_created=YES
mark CANDIDATE_IMAGE_BUILD PASS
cat > "$work/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d1o
POSTGRES_USER=d1o
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
DJANGO_HTTPS_BEHIND_PROXY=1
EOF
chmod 600 "$work/env"
django() {
  D run --rm --network "$net" --env-file "$work/env" \
    --security-opt no-new-privileges --pids-limit 512 --memory 3g \
    "$img" python manage.py "$@"
}
django check --deploy >/dev/null 2>&1 || { mark DJANGO_DEPLOY_CHECK FAIL; exit 5; }
mark DJANGO_DEPLOY_CHECK PASS
django makemigrations --check --dry-run --noinput >/dev/null 2>&1 || { mark MODEL_PARITY FAIL; exit 5; }
mark MODEL_PARITY PASS
django migrate --noinput >/dev/null 2>&1 || { mark SYNTHETIC_MIGRATIONS FAIL; exit 5; }
mark SYNTHETIC_MIGRATIONS PASS

# These are real Django client/URL resolver checks against the synthetic database.
django test reminders.tests.test_d1o_release_contract --noinput --verbosity 1 >/dev/null 2>&1 || {
  mark SECURITY_HTTP_CONTRACT FAIL; exit 6;
}
mark SECURITY_HTTP_CONTRACT PASS
# Full reminders regression may reveal failures unrelated to the targeted contract.
django test reminders --noinput --verbosity 1 >/dev/null 2>&1 || {
  mark DJANGO_REMINDERS_SUITE FAIL; exit 6;
}
mark DJANGO_REMINDERS_SUITE PASS

# Flutter dependencies may require internet access, but no DEV mount, keys or env.
# Dart/Flutter run inside a disposable copy so the checkout stays clean.
D run --rm -v "$root/clients/flutter:/source:ro" \
  --tmpfs /tmp:rw,size=2g,mode=1777 --memory 4g \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
    cp -a /source /tmp/flutter-app
    cd /tmp/flutter-app
    flutter pub get >/dev/null
    flutter analyze >/dev/null
    flutter test --reporter compact >/dev/null
    flutter build web --release >/dev/null
    test -s build/web/index.html
    test -s build/web/main.dart.js
  ' || { mark FLUTTER_ANALYZE_TEST_WEB_BUILD FAIL; exit 7; }
mark FLUTTER_ANALYZE_TEST_WEB_BUILD PASS
mark COMPOSE_CADDY_RUNTIME_INSPECTION NOT_RUN
mark ANDROID_PHYSICAL NOT_RUN
mark MFA_NATIVE_PUBLIC_ENABLED NO
mark CANDIDATE_INTEGRAL_GATE PASS
