#!/usr/bin/env bash
# MB1 M1-03 grouped gap audit. SOURCE and LIVE queries are read-only.
# No stopping services, migrations, backups or credentials are printed.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
finish() {
  rc=$?
  trap - EXIT
  echo "MB1_M103_GROUP_PHASE=$PHASE"
  echo "MB1_M103_GROUP_RESULT=$rc"
  echo "MB1_M103_CENSUS=NOT_UNIVERSAL_WRITER_EXCLUSION"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
test -f scripts/audit_mb1_m103_effective_pg_network_readonly.py
test -f scripts/test_mb1_m103_effective_pg_network_readonly.py
python3 -m py_compile scripts/audit_mb1_m103_effective_pg_network_readonly.py \
  scripts/gate_b18k_critical_primitive_calls.py
echo "MB1_M103_SOURCE_PREFLIGHT=OK"

PHASE=PURE_CONTRACTS
python3 -m unittest -q scripts.test_mb1_m103_effective_pg_network_readonly
echo "MB1_M103_PURE_CONTRACTS=OK"

PHASE=CRITICAL_CALLS
python3 scripts/gate_b18k_critical_primitive_calls.py
echo "MB1_M103_CRITICAL_SOURCE_CALLS=OK"

PHASE=PG_NETWORK_READONLY
# This is the ONLY privileged command; it only calls docker inspect, docker
# network inspect and SELECT on two verified VENCIRA PostgreSQL containers.
sudo env MB1_M103_READONLY_GAP=YES \
  python3 scripts/audit_mb1_m103_effective_pg_network_readonly.py
echo "MB1_M103_PG_NETWORK_READONLY=OK"
PHASE=DONE
echo "MB1_M103_GROUP_DONE=OK"
