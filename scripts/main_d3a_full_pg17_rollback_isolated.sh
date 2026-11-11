#!/usr/bin/env bash
# D3-A: full synthetic PostgreSQL database restore + candidate Django runtime.
# Read-only preflight of DEV identities. No operational backup/restore/deploy.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D3A_%s=%s\n' "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
for utility in git docker openssl mktemp; do
  command -v "$utility" >/dev/null || { mark MISSING_TOOL "$utility"; exit 2; }
done
[[ "$(git branch --show-current)" == main ]] || { mark MAIN_REQUIRED FAIL; exit 2; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  mark MAIN_SYNC_REQUIRED FAIL; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }
mark MAIN_CLEAN_SYNC PASS
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  sudo -v
  D(){ sudo docker "$@"; }
fi
before="$(mktemp)"
after="$(mktemp)"
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service" 2>/dev/null)" == vencira_localcheck ]] || {
    mark DEV_IDENTITY FAIL; rm -f "$before" "$after"; exit 3;
  }
  D inspect -f '{{.Id}}:{{.Image}}' "$service" >> "$before"
done
mark DEV_IDENTITY PASS
nonce="$(openssl rand -hex 8)"
net="vencira-d3a-$nonce-net"
db="vencira-d3a-$nonce-db"
img="vencira-d3a-$nonce-django"
tmp="$(mktemp -d /tmp/vencira-d3a.XXXXXXXX)"
chmod 700 "$tmp"
network_created=NO
db_created=NO
img_created=NO
cleanup(){
  local rc=$?
  trap - EXIT
  if [[ "$db_created" == YES ]]; then D rm -f "$db" >/dev/null 2>&1 || rc=9; fi
  if [[ "$network_created" == YES ]]; then D network rm "$net" >/dev/null 2>&1 || rc=9; fi
  if [[ "$img_created" == YES ]]; then D image rm "$img" >/dev/null 2>&1 || rc=9; fi
  rm -f "$tmp/env" "$tmp/restore.log" || rc=9
  rmdir "$tmp" || rc=9
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    D inspect -f '{{.Id}}:{{.Image}}' "$service" >> "$after" 2>/dev/null || rc=9
  done
  if cmp -s "$before" "$after"; then
    mark DEV_CONTAINERS_UNCHANGED OK
  else
    mark DEV_CONTAINERS_UNCHANGED FAIL
    rc=9
  fi
  rm -f "$before" "$after"
  mark EPHEMERAL_CLEANUP "$([[ "$rc" == 9 ]] && echo FAIL || echo DONE)"
  mark DEPLOY_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark OPERATIONAL_IMAGE_ROLLBACK_VERIFIED NO
  mark PRODUCTION_CADDY_CONFIG_VERIFIED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D network create --internal "$net" >/dev/null
network_created=YES
[[ "$(D network inspect -f '{{.Internal}}' "$net")" == true ]] || exit 4
mark NETWORK_INTERNAL PASS
secret="$(openssl rand -hex 24)"
D run -d --name "$db" --network "$net" --network-alias d3a-db \
  --security-opt no-new-privileges --pids-limit 256 --memory 2g \
  --tmpfs /var/lib/postgresql/data:rw,size=1536m,mode=0700 \
  --tmpfs /tmp:rw,size=384m,mode=1777 \
  -e POSTGRES_DB=d3a -e POSTGRES_USER=d3a -e POSTGRES_PASSWORD="$secret" \
  postgres:17-alpine >/dev/null
db_created=YES
ready=NO
for i in $(seq 1 60); do
  if D exec "$db" pg_isready -U d3a -d d3a >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || { mark PG17_READY FAIL; exit 4; }
mark PG17_TMPFS PASS
D build -q -t "$img" "$root/backend" >/dev/null
img_created=YES
mark CANDIDATE_IMAGE PASS
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=d3a-db,localhost,testserver
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d3a
POSTGRES_USER=d3a
POSTGRES_PASSWORD=$secret
POSTGRES_HOST=d3a-db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
EOF
chmod 600 "$tmp/env"
django(){
  D run --rm --network "$net" --env-file "$tmp/env" \
    --network-alias d3a-runtime --security-opt no-new-privileges \
    --pids-limit 256 --memory 2g "$img" python manage.py "$@"
}
django check >/dev/null || { mark DJANGO_CHECK FAIL; exit 5; }
django makemigrations --check --dry-run --noinput >/dev/null 2>&1 || {
  mark MODEL_PARITY FAIL; exit 5;
}
django migrate --noinput >/dev/null 2>&1 || { mark INITIAL_MIGRATE FAIL; exit 5; }
mark CANDIDATE_MIGRATIONS PASS
synthetic_username="d2e-synthetic-$nonce"
synthetic_password="$(openssl rand -hex 20)"
D run --rm --network "$net" --env-file "$tmp/env" \
  -e D2E_SYNTHETIC_USER="$synthetic_username" \
  -e D2E_SYNTHETIC_PASSWORD="$synthetic_password" \
  -v "$root/scripts/main_d2e_seed_synthetic.py:/opt/d3a/seed.py:ro" \
  --security-opt no-new-privileges --pids-limit 256 --memory 2g \
  "$img" python manage.py shell -c 'exec(open("/opt/d3a/seed.py").read())' >/dev/null || {
  mark SYNTHETIC_SEED FAIL; exit 5;
}
mark SYNTHETIC_FIXTURE PASS
sql="SELECT notes FROM reminders_renewal WHERE customer_reference='D2E-EDIT';"
state="$(D exec "$db" psql -U d3a -d d3a -At -v ON_ERROR_STOP=1 -c "$sql")"
[[ "$state" == "Before D2E" ]] || { mark INITIAL_STATE FAIL; exit 6; }
mark INITIAL_STATE PASS
# A *full* custom-format backup, including auth, membership and renewal tables.
D exec "$db" pg_dump -U d3a -d d3a -Fc -f /tmp/d3a-full.dump
D exec "$db" pg_restore --list /tmp/d3a-full.dump >/dev/null
mark FULL_DATABASE_SNAPSHOT PASS
D exec "$db" psql -U d3a -d d3a -v ON_ERROR_STOP=1 \
  -c "UPDATE reminders_renewal SET notes='AFTER_SNAPSHOT' WHERE customer_reference='D2E-EDIT';" >/dev/null
[[ "$(D exec "$db" psql -U d3a -d d3a -At -c "$sql")" == AFTER_SNAPSHOT ]] || {
  mark FAULT_INJECTED FAIL; exit 6;
}
mark SYNTHETIC_FAULT_INJECTED PASS
# Restore into a fresh empty database. Never touch DEV or a persisted volume.
D exec "$db" dropdb -U d3a d3a
D exec "$db" createdb -U d3a -O d3a d3a
D exec "$db" pg_restore -U d3a -d d3a --exit-on-error /tmp/d3a-full.dump >"$tmp/restore.log" 2>&1 || {
  mark FULL_RESTORE FAIL; exit 7;
}
[[ "$(D exec "$db" psql -U d3a -d d3a -At -v ON_ERROR_STOP=1 -c "$sql")" == "Before D2E" ]] || {
  mark RENEWAL_ROLLBACK FAIL; exit 7;
}
mark RENEWAL_ROLLBACK PASS
auth_count="$(D exec "$db" psql -U d3a -d d3a -At -v ON_ERROR_STOP=1 \
  -c "SELECT COUNT(*) FROM auth_user WHERE username LIKE 'd2e-synthetic-%';")"
[[ "$auth_count" == 1 ]] || { mark AUTH_RESTORE FAIL; exit 7; }
mark AUTH_RESTORE PASS
member_count="$(D exec "$db" psql -U d3a -d d3a -At -v ON_ERROR_STOP=1 \
  -c 'SELECT COUNT(*) FROM reminders_workspacemember;')"
[[ "$member_count" == 1 ]] || { mark MEMBERSHIP_RESTORE FAIL; exit 7; }
mark MEMBERSHIP_RESTORE PASS
django check >/dev/null || { mark RESTORED_RUNTIME_CHECK FAIL; exit 7; }
django migrate --check --noinput >/dev/null 2>&1 || {
  mark RESTORED_MIGRATION_PARITY FAIL; exit 7;
}
mark RESTORED_DJANGO_RUNTIME PASS
mark FULL_SYNTHETIC_DB_ROLLBACK_GATE PASS
# This rehearses database recovery only. A real immutable image rollback,
# production Caddy configuration and operational recovery require separate proof.
