#!/usr/bin/env bash
# D3-B2: immutable pre-upgrade images archive, no operational mutation.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D3B2_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark ROLLBACK_EXECUTED NO
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
for tool in docker git gzip tar sha256sum df stat openssl awk; do
  command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }
done
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || { mark MAIN_SYNC FAIL; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE FAIL; exit 2; }
mark MAIN_SYNC PASS
[[ "$(id -u)" != 0 ]] || { mark UNPRIVILEGED_OPERATOR_REQUIRED YES; exit 2; }
sudo -v
D(){ sudo docker "$@"; }
api=vencira_localcheck-api-1
db=vencira_localcheck-db-1
web=vencira_localcheck-web_preview-1
for name in "$api" "$db" "$web"; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck &&
     "$(D inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" == true ]] || { mark DEV_IDENTITY FAIL; exit 3; }
done
api_id="$(D inspect -f '{{.Id}}:{{.Image}}' "$api")"
db_id="$(D inspect -f '{{.Id}}:{{.Image}}' "$db")"
web_id="$(D inspect -f '{{.Id}}:{{.Image}}' "$web")"
api_img="$(D inspect -f '{{.Image}}' "$api")"
db_img="$(D inspect -f '{{.Image}}' "$db")"
web_img="$(D inspect -f '{{.Image}}' "$web")"
for img in "$api_img" "$db_img" "$web_img"; do
  [[ "$img" =~ ^sha256:[a-f0-9]{64}$ ]] || { mark IMMUTABLE_ID_INVALID YES; exit 3; }
  D image inspect "$img" >/dev/null 2>&1 || { mark CURRENT_IMAGE_MISSING YES; exit 3; }
done
mark CURRENT_IMAGES_PRESENT PASS
[[ "$(D inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Type}}{{end}}{{end}}' "$db")" == volume ]] || {
  mark DB_VOLUME_TYPE FAIL; exit 3;
}
mark DB_NAMED_VOLUME PASS
base="$HOME/vencira-release-archives"
[[ "$base" != "$root" && "$base" != "$root/"* && ! -L "$base" ]] || { mark ARCHIVE_PATH_INVALID YES; exit 4; }
if [[ ! -e "$base" ]]; then mkdir -m 700 -- "$base"; fi
[[ -d "$base" && "$(stat -c '%u:%a' "$base")" == "$(id -u):700" ]] || {
  mark ARCHIVE_PERMISSIONS FAIL; exit 4;
}
total=0
for img in "$api_img" "$db_img" "$web_img"; do
  bytes="$(D image inspect -f '{{.Size}}' "$img")"
  [[ "$bytes" =~ ^[0-9]+$ ]] || { mark IMAGE_SIZE_INVALID YES; exit 4; }
  total=$((total+bytes))
done
available="$(df -Pk "$base" | awk 'END {print $4}')"
[[ "$available" =~ ^[0-9]+$ ]] || { mark DISK_CAPACITY_UNKNOWN YES; exit 4; }
required=$(((total+1073741824+1023)/1024))
((available>=required)) || { mark DISK_CAPACITY FAIL; exit 4; }
mark DISK_CAPACITY PASS
dir="$base/pre-upgrade-$(openssl rand -hex 12)"
mkdir -m 700 -- "$dir"
finished=NO
cleanup(){
  rc=$?
  trap - EXIT
  if [[ "$finished" != YES ]]; then
    rm -f -- "$dir/images.tar.gz" "$dir/images.tar.gz.sha256" "$dir/images.manifest"
    rmdir -- "$dir" 2>/dev/null || rc=9
  fi
  unchanged=YES
  [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$api" 2>/dev/null)" == "$api_id" ]] || unchanged=NO
  [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$db" 2>/dev/null)" == "$db_id" ]] || unchanged=NO
  [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$web" 2>/dev/null)" == "$web_id" ]] || unchanged=NO
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$unchanged" == YES ]] && echo OK || echo FAIL)"
  [[ "$unchanged" == YES ]] || rc=9
  mark ARCHIVE_PRESERVED "$([[ "$finished" == YES ]] && echo YES || echo NO)"
  mark OPERATIONAL_ROLLBACK_VERIFIED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D image save "$api_img" "$db_img" "$web_img" | gzip -1 > "$dir/images.tar.gz" || { mark ARCHIVE_EXPORT FAIL; exit 5; }
mark IMAGE_SAVE PASS
gzip -t "$dir/images.tar.gz" || { mark GZIP_INTEGRITY FAIL; exit 5; }
tar -tzf "$dir/images.tar.gz" >/dev/null || { mark TAR_INTEGRITY FAIL; exit 5; }
mark ARCHIVE_STRUCTURAL_INTEGRITY PASS
(cd "$dir" && sha256sum images.tar.gz > images.tar.gz.sha256 &&
 sha256sum -c images.tar.gz.sha256 >/dev/null) || { mark CHECKSUM FAIL; exit 5; }
mark ARCHIVE_CHECKSUM PASS
printf 'api=%s\ndb=%s\nweb=%s\n' "$api_img" "$db_img" "$web_img" > "$dir/images.manifest"
chmod 600 "$dir/images.tar.gz" "$dir/images.tar.gz.sha256" "$dir/images.manifest"
finished=YES
mark PRE_UPGRADE_IMAGES_ARCHIVED PASS
mark ARCHIVE_OFF_HOST_VERIFIED NO
mark IMAGE_RELOAD_TESTED NO
mark ARCHIVE_DIRECTORY "$dir"
