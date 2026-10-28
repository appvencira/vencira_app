#!/usr/bin/env bash
# Unified C-FICHA candidate gate. Only disposable Docker resources.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
test -z "$(git status --porcelain)"
echo "C_FICHA_CANDIDATE_COMMIT=$(git rev-parse HEAD)"
bash -n scripts/rehearse_c_ficha_split_readonly.sh
bash -n scripts/rehearse_clamd_adapter_isolated.sh
bash -n scripts/validate_c_ficha_pg17_integrated.sh
bash scripts/validate_c_ficha_pg17_integrated.sh
echo "C_FICHA_CANDIDATE_LEGACY_FULL_GATE=OK"
bash scripts/rehearse_c_ficha_split_readonly.sh
echo "C_FICHA_CANDIDATE_PG17=OK"
bash scripts/rehearse_clamd_adapter_isolated.sh
echo "C_FICHA_CANDIDATE_REAL_CLAMD=OK"
# The legacy full Django and Flutter suite and the independent PostgreSQL
# suite are both mandatory; neither is evidence for a production release.
echo "C_FICHA_CANDIDATE_RESULT=0"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "MFA_RELEASE_AUTHORIZED=NO"
