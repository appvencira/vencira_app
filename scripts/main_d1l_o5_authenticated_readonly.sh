#!/usr/bin/env bash
# D1-L: read-only inspection of the exact O5 Restic configuration.
# Does not invoke the backup service or its upload wrapper.
set -Eeuo pipefail
set +x
umask 077
if [[ "$(id -u)" != "0" ]]; then
  echo 'D1L_ROOT_REQUIRED=YES'
  exit 1
fi
FILE=/etc/vencira-backup/config.env
DIR=/etc/vencira-backup
for path in "$DIR" "$FILE"; do
  if [[ -L "$path" || ! -e "$path" ]]; then
    echo 'D1L_SECURE_CONFIG=FAIL'
    exit 1
  fi
done
if [[ "$(stat -c '%u:%a' "$DIR")" != '0:700' ||
      "$(stat -c '%u:%a' "$FILE")" != '0:600' ]]; then
  echo 'D1L_SECURE_CONFIG=FAIL'
  exit 1
fi
echo 'D1L_SECURE_CONFIG=PASS'
# Exactly the configuration source used by the existing protected O5 backup.
set -a
# shellcheck disable=SC1091
source "$FILE"
set +a
if [[ "${RESTIC_REPOSITORY:-}" != 'rclone:vencira_google:VENCIRA-Backups/PostgreSQL' ||
      "${RESTIC_PASSWORD_FILE:-}" != '/etc/vencira-backup/restic-password' ||
      "${RCLONE_CONFIG:-}" != '/etc/vencira-backup/rclone.conf' ||
      -n "${RESTIC_PASSWORD:-}" ]]; then
  echo 'D1L_O5_CONFIG_MATCH=FAIL'
  exit 1
fi
for path in "$RESTIC_PASSWORD_FILE" "$RCLONE_CONFIG"; do
  if [[ -L "$path" || ! -s "$path" ||
        "$(stat -c '%u:%a' "$path")" != '0:600' ]]; then
    echo 'D1L_CREDENTIAL_FILE_PERMISSIONS=FAIL'
    exit 1
  fi
done
echo 'D1L_O5_CONFIG_MATCH=PASS'
echo 'D1L_CREDENTIAL_FILE_PERMISSIONS=PASS'
echo 'D1L_RESTIC_BACKUP_EXECUTED=NO'
echo 'D1L_RESTIC_RESTORE_EXECUTED=NO'
echo 'D1L_DEPLOY_EXECUTED=NO'
echo 'D1L_LIVE_MIGRATIONS_EXECUTED=NO'
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
D1L_CONFIRM_REPOSITORY_IS_DEV=YES python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main_d1l_o5_restic_metadata_gate.py"
