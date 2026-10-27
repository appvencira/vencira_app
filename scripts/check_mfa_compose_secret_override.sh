#!/usr/bin/env bash
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
# Synthetic placeholders only; never inspect or print real keys.
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
VENCIRA_MFA_SECRET_HOST_FILE=/tmp/vencira-synthetic-key-placeholder \
POSTGRES_DB=synthetic POSTGRES_USER=synthetic POSTGRES_PASSWORD=synthetic \
DJANGO_SECRET_KEY=synthetic-placeholder-only-not-for-running \
sudo -E docker compose -f compose.yaml -f compose.mfa-secrets.yaml config --format json >"$out"
python3 - "$out" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf8") as stream:
    cfg = json.load(stream)
api = cfg["services"]["api"]
assert api["environment"]["VENCIRA_MFA_FERNET_KEYS_FILE"] == "/run/secrets/vencira-mfa"
assert api["environment"]["VENCIRA_MFA_ENROLLMENT_ENABLED"] == "0"
mounts = [v for v in api["volumes"] if v["target"] == "/run/secrets/vencira-mfa"]
assert len(mounts) == 1 and mounts[0]["read_only"] is True
assert mounts[0]["type"] == "bind"
print("MFA_COMPOSE_OPTIONAL_MOUNT=OK")
print("MFA_ENROLLMENT_DISABLED=OK")
print("NO_DEPLOY_NO_MIGRATION=1")
PY
