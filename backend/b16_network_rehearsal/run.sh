#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck

WORK="$(mktemp -d /tmp/vencira-b16d.XXXXXXXX)"
NET="vencira-b16d-net-$$"
DB="vencira-b16d-db-$$"
RECEIVER="vencira-b16d-receiver-$$"

cleanup() {
  rc=$?
  trap - EXIT
  if [ "$rc" -ne 0 ]; then
    echo "B16D_FAILED=1"
    sudo docker logs --tail 35 "$RECEIVER" 2>/dev/null || true
  fi
  sudo docker rm -f "$RECEIVER" "$DB" >/dev/null 2>&1 || true
  sudo docker network rm "$NET" >/dev/null 2>&1 || true
  sudo rm -rf -- "$WORK"
  echo "B16D_RESULT=$rc"
  echo "B16_OPERATIONAL_RELEASE=NO"
  echo "C_FICHA_RELEASE_AUTHORIZED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT

echo "=== PREFLIGHT ==="
test "$(git rev-parse --short HEAD)" = e8fac47
test "$(git branch --show-current)" = \
  feature/c-ficha-independent-attachments
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"

EXTRA="$(git ls-files --others --exclude-standard |
  grep -vx 'clients/flutter/pubspec.lock' || true)"
test -z "$EXTRA"
echo "B16D_PREFLIGHT=OK"

mkdir -p "$WORK/build" "$WORK/signer" "$WORK/receiver"
chmod 755 "$WORK" "$WORK/build"
chmod 700 "$WORK/signer" "$WORK/receiver"

cp "backend/b16_network_rehearsal/receiver.py" "$WORK/build/receiver.py"

cp "backend/b16_network_rehearsal/signer.py" "$WORK/build/signer.py"

cp "backend/b16_network_rehearsal/Dockerfile.receiver" "$WORK/build/Dockerfile.receiver"

cp "backend/b16_network_rehearsal/Dockerfile.signer" "$WORK/build/Dockerfile.signer"

chmod 644 "$WORK/build/"*

echo "=== IMÁGENES AISLADAS ==="
sudo docker build -q \
  -f "$WORK/build/Dockerfile.receiver" \
  -t vencira-b16d-receiver:local "$WORK/build" >/dev/null
sudo docker build -q \
  -f "$WORK/build/Dockerfile.signer" \
  -t vencira-b16d-signer:local "$WORK/build" >/dev/null
echo "B16D_IMAGES=OK"

echo "=== CLAVES SINTÉTICAS SEPARADAS ==="
python3 - "$WORK" <<'PY'
from pathlib import Path
import secrets
import sys

root = Path(sys.argv[1])
key = secrets.token_bytes(32)

for name in ("signer", "receiver"):
    dest = root / name / "transport.key"
    dest.write_bytes(key)
    dest.chmod(0o644)
PY

sudo chown -R 65532:65532 "$WORK/signer" "$WORK/receiver"
sudo chmod 700 "$WORK/signer" "$WORK/receiver"

sudo docker run --rm --network none \
  --cap-drop ALL --security-opt no-new-privileges \
  --user 65532:65532 \
  --mount "type=bind,src=$WORK/signer,dst=/signer" \
  --mount "type=bind,src=$WORK/receiver,dst=/receiver" \
  vencira-b16d-signer:local init

sudo chmod 600 "$WORK/signer/private.key"
sudo chmod 600 "$WORK/signer/transport.key"
sudo chmod 600 "$WORK/receiver/public.key"
sudo chmod 600 "$WORK/receiver/transport.key"
echo "B16D_KEY_SEPARATION=OK"

echo "=== RED DOCKER INTERNA Y PG17 ==="

sudo docker network create --internal "$NET" >/dev/null
PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"

sudo docker run -d --name "$DB" \
  --network "$NET" --network-alias b16d-db \
  -e POSTGRES_DB=b16d \
  -e POSTGRES_USER=b16d \
  -e POSTGRES_PASSWORD="$PASSWORD" \
  --health-cmd="pg_isready -U b16d -d b16d" \
  --health-interval=2s --health-retries=40 \
  postgres:17-alpine >/dev/null

READY=0
for i in $(seq 1 50); do
  if [ "$(sudo docker inspect -f \
    '{{.State.Health.Status}}' "$DB")" = healthy ]; then
    READY=1
    break
  fi
  sleep 2
done

test "$READY" = 1
echo "B16D_PG17_TEMPORAL=OK"

sudo docker run -d --name "$RECEIVER" \
  --network "$NET" --network-alias b16d-receiver \
  --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 128 \
  -e PYTHONDONTWRITEBYTECODE=1 \
  -e POSTGRES_HOST=b16d-db \
  -e POSTGRES_PASSWORD="$PASSWORD" \
  --mount "type=bind,src=$WORK/receiver,dst=/run/keys,readonly" \
  vencira-b16d-receiver:local >/dev/null

echo "=== PRUEBAS DE TRANSPORTE ==="

sudo docker run --rm \
  --network "$NET" \
  --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 128 \
  -e PYTHONDONTWRITEBYTECODE=1 \
  --mount "type=bind,src=$WORK/signer,dst=/signer,readonly" \
  vencira-b16d-signer:local test

echo "=== VALIDACIÓN FINAL ==="
echo "B16D_INTERNAL_HTTP=OK"
echo "B16D_HMAC_ED25519=OK"
echo "B16D_PG17_ANTIREPLAY=OK"
echo "B16D_SYNTHETIC_NETWORK_GATE=OK"
echo "B16D_EXTERNAL_CUSTODY=NOT_VERIFIED"
echo "B16D_OPERATIONAL_INTEGRATION=NOT_VERIFIED"
