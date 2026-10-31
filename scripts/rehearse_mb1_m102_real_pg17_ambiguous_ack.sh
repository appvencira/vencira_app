#!/usr/bin/env bash
# M1-02: only new real PG17 commit/rollback ACK-ambiguity rehearsal.
# All databases, volumes, network and Django app are isolated and disposable.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
NET="mb1_ack_net_$$_$RANDOM"
DB="mb1_ack_db_$$_$RANDOM"
V_OBJ="mb1_ack_obj_$$_$RANDOM"
V_JOURNAL="mb1_ack_journal_$$_$RANDOM"
IMG="vencira-mb1-ack:$(date +%s)-$$"
net=0; db=0; obj=0; journal=0; image=0
finish() {
  rc=$?
  trap - EXIT
  if [ "$db" = 1 ]; then docker rm -f "$DB" >/dev/null 2>&1 || rc=1; fi
  if [ "$net" = 1 ]; then docker network rm "$NET" >/dev/null 2>&1 || rc=1; fi
  if [ "$obj" = 1 ]; then docker volume rm "$V_OBJ" >/dev/null 2>&1 || rc=1; fi
  if [ "$journal" = 1 ]; then docker volume rm "$V_JOURNAL" >/dev/null 2>&1 || rc=1; fi
  if [ "$image" = 1 ]; then docker image rm "$IMG" >/dev/null 2>&1 || true; fi
  echo "MB1_M102_REAL_PG17_PHASE=$PHASE"
  echo "MB1_M102_REAL_PG17_RESULT=$rc"
  echo "MB1_M102_REAL_POWERLOSS=NOT_VERIFIED"
  echo "MB1_M102_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED"
  echo "MB1_M106_EXTERNAL_CUSTODY=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "$(printenv MB1_M102_REAL_PG17_LAB || true)" = YES ] || { echo "MB1_M102_EXPLICIT_LAB_OPT_IN=REQUIRED"; exit 2; }
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
for cmd in docker git python3; do command -v "$cmd" >/dev/null; done
python3 -m py_compile backend/renewal_attachments/offline_mb1_pg17_ambiguous_commit_drill.py
docker info >/dev/null
echo "MB1_M102_PG17_PRECHECK=OK"

PHASE=BUILD
docker build -q -t "$IMG" ./backend >/dev/null
image=1
echo "MB1_M102_PG17_IMAGE_BUILD=OK"

PHASE=CREATE
docker volume create "$V_OBJ" >/dev/null; obj=1
docker volume create "$V_JOURNAL" >/dev/null; journal=1
docker network create --internal "$NET" >/dev/null; net=1
docker run -d --name "$DB" --network "$NET" \
 -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 -e POSTGRES_PASSWORD=synthetic-only \
 postgres:17-alpine >/dev/null
db=1
ready=0
for _ in $(seq 1 50); do
  if docker exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ]
echo "MB1_M102_PG17_DISPOSABLE_DATABASE=OK"

PHASE=VOLUMES
APP_UID="$(docker run --rm --network none "$IMG" id -u)"
APP_GID="$(docker run --rm --network none "$IMG" id -g)"
[[ "$APP_UID" =~ ^[0-9]+$ && "$APP_GID" =~ ^[0-9]+$ ]]
docker run --rm --network none --user 0:0 \
 --mount "type=volume,source=$V_OBJ,target=/lab/objects" \
 --mount "type=volume,source=$V_JOURNAL,target=/lab/journal" \
 -e LAB_UID="$APP_UID" -e LAB_GID="$APP_GID" \
 python:3.12-alpine sh -ec \
 'chown "$LAB_UID:$LAB_GID" /lab/objects /lab/journal; chmod 0700 /lab/objects /lab/journal' >/dev/null
echo "MB1_M102_PG17_PRIVATE_VOLUMES=OK"

app() {
 docker run --rm --network "$NET" \
  -e VENCIRA_ENV=test -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e MB1_DISPOSABLE_ONLY=1 -e VENCIRA_DB_ENGINE=postgresql \
  -e DJANGO_SECRET_KEY=mb1-synthetic-ack-django-secret-long-enough-only \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 \
  -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=synthetic-only \
  --mount "type=volume,source=$V_OBJ,target=/lab/objects" \
  --mount "type=volume,source=$V_JOURNAL,target=/lab/journal" \
  "$IMG" "$@"
}

PHASE=SCHEMA
app python manage.py migrate reminders 0018_draft_reasons --noinput >/dev/null
app python manage.py migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
echo "MB1_M102_PG17_TEMP_MIGRATIONS=OK"

PHASE=AMBIGUOUS_WRITE
app python -m renewal_attachments.offline_mb1_pg17_ambiguous_commit_drill write
PHASE=INDEPENDENT_VERIFY
app python -m renewal_attachments.offline_mb1_pg17_ambiguous_commit_drill verify
PHASE=DONE
echo "MB1_M102_REAL_PG17_AMBIGUOUS_COMMIT_GATE=OK"
