#!/usr/bin/env bash
# Package A: new-only full HTTP middleware lab; no DEV, no operational migrations.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB="mb1_pa_db_$$_$RANDOM"; NET="mb1_pa_net_$$_$RANDOM"; IMG=""
DB_CREATED=0; NET_CREATED=0; IMG_CREATED=0
docker_cmd() { sudo docker "$@"; }
finish() {
  rc=$?
  trap - EXIT
  if [ "$DB_CREATED" = 1 ]; then docker_cmd rm -fv "$DB" >/dev/null 2>&1 || rc=1; fi
  if [ "$NET_CREATED" = 1 ]; then docker_cmd network rm "$NET" >/dev/null 2>&1 || rc=1; fi
  if [ "$IMG_CREATED" = 1 ]; then docker_cmd image rm "$IMG" >/dev/null 2>&1 || true; fi
  echo "MB1_PA_PHASE=$PHASE"
  echo "MB1_PA_RESULT=$rc"
  echo "MB1_PA_HISTORICAL_BOTH_SCHEMAS=NOT_RUN"
  echo "MB1_PA_NONADMIN_HTTP=$([ "$PHASE" = DONE ] && echo OK || echo NOT_VERIFIED)"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "C_FICHA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap finish EXIT
[ "${MB1_PACKAGE_A_OPT_IN:-}" = YES ] || { echo "MB1_PA_OPT_IN=REQUIRED"; exit 2; }
[ -f backend/renewal_attachments/offline_mb1_package_a_http.py ]
[ -f backend/renewal_attachments/transition_contract.py ]
python3 -m py_compile backend/renewal_attachments/offline_mb1_package_a_http.py backend/renewal_attachments/transition_reconciliation.py
echo "MB1_PA_SOURCE_PREFLIGHT=OK"
PHASE=BUILD
IMG="vencira-mb1-pa:$$"
docker_cmd build -q -t "$IMG" ./backend >/dev/null
IMG_CREATED=1
PHASE=CREATE
docker_cmd network create --internal "$NET" >/dev/null
NET_CREATED=1
docker_cmd run -d --name "$DB" --network "$NET" -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 -e POSTGRES_PASSWORD=synthetic-pa-admin postgres:17-alpine >/dev/null
DB_CREATED=1
ready=0
for _ in $(seq 1 50); do
 if docker_cmd exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
 sleep 1
done
[ "$ready" = 1 ]
echo "MB1_PA_INTERNAL_PG17=OK"
app() {
 local app_user="$1" app_password="$2"
 shift 2
 docker_cmd run --rm --network "$NET" -e VENCIRA_ENV=test \
  -e VENCIRA_DB_ENGINE=postgresql -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 \
  -e VENCIRA_M103_SPLIT_DELETE_LAB=1 \
  -e DJANGO_SECRET_KEY=synthetic-pa-django-secret-long-enough-12345 \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 -e POSTGRES_USER="$app_user" \
  -e POSTGRES_PASSWORD="$app_password" "$IMG" python "$@"
}
PHASE=SCHEMA
app mb1 synthetic-pa-admin manage.py migrate reminders 0018_draft_reasons --noinput >/dev/null
app mb1 synthetic-pa-admin manage.py migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
app mb1 synthetic-pa-admin manage.py migrate auth --noinput >/dev/null
app mb1 synthetic-pa-admin manage.py migrate sessions --noinput >/dev/null
PHASE=BOOTSTRAP
docker_cmd run --rm --network "$NET" \
  -e MB1_PA_SCHEMA_BOOTSTRAP=1 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
  -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 -e VENCIRA_M103_SPLIT_DELETE_LAB=1 \
  -e DJANGO_SECRET_KEY=synthetic-pa-django-secret-long-enough-12345 \
  -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 -e POSTGRES_USER=mb1 \
  -e POSTGRES_PASSWORD=synthetic-pa-admin "$IMG" python -m renewal_attachments.offline_mb1_package_a_http
PHASE=ROLES
docker_cmd exec -i "$DB" psql -X -q -v ON_ERROR_STOP=1 -U mb1 -d mb1 >/dev/null <<'SQL'
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
CREATE ROLE mb1_pa_limited LOGIN PASSWORD 'synthetic-pa-limited';
GRANT CONNECT ON DATABASE mb1 TO mb1_pa_limited;
GRANT USAGE ON SCHEMA public TO mb1_pa_limited;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mb1_pa_limited;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mb1_pa_limited;
SQL
PHASE=HTTP
app mb1_pa_limited synthetic-pa-limited -m renewal_attachments.offline_mb1_package_a_http
PHASE=DONE
echo "MB1_PA_FULL_HTTP_NEW_ONLY=OK"
