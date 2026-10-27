#!/usr/bin/env bash
# O9b controlled deployment: explicit 0016 on DEV only after restorable O5 backup.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
# Shared MFA guard: fail closed before modifying services or schema.
bash scripts/mfa_legacy_deploy_guard_readonly.sh schema
PHASE=INITIAL
LOG="$(mktemp /tmp/vencira-o9b-deploy.XXXXXXXX.log)"
RUN="$(date -u +%Y%m%dT%H%M%SZ)_$$"
MIGRATION_STARTED=0
API_RECREATED=0
OLD_API_TAG=""
RECEIPT=""
finish() {
 rc=$?
 trap - EXIT
 if [ "$rc" -ne 0 ]; then
  echo "FASE_FALLIDA=$PHASE"
  echo "MIGRACION_PUDO_HABERSE_APLICADO=$MIGRATION_STARTED"
  echo "API_RECREADA=$API_RECREATED"
  echo "NO_REPETIR_SIN_VERIFICAR_ESQUEMA=1"
  echo "NO_RESTAURAR_DB_AUTOMATICAMENTE=1"
  echo "LOG_LOCAL=$LOG"
 else
  echo "O9B_0016_API_DESPLIEGUE=OK"
 fi
 if [ -n "$OLD_API_TAG" ]; then echo "IMAGEN_API_ANTERIOR=$OLD_API_TAG"; fi
 if [ -n "$RECEIPT" ]; then echo "RECIBO_LOCAL=$RECEIPT"; fi
 echo "RESULTADO_GLOBAL=$rc"
 echo "SIN_REINICIO_POSTGRES=1"
 echo "SIN_CAMBIOS_CADDY_OAUTH_TIMERS=1"
 echo "CONSOLA_ABIERTA"
 exit "$rc"
}
trap finish EXIT
step() { PHASE="$1"; shift; echo "=== $PHASE ==="; "$@" >>"$LOG" 2>&1 && echo "$PHASE=OK"; }
PHASE=IDENTITY
test "$(id -u)" -eq 0
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
for cmd in docker git restic rclone curl; do command -v "$cmd" >/dev/null; done
VALIDATED=d2e1214f4c32f98c6b833405b65134aa4f017c16
git cat-file -e "$VALIDATED^{commit}"
git diff --quiet "$VALIDATED" HEAD -- backend clients compose.yaml compose.preview.yaml deploy
echo "FUENTES_IDENTICAS_PREFLIGHT=OK"
echo "COMMIT=$(git rev-parse HEAD)"
COMPOSE=(docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml)
step COMPOSE_CONFIG "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" config --format json | python3 -c 'import json,sys;c=json.load(sys.stdin)["services"]["api"]["command"];c=" ".join(c) if isinstance(c,list) else c;assert "migrate --check --noinput" in c; assert "migrate --noinput" not in c' >>"$LOG" 2>&1
echo "MIGRATE_CHECK_ONLY=OK"
DB=vencira_localcheck-db-1
API=vencira_localcheck-api-1
for svc in api db web_preview; do
 name="vencira_localcheck-$svc-1"
 test "$(docker inspect "$name" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
 test "$(docker inspect "$name" --format '{{.State.Health.Status}}')" = healthy
done
DB_ID="$(docker inspect "$DB" --format '{{.Id}}')"
OLD_API_ID="$(docker inspect "$API" --format '{{.Image}}')"
case "$(docker inspect "$API" --format '{{json .Config.Cmd}}')" in *"migrate --check --noinput"*) ;; *) echo "ERROR=API_NOT_CHECK_ONLY"; exit 3;; esac
sql_read() { docker exec "$DB" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"; }
LAST="SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;"
test "$(sql_read "$LAST")" = 0015_renewal_reminder_drafts
COUNT="$(sql_read 'SELECT COUNT(*) FROM django_migrations;')"
echo "POSTGRES_0015_PRE=OK"
step O5_READ_ONLY bash scripts/o5_verify_active_schedule.sh
grep -Fxq 'AUDITORIA_FINAL_O5=OK' "$LOG"
grep -Fxq 'ULTIMO_SNAPSHOT_MENOS_36H=SI' "$LOG"
grep -Fxq 'COPIA_TRAS_REAUTORIZACION=SI' "$LOG"
echo "O5_BACKUP_VERIFICADO=OK"
PHASE=PRESERVE_IMAGE
docker image inspect "$OLD_API_ID" >/dev/null
OLD_API_TAG="vencira-o9b-pre-api:$RUN"
step TAG_PREVIOUS_API docker tag "$OLD_API_ID" "$OLD_API_TAG"
RECEIPT="$(mktemp /tmp/vencira-o9b-deploy.XXXXXXXX.receipt)"
chmod 600 "$RECEIPT"
printf 'VALIDATED_SHA=%s\nPREVIOUS_API=%s\nDB_ID=%s\n' "$VALIDATED" "$OLD_API_TAG" "$DB_ID" > "$RECEIPT"
step BUILD_NEW_API "${COMPOSE[@]}" build api
step MIGRATION_PLAN "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate reminders 0016_renewal_control_responses --plan
grep -Fq '0016_renewal_control_responses' "$LOG"
test "$DB_ID" = "$(docker inspect "$DB" --format '{{.Id}}')"
test "$OLD_API_ID" = "$(docker inspect "$API" --format '{{.Image}}')"
echo "BUILD_PLAN_SIN_DEPLOY=OK"
step FRESH_ENCRYPTED_O5 bash scripts/o5_backup_to_drive.sh
grep -Fxq 'GOOGLE_DRIVE_BACKUP_CIFRADO=OK' "$LOG"
grep -Fxq 'RESTIC_INTEGRIDAD_METADATA=OK' "$LOG"
echo "BACKUP_O5_PRE0016_FRESCO=OK"
printf 'FRESH_O5_BACKUP=OK\n' >>"$RECEIPT"
PHASE=APPLY_0016
MIGRATION_STARTED=1
step APPLY_0016 "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate reminders 0016_renewal_control_responses --noinput
PHASE=VERIFY_0016
test "$(sql_read "$LAST")" = 0016_renewal_control_responses
test "$(sql_read 'SELECT COUNT(*) FROM django_migrations;')" = "$((COUNT+1))"
test "$(sql_read "SELECT to_regclass('public.reminders_renewalcontrolresponse') IS NOT NULL;")" = t
test "$(sql_read 'SELECT COUNT(*) FROM reminders_renewalcontrolresponse;')" = 0
echo "POSTGRES_0016_VERIFICADO=OK"
step POST_MIGRATE_CHECK "${COMPOSE[@]}" run --rm --no-deps api python manage.py migrate --check --noinput
PHASE=DEPLOY_API
API_RECREATED=1
step DEPLOY_API "${COMPOSE[@]}" up -d --no-deps --no-build --force-recreate api
PHASE=API_HEALTH
healthy=starting
for i in $(seq 1 40); do
 healthy="$(docker inspect "$API" --format '{{.State.Health.Status}}')"
 if [ "$healthy" = healthy ] || [ "$healthy" = unhealthy ]; then break; fi
 sleep 5
done
test "$healthy" = healthy
echo "HEALTH_api=healthy"
PHASE=FINAL_CHECKS
test "$DB_ID" = "$(docker inspect "$DB" --format '{{.Id}}')"
test "$(sql_read "$LAST")" = 0016_renewal_control_responses
test "$(docker inspect vencira_localcheck-web_preview-1 --format '{{.State.Health.Status}}')" = healthy
test "$(docker inspect "$DB" --format '{{.State.Health.Status}}')" = healthy
for url in / /api/health/ /api/ready/; do
 code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732$url")"
 test "$code" = 200
done
uuid1=11111111-1111-4111-8111-111111111111
uuid2=b2222222-2222-4222-8222-222222222222
anon="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "http://127.0.0.1:28732/api/v1/workspaces/$uuid1/renewals/$uuid2/control-responses/")"
test "$anon" = 401 || test "$anon" = 403
echo "CONTROL_RESPONSES_ANON_HTTP=$anon"
echo "POSTGRES_INTACTO_ID=OK"
printf 'MIGRATION_0016=OK\nAPI_O9B=OK\n' >> "$RECEIPT"
