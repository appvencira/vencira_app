#!/usr/bin/env bash
# VENCIRA N1: isolated PostgreSQL 17 identity regression.
# Invoke with: bash scripts/n1_identity_pg17_ephemeral.sh
# No live DB, port publishing, named volume, deployment, or data migration.
set -euo pipefail

DOCKER=(sudo docker)
PG_IMAGE="postgres:17-alpine"
API_IMAGE="vencira-m3-backend-test"
NETWORK="vencira-n1-isolated-$$"
PG_CONTAINER="vencira-n1-postgres17-$$"
DB_NAME="vencira_n1_identity_synthetic"
DB_USER="vencira_n1_synthetic"
DB_PASSWORD="only-for-disposable-n1-test-pg17-2026"

# --lab runs only the PostgreSQL integration/lifecycle suites, skipping
# the already-green frontend, SQLite and broader backend regressions.
MODE="${1:-identity}"
case "$MODE" in
  identity)
    EXTRA_ENV=()
    SUITES=(
      reminders.test_native_mobile_auth_boundary
      reminders.test_native_mobile_identity_gate
      reminders.test_native_mobile_identity_database
      reminders.test_native_mobile_token_primitives
    )
    ;;
  --lab)
    EXTRA_ENV=(-e VENCIRA_NATIVE_SESSION_LAB=1)
    SUITES=(
      reminders.test_native_mobile_identity_database
      reminders.test_native_mobile_token_primitives
      native_sessions_lab.tests
      native_sessions_lab.test_pg17_race
      native_sessions_lab.test_login_rules
      native_sessions_lab.test_pg17_login_race
      native_sessions_lab.test_http_contract_cases
      native_sessions_lab.test_loopback_http_contract
      native_sessions_lab.test_verified_https_loopback
    )
    ;;
  --lab-https)
    # G7-D1 only: 3 HTTPS/TLS tests on a disposable PG17 test database.
    # Reuses private Docker network/tmpfs isolation; never exposes port 443.
    EXTRA_ENV=(-e VENCIRA_NATIVE_SESSION_LAB=1)
    SUITES=(
      native_sessions_lab.test_verified_https_loopback
    )
    ;;
  --candidate)
    # Isolated G4/G5 persistent-schema proposal, no operational route or DB.
    EXTRA_ENV=(-e VENCIRA_NATIVE_SERVICE_CANDIDATE=1)
    SUITES=(
      native_mobile_service.test_contract
      native_mobile_service.test_pg17_races
      native_mobile_service.test_g5_network_identity
      native_mobile_service.test_g5_throttle
      native_mobile_service.test_g5_pg17_races
      native_mobile_service.test_g5_audit
      native_mobile_service.test_g5_audit_pg17_races
      native_mobile_service.test_g5_keyring_policy
      native_mobile_service.test_g5_digest_capacity
      native_mobile_service.test_g14_admission
      native_mobile_service.test_g14_issuance_contract
      native_mobile_service.test_g14_issuance_atomicity
      native_mobile_service.test_g14_locked_verifier
      native_mobile_service.test_g14_untrusted_evidence
      native_mobile_service.test_g14_d3_candidate_boundary
      native_mobile_service.test_g14_d3_pg17_races
      native_mobile_service.test_g14_d5_mfa_writer_pg17_races
      native_mobile_service.test_g14_d8_admin_rotation_pg17
      native_mobile_service.test_g14_d9_recovery_guards_pg17
      native_mobile_service.test_g14_d9c_admin_finalization_pg17
      native_mobile_service.test_g14_e1_locked_mfa_verifier
    )
    ;;
  --lab-case)
    # Fixed allowlisted regression; do not accept arbitrary test targets.
    # Uses the same isolated PG17 tmpfs network as the full --lab suite.
    EXTRA_ENV=(-e VENCIRA_NATIVE_SESSION_LAB=1)
    SUITES=(
      native_sessions_lab.test_http_contract_cases.NativeRecoveryAfterAmbiguousRefreshHttpTests.test_recovery_rejects_oversized_payload_without_browser_state
    )
    ;;
  *)
    echo "Usage: bash scripts/n1_identity_pg17_ephemeral.sh [--lab|--lab-https|--lab-case|--candidate]" >&2
    exit 2
    ;;
esac

cleanup() {
  "${DOCKER[@]}" rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  "${DOCKER[@]}" network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! "${DOCKER[@]}" image inspect "$API_IMAGE" >/dev/null 2>&1; then
  echo "N1_PG17_RESULT=NOT_RUN: missing backend image $API_IMAGE" >&2
  exit 2
fi

echo "N1_PG17=isolated (private internal network, tmpfs, no published ports)"
"${DOCKER[@]}" network create --internal "$NETWORK" >/dev/null
"${DOCKER[@]}" run --rm --detach \
  --name "$PG_CONTAINER" \
  --network "$NETWORK" \
  --tmpfs /var/lib/postgresql/data:rw,size=536870912 \
  -e "POSTGRES_DB=$DB_NAME" \
  -e "POSTGRES_USER=$DB_USER" \
  -e "POSTGRES_PASSWORD=$DB_PASSWORD" \
  "$PG_IMAGE" >/dev/null

ready=0
for _ in $(seq 1 45); do
  if "${DOCKER[@]}" exec "$PG_CONTAINER" \
      pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "N1_PG17_RESULT=NOT_READY" >&2
  "${DOCKER[@]}" logs --tail 40 "$PG_CONTAINER" >&2 || true
  exit 3
fi

echo "N1_PG17_POSTGRES_READY=OK"
result=0
"${DOCKER[@]}" run --rm \
  --network "$NETWORK" \
  "${EXTRA_ENV[@]}" \
  -e VENCIRA_ENV=test \
  -e DJANGO_DEBUG=1 \
  -e DJANGO_SECRET_KEY=ci-only-local-test-not-a-production-secret \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  -e VENCIRA_DB_ENGINE=postgresql \
  -e "POSTGRES_DB=$DB_NAME" \
  -e "POSTGRES_USER=$DB_USER" \
  -e "POSTGRES_PASSWORD=$DB_PASSWORD" \
  -e "POSTGRES_HOST=$PG_CONTAINER" \
  -e POSTGRES_PORT=5432 \
  "$API_IMAGE" sh -c '
    if [ "$1" = "--candidate" ]; then
      python manage.py makemigrations native_mobile_service --check --dry-run || exit $?
    fi
    shift
    exec python -u manage.py test "$@" --verbosity 1
  ' -- "$MODE" "${SUITES[@]}" || result=$?

if [ "$MODE" = "--lab" ]; then
  echo "N1_PG17_LAB_RESULT=$result"
elif [ "$MODE" = "--lab-https" ]; then
  echo "G7_D1_TLS_PG17_RESULT=$result"
elif [ "$MODE" = "--lab-case" ]; then
  echo "N1_PG17_LAB_CASE_RESULT=$result"
elif [ "$MODE" = "--candidate" ]; then
  echo "G4_CANDIDATE_PG17_RESULT=$result"
  echo "G5_CANDIDATE_PG17_RESULT=$result"
else
  echo "N1_IDENTITY_PG17_RESULT=$result"
fi
exit "$result"
