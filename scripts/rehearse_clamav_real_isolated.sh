#!/usr/bin/env bash
# C-FICHA: real scanner smoke with harmless EICAR test string; no live data.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
IMAGE="clamav/clamav:stable"
TMP="$(mktemp -d /tmp/vencira-clamav-e2e.XXXXXXXX)"
LOG="$(mktemp /tmp/vencira-clamav-e2e.XXXXXXXX.log)"
cleanup() { rm -rf -- "$TMP"; }
trap cleanup EXIT
printf 'Synthetic clean test fixture only.\n' > "$TMP/clean.txt"
# Official EICAR antivirus test pattern; no executable or actual malware.
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$TMP/eicar.txt"
test "$(LC_ALL=C wc -c < "$TMP/eicar.txt" | tr -d "[:space:]")" = 68 || { echo "CLAMAV_EICAR_FIXTURE_INVALID=1"; exit 1; }
echo "CLAMAV_EICAR_FIXTURE_BYTES=68"
chmod 755 "$TMP"
chmod 644 "$TMP"/*.txt
echo "CLAMAV_NO_LIVE_DATA=1"
echo "CLAMAV_IMAGE=$IMAGE"
# Only the image pull uses a registry connection. Scanner itself has no network.
sudo docker pull "$IMAGE" > "$LOG" 2>&1
echo "CLAMAV_IMAGE_PULL=OK"
set +e
sudo docker run --rm --network none --read-only \
  --memory 4g --cpus 1.5 --pids-limit 128 \
  --cap-drop ALL --security-opt no-new-privileges \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
  --mount "type=bind,src=$TMP,dst=/fixtures,readonly" \
  --entrypoint clamscan "$IMAGE" --no-summary /fixtures > "$LOG" 2>&1
RC=$?
set -e
# Exactly one signature detection is expected: clamscan return code 1.
if [ "$RC" -ne 1 ]; then
  echo "CLAMAV_SCAN=FAIL_EXIT_$RC"
  tail -n 25 "$LOG"
  exit 1
fi
if ! grep -Eq '^/fixtures/clean.txt: OK$' "$LOG"; then
  echo "CLAMAV_CLEAN_FIXTURE=FAILED"; tail -n 25 "$LOG"; exit 1
fi
if ! grep -Eq '^/fixtures/eicar.txt: .* FOUND$' "$LOG"; then
  echo "CLAMAV_EICAR_DETECTION=FAILED"; tail -n 25 "$LOG"; exit 1
fi
echo "CLAMAV_CLEAN_FIXTURE=OK"
echo "CLAMAV_EICAR_DETECTION=OK"
echo "CLAMAV_CONTAINER_NETWORK_DISABLED=1"
echo "CLAMAV_NO_PRODUCTION_CHANGE=1"
echo "CLAMAV_REAL_ISOLATED_RESULT=0"
