#!/usr/bin/env bash
# New-only PG17 coexistence rehearsal; no DEV, no MFA migrations.
set -Eeuo pipefail
umask 077
PHASE=PRECHECK
DB="mb1_pa_coexist_db_$$_$RANDOM"; NET="mb1_pa_coexist_net_$$_$RANDOM"; IMG=""
DB_CREATED=0; NET_CREATED=0; IMG_CREATED=0
d() { sudo docker "$@"; }
finish() {
 rc=$?
 trap - EXIT
 if [ "$DB_CREATED" = 1 ]; then d rm -fv "$DB" >/dev/null 2>&1 || rc=1; fi
 if [ "$NET_CREATED" = 1 ]; then d network rm "$NET" >/dev/null 2>&1 || rc=1; fi
 if [ "$IMG_CREATED" = 1 ]; then d image rm "$IMG" >/dev/null 2>&1 || true; fi
 echo "MB1_PA_COEXIST_PHASE=$PHASE"
 echo "MB1_PA_COEXIST_RESULT=$rc"
 echo "MB1_PA_HISTORICAL_0027_REAL_MIGRATION=NOT_RUN"
 echo "MB1_PA_REAL_ENCRYPTED_STORE=NOT_RUN"
 echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
 echo "MB1_RELEASE_AUTHORIZED=NO"
 echo "MFA_RELEASE_AUTHORIZED=NO"
 echo "C_FICHA_RELEASE_AUTHORIZED=NO"
 echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
 exit "$rc"
}
trap finish EXIT
[ "${MB1_PA_COEXIST_OPT_IN:-}" = YES ] || { echo "PA_COEXIST_OPT_IN_REQUIRED"; exit 2; }
[ -f backend/renewal_attachments/offline_mb1_pa_coexist_lab.py ]
python3 -m py_compile backend/renewal_attachments/offline_mb1_pa_coexist_lab.py
echo "MB1_PA_COEXIST_PREFLIGHT=OK"
PHASE=BUILD
IMG="vencira-mb1-pa-coexist:$$"
d build -q -t "$IMG" ./backend >/dev/null
IMG_CREATED=1
PHASE=CREATE
d network create --internal "$NET" >/dev/null
NET_CREATED=1
d run -d --name "$DB" --network "$NET" -e POSTGRES_USER=mb1 -e POSTGRES_DB=mb1 -e POSTGRES_PASSWORD=pa-coexist-synthetic postgres:17-alpine >/dev/null
DB_CREATED=1
ready=0
for _ in $(seq 1 50); do
 if d exec "$DB" pg_isready -U mb1 -d mb1 >/dev/null 2>&1; then ready=1; break; fi
 sleep 1
done
[ "$ready" = 1 ]
echo "MB1_PA_COEXIST_PG17_INTERNAL=OK"
app() {
 d run --rm --network "$NET" \
   -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
   -e VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1 -e VENCIRA_M103_SPLIT_DELETE_LAB=0 \
   -e DJANGO_SECRET_KEY=synthetic-pa-coexist-secret-longer-than-32-characters \
   -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
   -e POSTGRES_HOST="$DB" -e POSTGRES_DB=mb1 \
   -e POSTGRES_USER=mb1 -e POSTGRES_PASSWORD=pa-coexist-synthetic \
   "$IMG" python "$@"
}
PHASE=SCHEMA
app manage.py migrate reminders 0018_draft_reasons --noinput >/dev/null
app manage.py migrate renewal_attachments 0006_ed25519_signature_length --noinput >/dev/null
app manage.py migrate auth --noinput >/dev/null
PHASE=COEXIST
app -m renewal_attachments.offline_mb1_pa_coexist_lab
PHASE=DONE
echo "MB1_PA_COEXIST_LAB=OK"
