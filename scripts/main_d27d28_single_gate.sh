#!/usr/bin/env bash
# D27/D28 grouped lab regression, single invocation.
# No deploy, live migrations, operational auth or production configuration.
set -Eeuo pipefail
set +x
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

mode="${1:---automated}"
case "$mode" in
  --automated|--all|--phone) ;;
  *)
    echo "USAGE: bash scripts/main_d27d28_single_gate.sh [--automated|--all|--phone]" >&2
    exit 64
    ;;
esac

echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
echo D27D28_MASTER_DEPLOY_EXECUTED=NO
echo D27D28_MASTER_LIVE_MIGRATIONS_EXECUTED=NO
echo D27D28_MASTER_ANDROID_MAIN_AUTH_ENABLED=NO
echo D27D28_MASTER_RELEASE_AUTHORIZED=NO

if [[ "$(id -u)" == 0 ]]; then
  echo D27D28_MASTER_NONROOT_REQUIRED=FAIL >&2
  exit 2
fi
if [[ "$(git branch --show-current)" != main ||
      "$(git rev-parse HEAD)" != "$(git rev-parse refs/remotes/origin/main)" ||
      -n "$(git status --porcelain)" ]]; then
  echo D27D28_MASTER_MAIN_CLEAN=FAIL >&2
  exit 2
fi
echo D27D28_MASTER_MAIN_CLEAN=PASS

checks=(
  scripts/main_d27_independent_issuer_pg17_grouped_gate.sh
  scripts/main_d27d28_phase1_router_grouped_gate.sh
  scripts/main_d27_flutter_real_https_pg17_isolated.sh
  scripts/main_d28_android_response_loss_pg17_lab.sh
)
for path in "${checks[@]}"; do
  [[ -f "$path" ]] || { echo "D27D28_MASTER_REQUIRED_SCRIPT_MISSING=$path" >&2; exit 2; }
  bash -n "$path"
done
echo D27D28_MASTER_SHELL_PREFLIGHT=PASS

rc=0
current=none
finished=()
on_exit() {
  local status=$?
  trap - EXIT
  if (( status != 0 )); then
    echo "D27D28_MASTER_STOPPED_AT=$current"
    echo "D27D28_MASTER_RESULT=$status"
  else
    echo "D27D28_MASTER_COMPLETED=${finished[*]}"
    echo D27D28_MASTER_RESULT=0
  fi
  echo MFA_RELEASE_AUTHORIZED=NO
  echo NO_DEPLOY_NO_LIVE_MIGRATION=1
}
trap on_exit EXIT

run_gate() {
  local key="$1" path="$2"
  current="$key"
  echo "D27D28_MASTER_START=$key"
  bash "$path"
  echo "D27D28_MASTER_${key}=PASS"
  finished+=("$key")
}

# Important: do not rerun already successful historical gates on every
# documentation-only update. Choose --automated for a planned grouped
# regression, --phone for a new physical rehearsal, or --all at phase close.
if [[ "$mode" == --automated || "$mode" == --all ]]; then
  run_gate D27_PG17 scripts/main_d27_independent_issuer_pg17_grouped_gate.sh
  run_gate D28_FLUTTER scripts/main_d27d28_phase1_router_grouped_gate.sh
  run_gate D27_D28_REAL_TLS scripts/main_d27_flutter_real_https_pg17_isolated.sh
fi
if [[ "$mode" == --phone || "$mode" == --all ]]; then
  echo D27D28_MASTER_PHONE_MANUAL_RESTART_REQUIRED=YES
  echo D27D28_MASTER_PHONE_OPERATOR_EVIDENCE_REQUIRED=YES
  run_gate D28_PHONE scripts/main_d28_android_response_loss_pg17_lab.sh
fi
