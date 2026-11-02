#!/usr/bin/env bash
# VENCIRA regression batch: disposable databases; no deployment.
# Usage: bash scripts/n1_verification_batch.sh
set -uo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
LOG_ROOT="$HOME/vencira-m3-results"
mkdir -p "$LOG_ROOT"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$LOG_ROOT/n1-batch-$STAMP"
mkdir -p "$OUT"

NET="vencira-n1-batch-$$"
PG="vencira-n1-batch-pg17-$$"
DB="vencira_n1_batch_test"
USR="vencira_n1_batch"
PW="ephemeral-ci-only-n1-batch"
IMG="vencira-m3-backend-test"
DOCKER=(sudo docker)
PG_UP=0
NET_UP=0

cleanup() {
  if [ "$PG_UP" -eq 1 ]; then
    "${DOCKER[@]}" rm -f "$PG" >/dev/null 2>&1 || true
  fi
  if [ "$NET_UP" -eq 1 ]; then
    "${DOCKER[@]}" network rm "$NET" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

TESTS=(
  reminders.test_native_mobile_auth_boundary
  reminders.test_native_mobile_identity_gate
  reminders.test_native_mobile_identity_database
  reminders.test_native_mobile_token_primitives
  reminders.test_mfa_login
  reminders.test_login_security
  reminders.test_reminder_planning
  reminders.test_control_intent
  reminders.test_person_suggestions_ranking
  reminders.test_control_responses
  reminders.test_control_response_api
  reminders.test_operational_transitions
  reminders.test_operational_inbox
  reminders.test_operational_api
  reminders.test_results
  reminders.test_device_notice_preview
  reminders.test_agenda
)

declare -A STATUS
step() {
  local name="$1"
  shift
  echo "=== $name ==="
  "$@" > "$OUT/$name.log" 2>&1
  STATUS["$name"]=$?
  tail -n 12 "$OUT/$name.log"
  echo "N1_BATCH_${name}=${STATUS[$name]}"
}

step STATIC python3 scripts/n1_static_security_gate.py
step BUILD "${DOCKER[@]}" build -t "$IMG" ./backend

if [ "${STATUS[BUILD]}" -eq 0 ]; then
  step SQLITE "${DOCKER[@]}" run --rm --network none \
    -e VENCIRA_ENV=test -e DJANGO_DEBUG=1 \
    -e DJANGO_SECRET_KEY=ci-only-local-test-not-a-production-secret \
    -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
    -e VENCIRA_DB_ENGINE=sqlite \
    "$IMG" python -u manage.py test "${TESTS[@]}" --verbosity 1

  step SQLITE_LAB "${DOCKER[@]}" run --rm --network none \
    -e VENCIRA_ENV=test -e DJANGO_DEBUG=1 \
    -e DJANGO_SECRET_KEY=ci-only-local-test-not-a-production-secret \
    -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
    -e VENCIRA_DB_ENGINE=sqlite -e VENCIRA_NATIVE_SESSION_LAB=1 \
    "$IMG" python -u manage.py test \
    reminders.test_native_mobile_identity_database \
    reminders.test_native_mobile_token_primitives \
    native_sessions_lab.tests \
    native_sessions_lab.test_pg17_race --verbosity 1

  if "${DOCKER[@]}" network create --internal "$NET" > "$OUT/pg-network.log" 2>&1; then
    NET_UP=1
    if "${DOCKER[@]}" run -d --rm --name "$PG" --network "$NET" \
        --tmpfs /var/lib/postgresql/data:rw,size=536870912 \
        -e POSTGRES_DB="$DB" -e POSTGRES_USER="$USR" \
        -e POSTGRES_PASSWORD="$PW" postgres:17-alpine \
        > "$OUT/pg-start.log" 2>&1; then
      PG_UP=1
      READY=0
      for _ in $(seq 1 45); do
        if "${DOCKER[@]}" exec "$PG" pg_isready -U "$USR" -d "$DB" \
            >/dev/null 2>&1; then
          READY=1
          break
        fi
        sleep 1
      done
      if [ "$READY" -eq 1 ]; then
        step PG17 "${DOCKER[@]}" run --rm --network "$NET" \
          -e VENCIRA_ENV=test -e DJANGO_DEBUG=1 \
          -e DJANGO_SECRET_KEY=ci-only-local-test-not-a-production-secret \
          -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
          -e VENCIRA_DB_ENGINE=postgresql \
          -e POSTGRES_DB="$DB" -e POSTGRES_USER="$USR" \
          -e POSTGRES_PASSWORD="$PW" -e POSTGRES_HOST="$PG" \
          "$IMG" python -u manage.py test "${TESTS[@]}" --verbosity 1

        step PG17_LAB "${DOCKER[@]}" run --rm --network "$NET" \
          -e VENCIRA_ENV=test -e DJANGO_DEBUG=1 \
          -e DJANGO_SECRET_KEY=ci-only-local-test-not-a-production-secret \
          -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
          -e VENCIRA_DB_ENGINE=postgresql -e VENCIRA_NATIVE_SESSION_LAB=1 \
          -e POSTGRES_DB="$DB" -e POSTGRES_USER="$USR" \
          -e POSTGRES_PASSWORD="$PW" -e POSTGRES_HOST="$PG" \
          "$IMG" python -u manage.py test \
          reminders.test_native_mobile_identity_database \
          reminders.test_native_mobile_token_primitives \
          native_sessions_lab.tests \
          native_sessions_lab.test_pg17_race --verbosity 1
      else
        STATUS[PG17]=3
        STATUS[PG17_LAB]=3
        echo "PG17=NOT_READY" | tee "$OUT/PG17.log"
      fi
    else
      STATUS[PG17]=4
      STATUS[PG17_LAB]=4
    fi
  else
    STATUS[PG17]=5
    STATUS[PG17_LAB]=5
  fi
else
  STATUS[SQLITE]=99
  STATUS[SQLITE_LAB]=99
  STATUS[PG17]=99
  STATUS[PG17_LAB]=99
fi

step FLUTTER "${DOCKER[@]}" run --rm \
  -v "$ROOT/clients/flutter:/work" -w /work \
  ghcr.io/cirruslabs/flutter:stable sh -c \
  'flutter pub get && flutter analyze && flutter test && flutter build web --release --pwa-strategy=none'

echo "=== BATCH FINAL SUMMARY ==="
FAILED=0
for name in STATIC BUILD SQLITE SQLITE_LAB PG17 PG17_LAB FLUTTER; do
  code="${STATUS[$name]:-99}"
  echo "N1_BATCH_${name}=$code"
  if [ "$code" -ne 0 ]; then FAILED=1; fi
done
echo "N1_BATCH_LOGS=$OUT"
echo "N1_BATCH_RESULT=$FAILED"
exit "$FAILED"
