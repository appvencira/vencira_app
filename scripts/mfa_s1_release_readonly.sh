#!/usr/bin/env bash
# MFA S1: puerta de despliegue de solo lectura; NUNCA publica ni migra.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
fail() { echo "MFA_S1_RELEASE=BLOCKED"; echo "REASON=$1"; exit 4; }
test "$#" -eq 1 || fail CANDIDATE_SHA_REQUIRED
CANDIDATE="$(git rev-parse --verify "$1^{commit}" 2>/dev/null)" || fail CANDIDATE_UNKNOWN
test "$(git rev-parse HEAD)" = "$CANDIDATE" || fail CHECKOUT_NOT_CANDIDATE
bash scripts/mfa_release_guard_readonly.sh "$CANDIDATE" || fail STATIC_CHECK
# Comprobación exclusivamente sintética del candidato: jamás interpretar el
# resultado como autorización frente a la BD persistente (actualmente 0018).
echo "MFA_CANDIDATE_STATIC_GATE=OK"
echo "MFA_RUNTIME_LIVE_GUARD=PENDING"
echo "MFA_OPERATIONAL_CUSTODY=PENDING"
echo "MFA_ADMIN_RECOVERY=PENDING"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_MIGRATION=1"
