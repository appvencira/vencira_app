#!/usr/bin/env bash
# I8-K PG17: isolated recovery HTTP JSON with atomic revocation and regression.
# Test-only Django app. No operational URL, no live DB, no published port.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
for cmd in docker openssl; do command -v "$cmd" >/dev/null || exit 2; done
declare -A before
for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$s")" = vencira_localcheck || exit 3
  test "$(D inspect -f '{{.State.Health.Status}}' "$s")" = healthy || exit 3
  before[$s]="$(D inspect -f '{{.Id}}:{{.Image}}' "$s")"
done
tmp="$(mktemp -d /tmp/vencira-native-i8k.XXXXXXXX)"
chmod 700 "$tmp"
net="vencira-native-i8k-$$"
pg="vencira-native-i8k-pg-$$"
img="vencira-native-i8k-test:$$"
net_created=0
img_built=0
cleanup() {
  local rc=$?
  trap - EXIT
  D rm -f "$pg" >/dev/null 2>&1 || true
  if [[ "$net_created" == 1 ]]; then D network rm "$net" >/dev/null 2>&1 || true; fi
  if [[ "$img_built" == 1 ]]; then D image rm "$img" >/dev/null 2>&1 || true; fi
  rm -f "$tmp/env"
  rmdir "$tmp" || true
  local same=YES
  for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$s" 2>/dev/null || true)" != "${before[$s]}" ]]; then same=NO; fi
  done
  if [[ "$same" == YES ]]; then echo "NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK"; else
    echo "NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=FAIL"; rc=9
  fi
  echo "NATIVE_I8K_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8K_LOCAL_RESULT=$rc"
  exit "$rc"
}
trap cleanup EXIT

D build -q -t "$img" ./backend >/dev/null
img_built=1
echo "NATIVE_I8K_DISPOSABLE_IMAGE=OK"
dbpass="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
audit="$(openssl rand -hex 36)"
abuse="$(openssl rand -hex 36)"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=i8klab
POSTGRES_USER=i8klab
POSTGRES_PASSWORD=$dbpass
POSTGRES_HOST=$pg
VENCIRA_NATIVE_SERVICE_CANDIDATE=1
VENCIRA_I8D_HTTP_LAB=1
VENCIRA_NATIVE_BEARER_ENABLED=0
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_G5_AUDIT_KEY=$audit
VENCIRA_G5_ABUSE_KEY=$abuse
EOF
chmod 600 "$tmp/env"
D network create --internal "$net" >/dev/null
net_created=1
test "$(D network inspect -f '{{.Internal}}' "$net")" = true
echo "NATIVE_I8K_INTERNAL_NETWORK=OK"
D run --rm -d --name "$pg" --network "$net" \
  --tmpfs /var/lib/postgresql/data:rw,size=384m \
  -e POSTGRES_DB=i8klab -e POSTGRES_USER=i8klab -e POSTGRES_PASSWORD="$dbpass" \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$pg" pg_isready -U i8klab -d i8klab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" == YES || exit 4
echo "NATIVE_I8K_PG17_READY=OK"
django() { D run --rm --network "$net" --env-file "$tmp/env" "$img" python manage.py "$@"; }
django check >/dev/null
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
echo "NATIVE_I8K_MIGRATION_PARITY=OK"
django migrate --noinput >/dev/null
echo "NATIVE_I8K_DISPOSABLE_SCHEMA=OK"
# Test runner itself creates a second temporary DB in ephemeral Postgres.
django test \
  native_mobile_service.test_i7_native_issuer_absence \
  native_mobile_service.test_native_http_contract \
  native_mobile_service.test_native_operational_issuer_gate \
  native_mobile_service.test_native_server_custody_issuer_pg17 \
  native_mobile_service.test_d22_http_pg17 \
  native_mobile_service.test_d23_workspace_pg17 \
  native_mobile_service.test_i8d_http_pg17 \
  native_mobile_service.test_i8i_non_mfa_recovery_policy_pg17 \
  native_mobile_service.test_i8j_recovery_pg17 \
  native_mobile_service.test_i8k_recovery_http_pg17 \
  --verbosity 1
# Flutter regression intentionally separate in main; no host worktree write or Docker volume.
echo "NATIVE_I8K_FLUTTER_GATE=NOT_RUN_SEPARATE"
echo "NATIVE_I8K_D23_NATIVE_WORKSPACE_PG17=PASS"
echo "NATIVE_I8K_D22_SERVER_CUSTODY_HTTP_PG17=PASS"
echo "NATIVE_I8K_D21_SERVER_CUSTODY_ISSUER_PG17=PASS"
echo "NATIVE_I8K_D20_ISSUER_REVIEW_GATE=PASS"
echo "NATIVE_I8K_NATIVE_JSON_CONTRACT=PASS"
echo "NATIVE_I8K_NO_PUBLIC_ISSUER=PASS"
echo "NATIVE_I8K_NO_MFA_DENIAL_POLICY=PASS"
echo "NATIVE_I8K_ATOMIC_RECOVERY_CORE=PASS"
echo "NATIVE_I8K_RECOVERY_HTTP_JSON=PASS"
echo "NATIVE_I8K_RECOVERY_ENDPOINTS_ABSENT=PASS"
echo "NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS"
