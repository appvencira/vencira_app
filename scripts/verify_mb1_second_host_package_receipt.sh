#!/usr/bin/env bash
# Second-host *synthetic* package receipt preflight; no key access or network.
set -Eeuo pipefail
umask 077
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 PACKAGE_DIR TRUSTED_CHECKSUM_FILE"
  exit 2
fi
PACKAGE="$1"
CHECKSUMS="$(realpath "$2")"
[ -d "$PACKAGE" ] && [ ! -L "$PACKAGE" ]
[ -f "$CHECKSUMS" ] && [ ! -L "$CHECKSUMS" ]
[ "$(stat -c %a "$PACKAGE")" = 700 ]
for f in capture.enc manifest.json manifest.mac; do
  [ -f "$PACKAGE/$f" ] && [ ! -L "$PACKAGE/$f" ]
done
# Restrict checksum input to the three expected package filenames.
python3 - "$CHECKSUMS" <<'PY'
import re, sys
from pathlib import Path
entries=Path(sys.argv[1]).read_text().splitlines()
expected={"capture.enc","manifest.json","manifest.mac"}
if len(entries)!=3:
    raise SystemExit("MB1_RECEIPT_INVALID_ENTRY_COUNT")
seen=set()
for line in entries:
    match=re.fullmatch(r"([a-f0-9]{64})  (capture\.enc|manifest\.json|manifest\.mac)",line)
    if not match or match.group(2) in seen:
        raise SystemExit("MB1_RECEIPT_INVALID_HASH_RECORD")
    seen.add(match.group(2))
if seen!=expected:
    raise SystemExit("MB1_RECEIPT_INCOMPLETE")
PY
(cd "$PACKAGE" && sha256sum --check --status "$CHECKSUMS")
echo "MB1_SECOND_HOST_PACKAGE_RECEIPT=OK"
echo "MB1_SECOND_HOST_KEYS=NOT_CHECKED"
echo "MB1_SECOND_HOST_RESTORE=NOT_RUN"
echo "MB1_EXTERNAL_CUSTODY=NOT_VERIFIED"
echo "MB1_RELEASE_AUTHORIZED=NO"
