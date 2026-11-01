#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[ "${MB1_PB_CRYPTO_OPT_IN:-}" = YES ] || exit 2
cd "$(dirname "$0")/.."
python3 -m py_compile backend/renewal_attachments/offline_mb1_pb_encrypted_pg17.py
DB="mb1_pb_crypto_db_$$"; NET="mb1_pb_crypto_net_$$"; IMG="vencira-pb-crypto:$$"
phase=BUILD
cleanup() {
 rc=$?
 trap - EXIT
 sudo docker rm -fv "$DB" >/dev/null 2>&1 || true
 sudo docker network rm "$NET" >/dev/null 2>&1 || true
 sudo docker image rm "$IMG" >/dev/null 2>&1 || true
 echo "MB1_PB_CRYPTO_PHASE=$phase"
 echo "MB1_PB_CRYPTO_RESULT=$rc"
 echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
 echo "MB1_RELEASE_AUTHORIZED=NO"
 echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
 exit "$rc"
}
trap cleanup EXIT
sudo docker build -q -t "$IMG" ./backend >/dev/null
phase=CREATE
sudo docker network create --internal "$NET" >/dev/null
sudo docker run -d --name "$DB" --network "$NET" -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 -e POSTGRES_PASSWORD=synthetic-pb-only postgres:17-alpine >/dev/null
ready=0
for i in $(seq 1 50); do
 if sudo docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
 sleep 1
done
[ "$ready" = 1 ]
app() {
 sudo docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
 -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 -e VENCIRA_M103_SPLIT_DELETE_LAB=0 \
 -e DJANGO_SECRET_KEY=synthetic-pb-only-long-django-secret \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 -e POSTGRES_USER=mb1 \
 -e POSTGRES_PASSWORD=synthetic-pb-only "$IMG" python "$@"
}
phase=SCHEMA
app manage.py migrate reminders 0018_draft_reasons --noinput >/dev/null
app manage.py migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
app manage.py migrate auth --noinput >/dev/null
phase=VERIFY
app -m renewal_attachments.offline_mb1_pb_encrypted_pg17
phase=DONE
echo "MB1_PB_CRYPTO_GROUP=OK"
