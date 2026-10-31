#!/usr/bin/env bash
# M1-03: actual Django ORM under limited PG17 login in a fresh Docker network.
# No DEV/O5 volumes or exposed ports; lab DB destroyed on exit.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB="mb1_m103_django_db_$$_$RANDOM"
NET="mb1_m103_django_net_$$_$RANDOM"
IMG="vencira-mb1-m103-orm:$(git -C /home/vencira/vencira-localcheck rev-parse --short=12 HEAD)-$$"
DB_CREATED=0
NET_CREATED=0
IMAGE_CREATED=0
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
  if [ "$IMAGE_CREATED" = 1 ]; then
    docker_cmd image rm "$IMG" >/dev/null 2>&1 || true
  fi
  echo "MB1_M103_DJANGO_PG17_PHASE=$PHASE"
  echo "MB1_M103_DJANGO_PG17_RESULT=$rc"
  echo "MB1_M103_DJANGO_HTTP_COMPATIBILITY=NOT_VERIFIED"
  echo "MB1_M103_LIVE_CREDENTIAL_MIGRATION=NOT_AUTHORIZED"
  echo "MB1_M103_FULL_WRITER_EXCLUSION=NOT_VERIFIED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "$(printenv MB1_M103_DJANGO_PG17_LAB || true)" = YES ] || {
  echo "MB1_M103_DJANGO_PG17_OPT_IN=REQUIRED"; exit 2;
}
cd /home/vencira/vencira-localcheck
[ "$(git branch --show-current)" = feature/c-ficha-independent-attachments ]
git diff --quiet
git diff --cached --quiet
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
command -v docker >/dev/null
command -v sudo >/dev/null
command -v python3 >/dev/null
python3 -m py_compile backend/reminders/offline_mb1_m103_limited_orm_lab.py
docker_cmd info >/dev/null
echo "MB1_M103_DJANGO_SOURCE_PREFLIGHT=OK"

PHASE=BUILD
docker_cmd build -q -t "$IMG" ./backend >/dev/null
IMAGE_CREATED=1
echo "MB1_M103_DJANGO_IMAGE_BUILD=OK"
PHASE=PG17
docker_cmd network create --internal "$NET" >/dev/null
NET_CREATED=1
docker_cmd run -d --name "$DB" --network "$NET" \
  -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 \
  -e POSTGRES_PASSWORD=mb1-only-synthetic-admin-password \
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
echo "MB1_M103_DJANGO_PG17_INTERNAL_ONLY=OK"

app() {
  local app_user="$1" app_password="$2"
  shift 2
  docker_cmd run --rm --network "$NET" \
    -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
    -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
    -e MB1_M103_DJANGO_LAB=YES \
    -e DJANGO_SECRET_KEY=mb1-synthetic-django-orm-secret-more-than-32-chars \
    -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
    -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 \
    -e POSTGRES_USER="$app_user" -e POSTGRES_PASSWORD="$app_password" \
    "$IMG" python manage.py "$@"
}
PHASE=MIGRATIONS
app mb1 mb1-only-synthetic-admin-password migrate reminders 0018_draft_reasons --noinput >/dev/null
app mb1 mb1-only-synthetic-admin-password migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
app mb1 mb1-only-synthetic-admin-password migrate sessions --noinput >/dev/null
echo "MB1_M103_DJANGO_REAL_MIGRATIONS_TEMP_ONLY=OK"

PHASE=GRANTS
docker_cmd exec -i "$DB" psql -X -q -v ON_ERROR_STOP=1 -U mb1 -d mb1 >/dev/null <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE ROLE mb1_app_limited LOGIN PASSWORD 'mb1-only-synthetic-app-password';
GRANT CONNECT ON DATABASE mb1 TO mb1_app_limited;
GRANT USAGE ON SCHEMA public TO mb1_app_limited;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mb1_app_limited;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mb1_app_limited;
SQL
echo "MB1_M103_DJANGO_LIMITED_ROLE_GRANTED=OK"

PHASE=ORM
docker_cmd run --rm --network "$NET" \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
  -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e MB1_M103_DJANGO_LAB=YES \
  -e DJANGO_SECRET_KEY=mb1-synthetic-django-orm-secret-more-than-32-chars \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 \
  -e POSTGRES_USER=mb1_app_limited \
  -e POSTGRES_PASSWORD=mb1-only-synthetic-app-password \
  "$IMG" python -m reminders.offline_mb1_m103_limited_orm_lab
PHASE=DONE
echo "MB1_M103_DJANGO_LIMITED_PG17_ORM_PARTIAL=OK"
echo "MB1_M103_RENEWAL_DELETE=BLOCKED_BY_MFA_GATED_0027"
