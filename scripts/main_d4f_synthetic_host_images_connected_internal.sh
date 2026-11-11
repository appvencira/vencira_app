#!/usr/bin/env bash
# D4-F: connected, synthetic-only Docker lab using retained host image IDs.
# Does not load archived images into host Docker or access any DEV DB/volumes.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D4F_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for f in RELEASE_AUTHORIZED DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED OPERATIONAL_ROLLBACK_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED; do mark "$f" NO; done
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_OPERATOR FAIL; exit 2; }
for t in git openssl sudo docker sha256sum mktemp; do command -v "$t" >/dev/null || { mark PREREQUISITE "$t"; exit 2; }; done
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" && -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
archive_root="${1:-}"
[[ "$archive_root" == /* && -d "$archive_root" && ! -L "$archive_root" ]] || { mark ARCHIVE_PATH FAIL; exit 2; }
[[ "$(stat -c '%u:%a' "$archive_root")" == "$(id -u):700" ]] || { mark ARCHIVE_PERMISSIONS FAIL; exit 2; }
(cd "$archive_root" && sha256sum --status -c images.tar.gz.sha256) || { mark ARCHIVE_CHECKSUM FAIL; exit 3; }
mark ARCHIVE_CHECKSUM PASS
[[ -f "$archive_root/images.manifest" && ! -L "$archive_root/images.manifest" ]] || { mark MANIFEST FAIL; exit 3; }
declare -A image_ids=()
while IFS='=' read -r role image_id; do
  [[ "$role" == api || "$role" == db || "$role" == web ]] || { mark MANIFEST FAIL; exit 3; }
  [[ -z "${image_ids[$role]:-}" && "$image_id" =~ ^sha256:[a-f0-9]{64}$ ]] || { mark MANIFEST FAIL; exit 3; }
  image_ids[$role]="$image_id"
done <"$archive_root/images.manifest"
[[ "${#image_ids[@]}" -eq 3 ]] || { mark MANIFEST FAIL; exit 3; }
sudo -n true >/dev/null 2>&1 || { mark SUDO_SESSION REQUIRED; exit 2; }
D(){ sudo -n docker "$@"; }
declare -A before=()
for role in api db web; do
  case "$role" in
    api) svc=vencira_localcheck-api-1;;
    db) svc=vencira_localcheck-db-1;;
    web) svc=vencira_localcheck-web_preview-1;;
  esac
  before[$role]="$(D inspect -f '{{.Id}}:{{.Image}}' "$svc" 2>/dev/null)" || { mark LIVE_INSPECT FAIL; exit 3; }
  [[ "${before[$role]#*:}" == "${image_ids[$role]}" ]] || { mark LIVE_IMAGE_IDENTITY FAIL; exit 3; }
  [[ "$(D inspect -f '{{.State.Running}}' "$svc")" == true ]] || { mark LIVE_RUNNING FAIL; exit 3; }
done
mark LIVE_IMAGE_IDENTITY PASS
nonce="$(openssl rand -hex 8)"
net="vencira-d4f-$nonce-net"
db="vencira-d4f-$nonce-db"
api="vencira-d4f-$nonce-api"
web="vencira-d4f-$nonce-web"
work="$(mktemp -d /tmp/vencira-d4f.XXXXXXXX)"
chmod 700 "$work"
net_created=NO
created=()
cleanup(){
  rc=$?
  trap - EXIT
  for ((i=${#created[@]}-1;i>=0;i--)); do D rm -f "${created[$i]}" >/dev/null 2>&1 || rc=9; done
  if [[ "$net_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  [[ "$work" == /tmp/vencira-d4f.* && -d "$work" && ! -L "$work" ]] || { mark CLEANUP_PATH FAIL; exit 9; }
  rm -rf -- "$work" || rc=9
  intact=YES
  for role in api db web; do
    case "$role" in
      api) svc=vencira_localcheck-api-1;;
      db) svc=vencira_localcheck-db-1;;
      web) svc=vencira_localcheck-web_preview-1;;
    esac
    [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$svc" 2>/dev/null || true)" == "${before[$role]}" ]] || intact=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$intact"
  [[ "$intact" == YES ]] || rc=9
  mark EPHEMERAL_CLEANUP "$([[ "$rc" == 9 ]] && echo FAIL || echo DONE)"
  mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
  mark REAL_O5_COMPATIBILITY_VERIFIED NO
  mark ARCHIVE_CONFIG_HASH_EQUIVALENCE_VERIFIED NO
  mark OPERATIONAL_ROLLBACK_VERIFIED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D network create --internal "$net" >"$work/network.out" 2>"$work/network.err" || { mark INTERNAL_NETWORK FAIL; exit 4; }
net_created=YES
[[ "$(D network inspect -f '{{.Internal}}' "$net")" == true ]] || { mark INTERNAL_NETWORK FAIL; exit 4; }
mark INTERNAL_NETWORK PASS
password="$(openssl rand -hex 24)"
if ! D run -d --pull never --name "$db" --network "$net" --network-alias db \
  --security-opt no-new-privileges --pids-limit 192 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1024m,mode=1777 \
  --tmpfs /var/run/postgresql:rw,size=32m,mode=1777 \
  --tmpfs /tmp:rw,size=64m,mode=1777 \
  -e POSTGRES_DB=d4f_synthetic -e POSTGRES_USER=d4f_synthetic -e POSTGRES_PASSWORD="$password" \
  "${image_ids[db]}" >"$work/db.id" 2>"$work/db.err"; then mark PG17_START FAIL; exit 5; fi
created+=("$db")
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -q -U d4f_synthetic -d d4f_synthetic >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark PG17_READY FAIL; exit 5; }
mark PG17_READY PASS
cat >"$work/env" <<ENV
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
DJANGO_ALLOWED_HOSTS=api,localhost,127.0.0.1,web_preview
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d4f_synthetic
POSTGRES_USER=d4f_synthetic
POSTGRES_PASSWORD=$password
POSTGRES_HOST=db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
ENV
chmod 600 "$work/env"
if ! D run -d --pull never --name "$api" --network "$net" --network-alias api \
  --env-file "$work/env" --security-opt no-new-privileges --pids-limit 192 --memory 1g \
  "${image_ids[api]}" >"$work/api.id" 2>"$work/api.err"; then mark API_START FAIL; exit 6; fi
created+=("$api")
ready=NO
for _ in $(seq 1 35); do
  if D exec "$api" python -c 'import json,urllib.request; r=urllib.request.urlopen("http://127.0.0.1:8000/api/ready/",timeout=3); assert r.status==200 and json.load(r).get("status")=="ready"' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark DJANGO_PG17_READY_HTTP FAIL; exit 6; }
mark DJANGO_PG17_READY_HTTP PASS
if ! D run -d --pull never --name "$web" --network "$net" --network-alias web_preview \
  --security-opt no-new-privileges --pids-limit 128 --memory 384m \
  --tmpfs /tmp:rw,size=64m,mode=1777 \
  --tmpfs /var/cache/nginx:rw,size=64m,mode=1777 \
  --tmpfs /var/run:rw,size=16m,mode=1777 \
  "${image_ids[web]}" >"$work/web.id" 2>"$work/web.err"; then mark WEB_START FAIL; exit 7; fi
created+=("$web")
ready=NO
for _ in $(seq 1 35); do
  if D exec "$web" sh -c 'wget -q -O /dev/null -T 3 http://127.0.0.1:8080/' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark WEB_HTTP_8080 FAIL; exit 7; }
mark WEB_HTTP_8080 PASS
if D exec "$web" sh -c 'wget -q -O /dev/null -T 3 http://api:8000/api/health/' >/dev/null 2>&1; then
  mark WEB_TO_API_PRIVATE_HTTP PASS
else
  mark WEB_TO_API_PRIVATE_HTTP FAIL
  exit 7
fi
for cname in "$db" "$api" "$web"; do
  [[ "$(D inspect -f '{{.HostConfig.PortBindings}}' "$cname")" == 'map[]' ]] || { mark NO_HOST_PORTS FAIL; exit 8; }
done
mark NO_HOST_PORTS PASS
mark SYNTHETIC_PG17_DJANGO_WEB_INTERNAL_NETWORK PASS
mark WEB_REVERSE_PROXY_PATH_VERIFIED NO
mark ARCHIVED_IMAGES_HOST_DOCKER_RELOADED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
