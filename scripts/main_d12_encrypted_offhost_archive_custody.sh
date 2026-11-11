#!/usr/bin/env bash
# D12: encrypted off-host backup of historical image archive plus remote
# streamed hash verification. This WRITES one new remote restic snapshot.
# No Docker/container/Caddy/DNS action, no live database restore or migration.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D12_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for k in DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED CONTAINER_RUN_EXECUTED CADDY_RELOAD_EXECUTED CADDY_CONFIG_CHANGED DNS_CHANGED OPERATIONAL_ROLLBACK_EXECUTED; do mark "$k" NO; done
mark ENCRYPTED_OFF_HOST_SNAPSHOT_CREATED NO
mark REMOTE_PAYLOAD_VERIFIED NO
[[ "$(id -u)" == 0 ]] || { mark ROOT_REQUIRED YES; mark RESULT 2; exit 2; }
for t in restic rclone python3 sha256sum stat openssl git; do
  command -v "$t" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$t"; mark RESULT 2; exit 2; }
done
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" &&
   -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; mark RESULT 2; exit 2; }
mark MAIN_CLEAN PASS
archive="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
[[ -d "$archive" && ! -L "$archive" ]] || { mark ARCHIVE_PATH FAIL; mark RESULT 2; exit 2; }
for f in images.tar.gz images.tar.gz.sha256 images.manifest; do
  [[ -f "$archive/$f" && ! -L "$archive/$f" ]] || { mark ARCHIVE_FILES FAIL; mark RESULT 2; exit 2; }
done
(cd "$archive" && sha256sum --status -c images.tar.gz.sha256) || {
  mark LOCAL_ARCHIVE_CHECKSUM FAIL; mark RESULT 3; exit 3;
}
mark LOCAL_ARCHIVE_CHECKSUM PASS
digest_archive="$(sha256sum "$archive/images.tar.gz" | cut -d' ' -f1)"
digest_manifest="$(sha256sum "$archive/images.manifest" | cut -d' ' -f1)"
digest_checksum="$(sha256sum "$archive/images.tar.gz.sha256" | cut -d' ' -f1)"
for digest in "$digest_archive" "$digest_manifest" "$digest_checksum"; do
  [[ "$digest" =~ ^[a-f0-9]{64}$ ]] || { mark HASH_CAPTURE FAIL; mark RESULT 3; exit 3; }
done
cfgdir=/etc/vencira-backup
cfg="$cfgdir/config.env"
[[ -d "$cfgdir" && ! -L "$cfgdir" && -f "$cfg" && ! -L "$cfg" &&
   "$(stat -c '%u:%a' "$cfgdir")" == '0:700' &&
   "$(stat -c '%u:%a' "$cfg")" == '0:600' ]] || {
  mark O5_CONFIGURATION_SECURITY FAIL; mark RESULT 3; exit 3;
}
set -a
# shellcheck disable=SC1091
source "$cfg"
set +a
[[ "$RESTIC_REPOSITORY" == 'rclone:vencira_google:VENCIRA-Backups/PostgreSQL' &&
   "$RESTIC_PASSWORD_FILE" == '/etc/vencira-backup/restic-password' &&
   "$RCLONE_CONFIG" == '/etc/vencira-backup/rclone.conf' &&
   -z "$(printenv RESTIC_PASSWORD || true)" ]] || {
  mark RESTIC_REPOSITORY_IDENTITY FAIL; mark RESULT 3; exit 3;
}
for p in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  [[ -s "$p" && ! -L "$p" && "$(stat -c '%u:%a' "$p")" == '0:600' ]] || {
    mark RESTIC_CREDENTIAL_PERMISSIONS FAIL; mark RESULT 3; exit 3;
  }
done
mark REMOTE_REPOSITORY_CONFIG PASS
tag="d12-vencira-images-$(openssl rand -hex 12)"
if ! restic backup --quiet --tag vencira-image-archive --tag "$tag" "$archive" >/dev/null 2>&1; then
  mark ENCRYPTED_OFF_HOST_BACKUP FAIL; mark RESULT 4; exit 4
fi
mark ENCRYPTED_OFF_HOST_SNAPSHOT_CREATED YES
selector='
import json,sys,re
items=json.load(sys.stdin); tag=sys.argv[1]; path=sys.argv[2]; hits=[]
for x in items:
    if not isinstance(x,dict): continue
    if tag not in x.get("tags",[]): continue
    ident=x.get("id","")
    if not isinstance(ident,str) or not re.fullmatch("[0-9a-f]{64}",ident): continue
    if path not in x.get("paths",[]): continue
    hits.append(ident)
if len(hits)!=1: sys.exit(1)
print(hits[0])
'
snapshot="$(restic --no-lock snapshots --json --tag "$tag" 2>/dev/null |
    python3 -c "$selector" "$tag" "$archive")" || {
  mark UNIQUE_REMOTE_SNAPSHOT FAIL; mark RESULT 5; exit 5
}
mark UNIQUE_REMOTE_SNAPSHOT PASS
verify_remote(){
  local got
  got="$(restic --no-lock dump "$snapshot" "$archive/$1" 2>/dev/null |
        sha256sum | cut -d' ' -f1)" || return 1
  [[ "$got" == "$2" ]]
}
if verify_remote images.tar.gz "$digest_archive"; then
  mark REMOTE_ARCHIVE_BYTES_EQUAL PASS
else
  mark REMOTE_ARCHIVE_BYTES_EQUAL FAIL; mark RESULT 6; exit 6
fi
if verify_remote images.manifest "$digest_manifest" &&
   verify_remote images.tar.gz.sha256 "$digest_checksum"; then
  mark REMOTE_METADATA_BYTES_EQUAL PASS
else
  mark REMOTE_METADATA_BYTES_EQUAL FAIL; mark RESULT 6; exit 6
fi
mark REMOTE_PAYLOAD_VERIFIED YES
mark ENCRYPTED_OFF_HOST_ARCHIVE_CUSTODY PASS
mark REMOTE_RESTORE_TO_NEW_RUNTIME_VERIFIED NO
mark ARCHIVE_CONFIG_ID_EQUIVALENCE_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RESULT 0
