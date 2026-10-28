#!/usr/bin/env bash
# No live services, no persistent DB, no operational Fernet material.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = "integration/local-e2e-prep"
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
TMP="$(mktemp -d /tmp/vencira-mfa-fernet-synthetic.XXXXXXXX)"
IMAGE="vencira-mfa-fernet-synthetic:$(git rev-parse --short=12 HEAD)"
cleanup() {
  rc=$?
  trap - EXIT
  sudo rm -rf -- "$TMP"
  echo "FERNET_DOCKER_RESULT=$rc"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
chmod 755 "$TMP"
python3 - "$TMP/mfa-key" <<'PY'
import base64, os, secrets, sys
key = base64.urlsafe_b64encode(secrets.token_bytes(32))
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'wb') as f:
    f.write(key + b'\n')
PY
sudo docker build -q -t "$IMAGE" ./backend >/dev/null
UID_API="$(sudo docker run --rm --network none --entrypoint id "$IMAGE" -u)"
test "$UID_API" -ne 0
sudo chown "$UID_API:$UID_API" "$TMP/mfa-key"
sudo docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --mount "type=bind,src=$TMP/mfa-key,dst=/run/secrets/vencira-mfa,readonly" \
  -e VENCIRA_MFA_FERNET_KEYS_FILE=/run/secrets/vencira-mfa \
  --entrypoint python "$IMAGE" -c '
from pathlib import Path
from reminders.mfa_key_config import load_mfa_keys
from reminders.mfa_secrets import encrypt_totp_secret, decrypt_totp_secret
path = Path("/run/secrets/vencira-mfa")
assert path.is_file()
keys = load_mfa_keys()
assert len(keys) == 1
token = encrypt_totp_secret("SYNTHETIC-TOTP-ONLY", user_id=42, keys=keys)
assert decrypt_totp_secret(token, user_id=42, keys=keys) == "SYNTHETIC-TOTP-ONLY"
try:
    decrypt_totp_secret(token, user_id=43, keys=keys)
except ValueError:
    pass
else:
    raise AssertionError("cross-account secret accepted")
print("MFA_DOCKER_SECRET_NONROOT=OK")
print("MFA_FERNET_SYNTHETIC_ROUNDTRIP=OK")
print("MFA_NO_CROSS_USER_DECRYPT=OK")
'
