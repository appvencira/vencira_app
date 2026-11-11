#!/usr/bin/env bash
# D14: real O5 snapshot into disposable PG17 with retained host image IDs.
# No persistent mounts, no DEV DB access, no host Docker image loading.
# Privileged operator MUST review this script before running with sudo.
set -Eeuo pipefail
set +x
umask 077

mark(){ printf 'D14_%s=%s\n' "$1" "$2"; }
mark READ_ONLY_SOURCE_REPOSITORY YES
mark ARCHIVED_IMAGES_HOST_DOCKER_RELOADED NO
mark CONTAINER_RUN_EXECUTED NO
mark BACKUP_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark DEPLOY_EXECUTED NO
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'

if [[ "$(id -u)" != 0 ]]; then mark ROOT_REQUIRED YES; exit 2; fi
for tool in restic rclone docker openssl python3 stat sha256sum; do
  if ! command -v "$tool" >/dev/null; then mark PREREQUISITE_MISSING YES; exit 2; fi
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$root/backend/Dockerfile" ]]; then
  mark CHECKOUT_UNEXPECTED YES; exit 2
fi
archive_root="${1:-}"
[[ "$archive_root" == /* && -d "$archive_root" && ! -L "$archive_root" ]] || { mark ARCHIVE_PATH FAIL; exit 2; }
[[ -f "$archive_root/images.manifest" && ! -L "$archive_root/images.manifest" ]] || { mark ARCHIVE_MANIFEST FAIL; exit 2; }
(cd "$archive_root" && sha256sum --status -c images.tar.gz.sha256) || { mark ARCHIVE_CHECKSUM FAIL; exit 2; }
mark ARCHIVE_CHECKSUM PASS
declare -A image_ids=()
while IFS='=' read -r role imgid; do
  [[ "$role" == api || "$role" == db || "$role" == web ]] || { mark ARCHIVE_MANIFEST FAIL; exit 2; }
  [[ -z "${image_ids[$role]:-}" && "$imgid" =~ ^sha256:[a-f0-9]{64}$ ]] || { mark ARCHIVE_MANIFEST FAIL; exit 2; }
  image_ids[$role]="$imgid"
done < "$archive_root/images.manifest"
[[ "${#image_ids[@]}" -eq 3 ]] || { mark ARCHIVE_MANIFEST FAIL; exit 2; }
mark ARCHIVE_MANIFEST PASS
mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
# The retained image supports the historical 0018 baseline, not 0027.
# Verify this BEFORE O5 access, with no network, no mounts and no writes.
if docker run --rm --pull never --network none --read-only \
    --security-opt no-new-privileges --pids-limit 32 --memory 128m \
    --entrypoint python "${image_ids[api]}" -c '
from pathlib import Path
from re import fullmatch
p=Path("/app/reminders/migrations")
has18=any(fullmatch(r"0018_[A-Za-z0-9_]+\\.py", x.name) for x in p.glob("0018_*.py"))
has27=any(fullmatch(r"0027_[A-Za-z0-9_]+\\.py", x.name) for x in p.glob("0027_*.py"))
raise SystemExit(0 if has18 and not has27 else 1)
' >/dev/null 2>&1; then
  mark HISTORICAL_API_0018_ONLY PASS
else
  mark HISTORICAL_API_0018_ONLY FAIL
  mark O5_CREDENTIALS_ACCESSED NO
  mark REAL_O5_RESTORE_EXECUTED NO
  mark RESULT 8
  exit 8
fi
cfgdir=/etc/vencira-backup
cfg="$cfgdir/config.env"
for p in "$cfgdir" "$cfg"; do
  if [[ -L "$p" || ! -e "$p" ]]; then mark CONFIG_SECURE NO; exit 2; fi
done
if [[ "$(stat -c '%u:%a' "$cfgdir")" != '0:700' ||
      "$(stat -c '%u:%a' "$cfg")" != '0:600' ]]; then
  mark CONFIG_SECURE NO; exit 2
fi
set -a
# shellcheck disable=SC1091
source "$cfg"
set +a
if [[ "${RESTIC_REPOSITORY:-}" != 'rclone:vencira_google:VENCIRA-Backups/PostgreSQL' ||
      "${RESTIC_PASSWORD_FILE:-}" != '/etc/vencira-backup/restic-password' ||
      "${RCLONE_CONFIG:-}" != '/etc/vencira-backup/rclone.conf' ||
      -n "${RESTIC_PASSWORD:-}" ]]; then
  mark CONFIG_MATCH NO; exit 2
fi
for p in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  if [[ -L "$p" || ! -s "$p" || "$(stat -c '%u:%a' "$p")" != '0:600' ]]; then
    mark CREDENTIAL_FILE_PERMISSIONS NO; exit 2
  fi
done
mark CONFIG_MATCH PASS

# Verify live service identity without using it as an input or destination.
declare -A dev_id
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  if [[ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" != 'vencira_localcheck' ]]; then
    mark DEV_IDENTITY FAIL; exit 3
  fi
  dev_id["$name"]="$(docker inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
for role in api db web; do
  case "$role" in
    api) svc=vencira_localcheck-api-1;;
    db) svc=vencira_localcheck-db-1;;
    web) svc=vencira_localcheck-web_preview-1;;
  esac
  [[ "${dev_id[$svc]#*:}" == "${image_ids[$role]}" ]] || { mark HOST_IMAGE_IDENTITY FAIL; exit 3; }
done
mark HOST_IMAGE_IDENTITY PASS

lab="vencira-d14-$(openssl rand -hex 8)"
network="$lab-net"
network_created=NO
tmp="$(mktemp -d /tmp/vencira-d14.XXXXXXXX)"
chmod 700 "$tmp"
db_user=d14restore
db_name=d14restore
password="$(openssl rand -hex 24)"
created=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$created" == YES ]]; then
    docker rm -f "$lab" >/dev/null 2>&1 || rc=9
  fi
  if [[ "$network_created" == YES ]]; then
    docker network rm "$network" >/dev/null 2>&1 || rc=9
  fi
  rm -f "$tmp/env"
  rmdir "$tmp" >/dev/null 2>&1 || rc=9
  local intact=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(docker inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${dev_id[$name]}" ]]; then
      intact=NO
    fi
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$intact" == YES ]] && echo OK || echo FAIL)"
  if [[ "$intact" != YES ]]; then rc=9; fi
  mark LAB_CONTAINER_REMOVED "$([[ "$created" == YES ]] && echo YES || echo NOT_CREATED)"
  mark CONTAINER_RUN_EXECUTED "$([[ "$created" == YES ]] && echo YES || echo NO)"
  mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
  mark REAL_O5_DATA_OUTPUT_PRINTED NO
  mark LIVE_RESTORE_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark DEPLOY_EXECUTED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT

# Select the newest *matching* O5 PostgreSQL dump metadata. Snapshot IDs
# remain private and are not printed. Reject stale, ambiguous or malformed
# metadata; never use arbitrary 'latest' from a different backup family.
selector='
import datetime, json, re, sys
records=json.load(sys.stdin)
now=datetime.datetime.now(datetime.timezone.utc)
valid=[]
for x in records:
    if not isinstance(x,dict): continue
    ident=x.get("id","")
    if not isinstance(ident,str) or not re.fullmatch("[0-9a-f]{64}",ident): continue
    if "vencira-postgresql" not in x.get("tags",[]): continue
    if not any(isinstance(p,str) and p.rsplit("/",1)[-1]=="vencira-postgres.dump"
               for p in x.get("paths",[])): continue
    try: when=datetime.datetime.fromisoformat(x["time"].replace("Z","+00:00"))
    except (KeyError,TypeError,ValueError,AttributeError): continue
    if when.tzinfo is None or when>now+datetime.timedelta(minutes=10): continue
    valid.append((when,ident))
if not valid: sys.exit(21)
valid.sort(reverse=True)
if now-valid[0][0]>datetime.timedelta(hours=48): sys.exit(22)
print(valid[0][1])
'
snapshot="$(restic --no-lock snapshots --tag vencira-postgresql --json 2>/dev/null | python3 -c "$selector")" || {
  mark RECENT_POSTGRESQL_SNAPSHOT NO; exit 4;
}
mark RECENT_POSTGRESQL_SNAPSHOT PASS

# Dedicated internal Docker network; no connection to the DEV stack.
docker network create --internal "$network" >/dev/null
network_created=YES
[[ "$(docker network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 5
mark LAB_NETWORK_INTERNAL PASS
# Only tmpfs PGDATA, no persistent volumes or host bind mounts.
docker run -d --name "$lab" \
  --network "$network" --security-opt no-new-privileges --pids-limit 256 \
  --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=256m,mode=1777 \
  -e POSTGRES_DB="$db_name" -e POSTGRES_USER="$db_user" \
  -e POSTGRES_PASSWORD="$password" \
  "${image_ids[db]}" >/dev/null
created=YES
if [[ "$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$lab")" != "$network" ]]; then
  mark PG17_NETWORK_ISOLATED NO; exit 5
fi
if [[ -n "$(docker inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "$lab")" ]]; then
  mark PG17_PERSISTENT_MOUNT_PRESENT YES; exit 5
fi
ready=NO
for _ in $(seq 1 60); do
  if docker exec "$lab" pg_isready -U "$db_user" -d "$db_name" >/dev/null 2>&1; then
    ready=YES; break
  fi
  sleep 1
done
if [[ "$ready" != YES ]]; then mark PG17_READY FAIL; exit 5; fi
mark PG17_NETWORK_ISOLATED PASS
mark PG17_TMPFS_READY PASS

# Stream decrypted data directly into disposable PostgreSQL. No plaintext
# dump files. pipefail catches Restic and pg_restore failures. Suppress both
# commands' raw errors: names/paths inside them may be private.
if ! restic --no-lock dump "$snapshot" /vencira-postgres.dump 2>/dev/null |
     docker exec -i "$lab" pg_restore -U "$db_user" -d "$db_name" \
       --no-owner --no-privileges --exit-on-error >/dev/null 2>&1; then
  mark RESTORE_REAL_O5_PG17 FAIL; exit 6
fi
mark RESTORE_REAL_O5_PG17 PASS

# Report only a boolean for historical migration baseline, not user data.
# This intentionally stops BEFORE migrations on actual recovered data.
sql="SELECT CASE WHEN EXISTS (SELECT 1 FROM django_migrations WHERE app='reminders' AND name LIKE '0018_%') THEN 'PASS' ELSE 'FAIL' END;"
baseline="$(docker exec "$lab" psql -U "$db_user" -d "$db_name" -Atqc "$sql" 2>/dev/null)" || {
  mark HISTORICAL_0018 FAIL; exit 7;
}
if [[ "$baseline" != PASS ]]; then mark HISTORICAL_0018 FAIL; exit 7; fi
mark HISTORICAL_0018 PASS
mark BACKUP_PAYLOAD_PG_RESTORE_VERIFIED YES
mark REAL_BACKUP_RESTORED PASS

mark RETAINED_DJANGO_IMAGE_SELECTED PASS
key="$(openssl rand -hex 32)"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_SECRET_KEY=$key
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=$db_name
POSTGRES_USER=$db_user
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$lab
VENCIRA_MFA_ENROLLMENT_ENABLED=0
EOF
chmod 600 "$tmp/env"
django() {
  docker run --rm --network "$network" --env-file "$tmp/env" \
    --security-opt no-new-privileges "${image_ids[api]}" python manage.py "$@"
}
# Three stable entity counts remain in local variables and are never printed.
counts() {
  docker exec "$lab" psql -U "$db_user" -d "$db_name" -Atq \
    -v ON_ERROR_STOP=1 -c \
    "SELECT (SELECT count(*) FROM auth_user)::text || ':' ||
      (SELECT count(*) FROM reminders_workspace)::text || ':' ||
      (SELECT count(*) FROM reminders_renewal)::text;" 2>/dev/null
}
before_counts="$(counts)" || { mark BASELINE_COUNTS FAIL; exit 8; }
[[ "$before_counts" =~ ^[0-9]+:[0-9]+:[0-9]+$ ]] || {
  mark BASELINE_COUNTS FAIL; exit 8
}
mark BASELINE_COUNTS PASS
if ! django check >/dev/null 2>&1 ||
   ! django makemigrations reminders --check --dry-run --noinput >/dev/null 2>&1; then
  mark MODEL_MIGRATION_PARITY FAIL; exit 8
fi
mark MODEL_MIGRATION_PARITY PASS
# The historical API must ONLY plan its own existing 0018 target.
# Do not run migrations 0019-0027 using this image.
if ! django migrate reminders 0018 --plan >/dev/null 2>&1; then
  mark HISTORICAL_0018_MIGRATION_PLAN FAIL
  exit 8
fi
mark HISTORICAL_0018_MIGRATION_PLAN PASS
# Make sure the recovered snapshot remains at the historical schema.
historical_sql="SELECT CASE WHEN
 EXISTS(SELECT 1 FROM django_migrations WHERE app='reminders'
        AND name LIKE '0018_%')
 AND NOT EXISTS(SELECT 1 FROM django_migrations WHERE app='reminders'
        AND substring(name from 1 for 4) ~ '^[0-9]{4}$'
        AND substring(name from 1 for 4)::integer BETWEEN 19 AND 27)
 THEN 'PASS' ELSE 'FAIL' END;"
historical="$(docker exec "$lab" psql -U "$db_user" -d "$db_name" -Atq -v ON_ERROR_STOP=1 -c "$historical_sql" 2>/dev/null)" || {
  mark HISTORICAL_MIGRATION_SET FAIL; exit 8
}
[[ "$historical" == PASS ]] || { mark HISTORICAL_MIGRATION_SET FAIL; exit 8; }
mark HISTORICAL_MIGRATION_SET PASS
[[ "$(counts)" == "$before_counts" ]] || { mark CORE_COUNTS_UNCHANGED FAIL; exit 9; }
mark CORE_COUNTS_UNCHANGED PASS
mark REAL_DATA_CONTENT_PRINTED NO
mark HISTORICAL_API_O5_COMPATIBILITY PASS
mark HOST_RETAINED_PG17_API_REAL_O5_LAB PASS
mark ARCHIVE_EXPORTED_IMAGES_USED NO
mark ARCHIVE_EXPORT_EXECUTABLE_EQUIVALENCE_VERIFIED NO
mark OFF_HOST_COPY_VERIFIED YES_PREVIOUS_D12
mark WEB_REVERSE_PROXY_WITH_REAL_O5_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
