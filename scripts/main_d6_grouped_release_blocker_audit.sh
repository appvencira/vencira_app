#!/usr/bin/env bash
# D6: grouped post-regression release blocker audit.
# D5 and D4 lab successes are not repeated; no mutations or secrets.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D6_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for k in RELEASE_AUTHORIZED DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED OPERATIONAL_ROLLBACK_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED CONTAINER_RUN_EXECUTED O5_CREDENTIALS_ACCESSED; do mark "$k" NO; done
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_OPERATOR FAIL; mark RESULT 2; exit 2; }
for tool in git python3 bash sha256sum sudo docker curl; do
  command -v "$tool" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$tool"; mark RESULT 2; exit 2; }
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" &&
   -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; mark RESULT 2; exit 2; }
mark MAIN_CLEAN PASS
archive="${1:-/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7}"
[[ "$archive" == /* && -d "$archive" && ! -L "$archive" ]] || { mark ARCHIVE_PATH FAIL; mark RESULT 2; exit 2; }
(cd "$archive" && sha256sum --status -c images.tar.gz.sha256) || { mark ARCHIVE_CHECKSUM FAIL; mark RESULT 3; exit 3; }
mark ARCHIVE_CHECKSUM PASS
sudo -n true >/dev/null 2>&1 || { mark SUDO_SESSION REQUIRED; mark RESULT 2; exit 2; }
# Offline verification is evidence, but mismatch in archived image config ID
# remains a real open problem. Do not rewrite the historical manifest.
if python3 scripts/main_d3b3_verify_archived_images_offline.py "$archive" > /dev/null 2>&1; then
  mark ARCHIVE_CONFIG_IDS_FROM_D3B3 PASS
else
  mark ARCHIVE_CONFIG_IDS_FROM_D3B3 UNRESOLVED
fi
# Read-only identity chain and rollback inventory: no service mutation.
if python3 scripts/main_d3b7_image_id_chain_readonly.py "$archive" >/dev/null 2>&1; then
  mark RUNNING_MANIFEST_IMAGE_ID_CHAIN PASS
else
  mark RUNNING_MANIFEST_IMAGE_ID_CHAIN FAIL
fi
if bash scripts/main_d3b_operational_rollback_inventory_readonly.sh >/dev/null 2>&1; then
  mark ROLLBACK_BASELINE_INVENTORY PASS
else
  mark ROLLBACK_BASELINE_INVENTORY FAIL
fi
# Distinguish config grammar and DEV HTTPS availability from *production*
# verification. Do not interpret DEV Caddy pass as production permission.
if bash scripts/main_d3c_caddy_readonly_preflight.sh >/dev/null 2>&1; then
  mark DEV_CADDY_HTTPS_PREFLIGHT PASS
else
  mark DEV_CADDY_HTTPS_PREFLIGHT NOT_VERIFIED
fi
# Read-only TLS handshake and HTTP status for public apex only. This does not
# establish that production application routes, cookies or CSRF are correct.
if code="$(curl --proto '=https' --tlsv1.2 --silent --show-error \
    --connect-timeout 7 --max-time 15 --output /dev/null \
    --write-out '%{http_code}' https://vencira.es/ 2>/dev/null)"; then
  case "$code" in
    200|301|302|303|307|308) mark PUBLIC_APEX_TLS_HTTP_REACHABLE YES;;
    *) mark PUBLIC_APEX_TLS_HTTP_REACHABLE NO;;
  esac
else
  mark PUBLIC_APEX_TLS_HTTP_REACHABLE NO
fi
# No access to off-host image custody credentials; no implication that
# DATABASE backups in O5 contain the Docker image archive.
mark B1_ARCHIVE_EXACT_ID_AND_RUNTIME_RECOVERY VERIFIED_NO
mark B2_EXPORT_RESTORED_IMAGE_REAL_O5_END_TO_END VERIFIED_NO
mark B3_OFF_HOST_ENCRYPTED_IMAGE_CUSTODY VERIFIED_NO
mark B4_MAIN_DJANGO_FLUTTER_WEB_D5_HISTORICAL PASS_RECORDED
mark B4_ANDROID_FINAL_APK_AND_DEVICE VERIFIED_NO
mark B5_PRODUCTION_CADDY_LOADED_CONFIG_COOKIES_CSRF VERIFIED_NO
mark B5_PUBLIC_APPROVAL NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark RELEASE_READINESS BLOCKED
mark BLOCKERS_OPEN 5
mark RESULT 4
exit 4
