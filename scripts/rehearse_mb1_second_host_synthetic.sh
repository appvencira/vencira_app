#!/usr/bin/env bash
# MB1 independent-host rehearsal. Run ONLY on an independent recovery host
# with a synthetic MB1 package and independently supplied synthetic keys.
set -Eeuo pipefail
umask 077
fail() { echo "MB1_SECOND_HOST_PHASE=$phase"; echo "MB1_SECOND_HOST_RESULT=1"; exit 1; }
phase=PREFLIGHT
trap fail ERR
[ "${MB1_CONFIRM_INDEPENDENT_HOST:-}" = "YES_SYNTHETIC_ONLY" ] || { echo "Independent host confirmation required"; exit 2; }
[ "$#" -eq 3 ] || { echo "Usage: $0 PACKAGE_DIRECTORY KEY_DIRECTORY BACKEND_IMAGE"; exit 2; }
PACKAGE="$1"; KEYS="$2"; IMG="$3"
[ -d "$PACKAGE" ] && [ -d "$KEYS" ] && [ ! -L "$PACKAGE" ] && [ ! -L "$KEYS" ]
[ "$(realpath "$PACKAGE")" != "$(realpath "$KEYS")" ]
[ "$(stat -c '%a' "$PACKAGE")" = 700 ]
[ "$(stat -c '%a' "$KEYS")" = 700 ]
for f in capture.enc manifest.json manifest.mac; do [ -f "$PACKAGE/$f" ] && [ ! -L "$PACKAGE/$f" ]; done
for f in encryption.key authentication.key; do [ -f "$KEYS/$f" ] && [ ! -L "$KEYS/$f" ]; done
command -v docker >/dev/null
case "$IMG" in *:latest|"") echo "Use a pinned backend image digest or tag"; exit 2;; esac
phase=SETUP
ID="vencira_mb1_second_$$_$RANDOM"
DB="$ID"; RUN_DIR="$(mktemp -d /tmp/vencira-mb1-second-host.XXXXXXXX)"
cleanup() {
 rc=$?; trap - ERR EXIT
 docker rm -f "$DB" >/dev/null 2>&1 || true
 rm -rf -- "$RUN_DIR"
 echo "MB1_SECOND_HOST_RESULT=$rc"
 echo "MB1_EXTERNAL_KEY_CUSTODY=REQUIRES_MANUAL_ATTESTATION"
 echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
 echo "MB1_RELEASE_AUTHORIZED=NO"
 exit "$rc"
}
trap cleanup EXIT
phase=NO_KEYS_NEGATIVE
# Package alone must not be sufficient to decrypt.
mkdir -m 700 "$RUN_DIR/empty"
if docker run --rm --network none --user "$(id -u):$(id -g)" \
 --mount "type=bind,source=$(realpath "$PACKAGE"),target=/capture,readonly" \
 --mount "type=bind,source=$RUN_DIR/empty,target=/keymedia,readonly" \
 -e VENCIRA_ENV=test -e MB1_DISPOSABLE_ONLY=1 -e MB1_SYNTHETIC_KEY_ROOT=/keymedia \
 "$IMG" python -m renewal_attachments.mb1_e2e_authenticated_pack detached_stream /capture >/dev/null 2>&1; then
 echo "MB1_SECOND_HOST_NO_KEYS=UNEXPECTED_SUCCESS"; exit 1
fi
echo "MB1_SECOND_HOST_NO_KEYS=REJECTED"
phase=PG17
docker run -d --name "$DB" --network none \
 -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
 -e POSTGRES_PASSWORD=synthetic-mb1-only postgres:17-alpine >/dev/null
ready=0
for _ in $(seq 1 40); do
 if docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
 sleep 1
done
[ "$ready" -eq 1 ]
phase=RESTORE
# Package and key mounts are separate; the source host is not contacted.
# Streaming decryption happens in RAM/pipe, not as a plaintext host dump.
docker run --rm --network none --user "$(id -u):$(id -g)" \
 --mount "type=bind,source=$(realpath "$PACKAGE"),target=/capture,readonly" \
 --mount "type=bind,source=$(realpath "$KEYS"),target=/keymedia,readonly" \
 -e VENCIRA_ENV=test -e MB1_DISPOSABLE_ONLY=1 -e MB1_SYNTHETIC_KEY_ROOT=/keymedia \
 "$IMG" python -m renewal_attachments.mb1_e2e_authenticated_pack detached_stream /capture |
 docker exec -i "$DB" pg_restore --exit-on-error --no-owner --no-privileges -U mb1 -d mb1 >/dev/null
phase=VERIFY
COUNT="$(docker exec "$DB" psql -X -A -t -v ON_ERROR_STOP=1 -U mb1 -d mb1 -c \
 "SELECT count(*) FROM renewal_attachments_renewalattachment WHERE display_name='synthetic.pdf' AND state='quarantined';")"
[ "$COUNT" = 1 ]
echo "MB1_SECOND_HOST_PG17_RESTORE=OK"
echo "MB1_SECOND_HOST_PACKAGE_AND_KEYS_SEPARATE=OK"
echo "MB1_SECOND_HOST_SYNTHETIC_RESTORE=OK"
