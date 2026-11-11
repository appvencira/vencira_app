#!/usr/bin/env bash
# D13 privileged reader, called only by D13 unprivileged wrapper.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D13_%s=%s\n' "$1" "$2"; }
[[ "$(id -u)" == 0 && $# == 2 ]] || { mark HELPER_ARGS FAIL; exit 2; }
dst="$1"; owner="$2"
[[ "$owner" =~ ^[0-9]+$ && "$owner" -gt 0 ]] || { mark OWNER FAIL; exit 2; }
[[ "$dst" == /home/vencira/vencira-release-archives/d13-remote.* &&
   -d "$dst" && ! -L "$dst" &&
   "$(stat -c '%u:%a' "$dst")" == "$owner:700" ]] || {
  mark DESTINATION_SECURITY FAIL; exit 2;
}
for tool in restic rclone python3 sha256sum stat; do
  command -v "$tool" >/dev/null || { mark PREREQUISITE "$tool"; exit 2; }
done
cfgdir=/etc/vencira-backup
cfg="$cfgdir/config.env"
[[ -d "$cfgdir" && ! -L "$cfgdir" && -f "$cfg" && ! -L "$cfg" &&
   "$(stat -c '%u:%a' "$cfgdir")" == 0:700 &&
   "$(stat -c '%u:%a' "$cfg")" == 0:600 ]] || { mark O5_CONFIG_SECURITY FAIL; exit 3; }
set -a
source "$cfg"
set +a
[[ "${RESTIC_REPOSITORY:-}" == 'rclone:vencira_google:VENCIRA-Backups/PostgreSQL' &&
   "${RESTIC_PASSWORD_FILE:-}" == /etc/vencira-backup/restic-password &&
   "${RCLONE_CONFIG:-}" == /etc/vencira-backup/rclone.conf &&
   -z "${RESTIC_PASSWORD:-}" ]] || { mark REPOSITORY_IDENTITY FAIL; exit 3; }
for f in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  [[ -s "$f" && ! -L "$f" && "$(stat -c '%u:%a' "$f")" == 0:600 ]] || {
    mark CREDENTIAL_PERMISSIONS FAIL; exit 3;
  }
done
mark REMOTE_SOURCE_VERIFIED PASS
archive="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
selector='
import json,sys,re,datetime
items=json.load(sys.stdin); path=sys.argv[1]; matches=[]
for x in items:
    if not isinstance(x,dict):continue
    ident=x.get("id","")
    if not isinstance(ident,str) or not re.fullmatch(r"[0-9a-f]{64}",ident):continue
    if "vencira-image-archive" not in x.get("tags",[]):continue
    if path not in x.get("paths",[]):continue
    if not any(isinstance(t,str) and re.fullmatch(r"d12-vencira-images-[0-9a-f]{24}",t) for t in x.get("tags",[])):continue
    try: moment=datetime.datetime.fromisoformat(x["time"].replace("Z","+00:00"))
    except (ValueError,KeyError,TypeError,AttributeError):continue
    if moment.tzinfo is None:continue
    matches.append((moment,ident))
if not matches:sys.exit(1)
matches.sort(reverse=True)
if len(matches)>1 and matches[0][0]==matches[1][0]:sys.exit(1)
print(matches[0][1])
'
snapshot="$(restic --no-lock snapshots --json --tag vencira-image-archive 2>/dev/null |
  python3 -c "$selector" "$archive")" || { mark D12_SNAPSHOT_SELECTION FAIL; exit 4; }
mark D12_SNAPSHOT_SELECTION PASS
for filename in images.tar.gz images.tar.gz.sha256 images.manifest; do
  [[ ! -e "$dst/$filename" ]] || { mark DESTINATION_NOT_EMPTY FAIL; exit 4; }
  if ! restic --no-lock dump "$snapshot" "$archive/$filename" >"$dst/$filename" 2>/dev/null; then
    mark REMOTE_DOWNLOAD FAIL; exit 5;
  fi
  chown "$owner" "$dst/$filename"
  chmod 600 "$dst/$filename"
done
(cd "$dst" && sha256sum --status -c images.tar.gz.sha256) || {
  mark RECOVERED_ARCHIVE_SHA256 FAIL; exit 6;
}
mark RESTIC_REMOTE_ARCHIVE_DOWNLOADED PASS
mark RECOVERED_ARCHIVE_SHA256 PASS
mark D12_SNAPSHOT_CONTENT_SOURCE YES
mark LIVE_RESTORE_EXECUTED NO
mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
mark RESULT 0
