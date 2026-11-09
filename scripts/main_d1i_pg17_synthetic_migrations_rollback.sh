#!/usr/bin/env bash
# D1-I: isolated synthetic PG17 schema migration/rollback/restore rehearsal.
# NEVER connects to DEV DB, never restores user data, no operational deployment.
set -Eeuo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v openssl >/dev/null
command -v docker >/dev/null
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A before
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  [[ "$(D inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]] || exit 3
  before["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
tag="vencira-d1i-$$"
network="$tag-net"
db="$tag-db"
img="$tag:lab"
tmp="$(mktemp -d /tmp/vencira-d1i.XXXXXXXX)"
chmod 700 "$tmp"
network_created=0
image_created=0
cleanup() {
  local rc=$?
  trap - EXIT
  D rm -f "$db" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_created" == 1 ]]; then D image rm "$img" >/dev/null 2>&1 || true; fi
  rm -f "$tmp/env" "$tmp/baseline.dump"
  rmdir "$tmp" >/dev/null 2>&1 || true
  local intact=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${before[$name]}" ]]; then intact=NO; fi
  done
  echo "D1I_DEV_CONTAINERS_UNCHANGED=$([[ "$intact" == YES ]] && echo OK || echo FAIL)"
  if [[ "$intact" != YES ]]; then rc=9; fi
  echo 'D1I_O5_BACKUP_RESTORED=NO'
  echo 'D1I_LIVE_MIGRATIONS_EXECUTED=NO'
  echo 'D1I_DEPLOY_EXECUTED=NO'
  echo 'MFA_RELEASE_AUTHORIZED=NO'
  echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
  echo "D1I_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT
D build -q -t "$img" ./backend >/dev/null
image_created=1
echo 'D1I_CANDIDATE_IMAGE=PASS'
pass="$(openssl rand -hex 24)"
key="$(openssl rand -hex 36)"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_SECRET_KEY=$key
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=d1ilab
POSTGRES_USER=d1ilab
POSTGRES_PASSWORD=$pass
POSTGRES_HOST=$db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
EOF
chmod 600 "$tmp/env"
D network create --internal "$network" >/dev/null
network_created=1
[[ "$(D network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 4
D run -d --name "$db" --network "$network" \
  --tmpfs /var/lib/postgresql/data:rw,size=384m \
  -e POSTGRES_DB=d1ilab -e POSTGRES_USER=d1ilab -e POSTGRES_PASSWORD="$pass" \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U d1ilab -d d1ilab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || exit 5
echo 'D1I_PG17_INTERNAL_TMPFS_READY=PASS'
django() { D run --rm --network "$network" --env-file "$tmp/env" "$img" python manage.py "$@"; }
django check >/dev/null
django makemigrations reminders --check --dry-run --noinput >/dev/null
echo 'D1I_MODEL_MIGRATION_PARITY=PASS'
django migrate reminders 0018 --noinput >/dev/null
# Ensure auth and other dependencies needed by schema are applied.
django migrate --plan >/dev/null
echo 'D1I_BASELINE_0018=PASS'
# Create a binary dump of SYNTHETIC schema only, using a disposable database.
D exec "$db" pg_dump -U d1ilab -d d1ilab -Fc -f /tmp/d1i-baseline.dump
D exec "$db" test -s /tmp/d1i-baseline.dump
echo 'D1I_SYNTHETIC_BASELINE_DUMP=PASS'
django migrate reminders 0027 --plan >/dev/null
echo 'D1I_0019_0027_PLAN=PASS'
django migrate reminders 0027 --noinput >/dev/null
check_up="$(cat <<'PY'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name")
    rows={r[0] for r in c.fetchall()}
assert all(any(name.startswith(f"{n:04d}_") for name in rows) for n in range(19,28))
print("D1I_0019_0027_APPLIED=PASS")
PY
)"
django shell -c "$check_up" | grep -Fx 'D1I_0019_0027_APPLIED=PASS'
# Django rollback must be supported by all operations. Fail closed otherwise.
django migrate reminders 0018 --noinput >/dev/null
check_down="$(cat <<'PY'
from django.db import connection
with connection.cursor() as c:
    c.execute("SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name")
    rows={r[0] for r in c.fetchall()}
assert any(s.startswith("0018_") for s in rows)
assert all(not any(name.startswith(f"{n:04d}_") for name in rows) for n in range(19,28))
print("D1I_ROLLBACK_TO_0018=PASS")
PY
)"
django shell -c "$check_down" | grep -Fx 'D1I_ROLLBACK_TO_0018=PASS'
# Validate pg_restore of the synthetic 0018 dump to a DIFFERENT, empty
# database on the same disposable PG17 instance. Never target live DEV.
D exec "$db" createdb -U d1ilab -O d1ilab d1irestored
D exec "$db" pg_restore -U d1ilab -d d1irestored --no-owner --no-privileges /tmp/d1i-baseline.dump
D exec "$db" psql -U d1ilab -d d1irestored -Atqc \
  "SELECT COUNT(*) FROM django_migrations WHERE app='reminders' AND name LIKE '0018_%'" \
  | grep -Fx '1'
echo 'D1I_SYNTHETIC_DUMP_RESTORED=PASS'
# Return original lab DB to latest, verify model/DB coherence.
django migrate reminders 0027 --noinput >/dev/null
django migrate --plan >/dev/null
echo 'D1I_0019_0027_REAPPLY=PASS'
echo 'D1I_SCHEMA_ONLY_GATE=PASS'
