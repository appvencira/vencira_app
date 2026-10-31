#!/usr/bin/env bash
# M1-03: single new-only split-model deletion and API-view rehearsal.
# All SQL and synthetic data in newly created PG17; never touch DEV/O5.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB="mb1_m103_split_db_$$_$RANDOM"
NET="mb1_m103_split_net_$$_$RANDOM"
IMG=""
DB_CREATED=0; NET_CREATED=0; IMG_CREATED=0
docker_cmd() { sudo docker "$@"; }
finish() {
  rc=$?
  trap - EXIT
  if [ "$DB_CREATED" = 1 ]; then
    docker_cmd rm -fv "$DB" >/dev/null 2>&1 || rc=1
  fi
  if [ "$NET_CREATED" = 1 ]; then
    docker_cmd network rm "$NET" >/dev/null 2>&1 || rc=1
  fi
  if [ "$IMG_CREATED" = 1 ]; then
    docker_cmd image rm "$IMG" >/dev/null 2>&1 || true
  fi
  echo "MB1_M103_SPLIT_GROUP_PHASE=$PHASE"
  echo "MB1_M103_SPLIT_GROUP_RESULT=$rc"
  echo "MB1_M103_SPLIT_RUNTIME_OMISSION=TEST_ONLY"
  echo "MB1_M103_FULL_HTTP_MIDDLEWARE=NOT_VERIFIED"
  echo "MB1_M103_HISTORICAL_DATA_TRANSITION=NOT_IMPLEMENTED"
  echo "MB1_M103_LIVE_SCHEMA_CHANGE=NOT_AUTHORIZED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "C_FICHA_RELEASE_AUTHORIZED=NO"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "$(printenv MB1_M103_SPLIT_DELETE_LAB || true)" = YES ] || {
  echo "MB1_M103_SPLIT_LAB_OPT_IN=REQUIRED"; exit 2;
}
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
python3 -m py_compile backend/config/settings.py backend/reminders/models.py \
  backend/renewal_attachments/offline_mb1_m103_split_delete_lab.py
echo "MB1_M103_SPLIT_SOURCE_PREFLIGHT=OK"

PHASE=BUILD
IMG="vencira-mb1-m103-split:$(git rev-parse --short=12 HEAD)-$$"
docker_cmd build -q -t "$IMG" ./backend >/dev/null
IMG_CREATED=1
echo "MB1_M103_SPLIT_IMAGE_BUILD=OK"

PHASE=CREATE
docker_cmd network create --internal "$NET" >/dev/null
NET_CREATED=1
docker_cmd run -d --name "$DB" --network "$NET" \
 -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
 -e POSTGRES_PASSWORD=mb1-split-synthetic-admin-only \
 postgres:17-alpine >/dev/null
DB_CREATED=1
ready=0
for _ in $(seq 1 50); do
  if docker_cmd exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
[ "$ready" = 1 ]
echo "MB1_M103_SPLIT_POSTGRES17_INTERNAL_ONLY=OK"

app() {
  local app_user="$1" app_password="$2"
  shift 2
  docker_cmd run --rm --network "$NET" \
    -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
    -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
    -e VENCIRA_M103_SPLIT_DELETE_LAB=1 \
    -e DJANGO_SECRET_KEY=mb1-split-synthetic-django-secret-over-32-characters \
    -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
    -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 \
    -e POSTGRES_USER="$app_user" -e POSTGRES_PASSWORD="$app_password" \
    "$IMG" python "$@"
}

PHASE=SCHEMA
# Explicit migration targets. No global migrate or reminders.0019-0027.
app mb1 mb1-split-synthetic-admin-only manage.py migrate reminders 0018_draft_reasons --noinput >/dev/null
app mb1 mb1-split-synthetic-admin-only manage.py migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
app mb1 mb1-split-synthetic-admin-only manage.py migrate sessions --noinput >/dev/null
echo "MB1_M103_SPLIT_INDEPENDENT_SCHEMA_WITHOUT_MFA=OK"

PHASE=ROLES
docker_cmd exec -i "$DB" psql -X -q -v ON_ERROR_STOP=1 -U mb1 -d mb1 >/dev/null <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE ROLE mb1_app_limited LOGIN PASSWORD 'mb1-split-synthetic-app-only';
GRANT CONNECT ON DATABASE mb1 TO mb1_app_limited;
GRANT USAGE ON SCHEMA public TO mb1_app_limited;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mb1_app_limited;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mb1_app_limited;
SQL
echo "MB1_M103_SPLIT_LIMITED_ROLE_READY=OK"

PHASE=REAL_ORM
app mb1_app_limited mb1-split-synthetic-app-only \
 -m renewal_attachments.offline_mb1_m103_split_delete_lab
echo "MB1_M103_SPLIT_DJANGO_NONADMIN_DELETE_AND_API=OK"
PHASE=DONE
echo "MB1_M103_SPLIT_GROUP_DONE=OK"
