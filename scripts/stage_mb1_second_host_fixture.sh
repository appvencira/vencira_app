#!/usr/bin/env bash
# Stage an EXISTING synthetic MB1 E2E backup for transfer over two channels.
# Does NOT contact any external host, contain production keys, or touch DEV.
set -Eeuo pipefail
umask 077
[ "$#" -eq 1 ] || { echo "Usage: $0 /tmp/vencira-mb1-e2e.<run-id>"; exit 2; }
SOURCE="$1"
case "$SOURCE" in /tmp/vencira-mb1-e2e.*) ;; *) echo "SOURCE_NOT_MB1_E2E"; exit 2;; esac
[ -d "$SOURCE" ] && [ ! -L "$SOURCE" ]
[ "$(stat -c '%U' "$SOURCE")" = "$(id -un)" ]
[ "$(stat -c '%a' "$SOURCE")" = 700 ]
for file in capture.enc manifest.json manifest.mac keys/encryption.key keys/authentication.key; do
  [ -f "$SOURCE/$file" ] && [ ! -L "$SOURCE/$file" ]
done
# Explicitly reject any raw dump or non-synthetic origin package.
[ ! -e "$SOURCE/source.dump" ] || { echo "PLAINTEXT_DUMP_PRESENT=ABORT"; exit 1; }
grep -q '"snapshot":"mb1-dual-pg17-synthetic-v1"' "$SOURCE/manifest.json" || {
 echo "NOT_SYNTHETIC_MB1_MANIFEST"; exit 1;
}
OUT="$(mktemp -d /tmp/vencira-mb1-transfer.XXXXXXXX)"
mkdir -m 700 "$OUT/package" "$OUT/keys"
cp -- "$SOURCE/capture.enc" "$SOURCE/manifest.json" "$SOURCE/manifest.mac" "$OUT/package/"
cp -- "$SOURCE/keys/encryption.key" "$SOURCE/keys/authentication.key" "$OUT/keys/"
chmod 600 "$OUT/package/"* "$OUT/keys/"*
[ "$(find "$OUT/package" -maxdepth 1 -type f | wc -l)" -eq 3 ]
[ "$(find "$OUT/keys" -maxdepth 1 -type f | wc -l)" -eq 2 ]
# Public checksum list contains only encrypted package files, NEVER keys.
(cd "$OUT/package" && sha256sum capture.enc manifest.json manifest.mac) > "$OUT/package-checksums.sha256"
chmod 600 "$OUT/package-checksums.sha256"
echo "MB1_TRANSFER_PACKAGE_CHECKSUMS=$OUT/package-checksums.sha256"
echo "MB1_TRANSFER_STAGED_SYNTHETIC=OK"
echo "MB1_TRANSFER_PACKAGE_DIR=$OUT/package"
echo "MB1_TRANSFER_KEY_DIR=$OUT/keys"
echo "MB1_TRANSFER_KEYS_OFF_HOST=NO"
echo "MB1_TRANSFER_SECOND_HOST_VERIFIED=NO"
echo "MB1_RELEASE_AUTHORIZED=NO"
echo "IMPORTANT=TRANSFER_PACKAGE_AND_KEYS_SEPARATELY_AND_DELETE_STAGING_AFTER_VERIFICATION"
