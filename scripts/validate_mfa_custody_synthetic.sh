#!/usr/bin/env bash
# D1.5-S1: test de custodia criptografica MFA, SIN secretos operacionales.
# No consulta PostgreSQL persistente, no restaura O5 y no despliega.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -f backend/reminders/test_mfa_key_config.py
test -f backend/reminders/test_mfa_disaster_recovery.py
echo "=== D15_S1_CUSTODIA_SINTETICA ==="
# Build aislado ya existente: no exponer clave real en argumentos ni env.
docker build -q -t "vencira-mfa-custody-test:$(git rev-parse --short=12 HEAD)" ./backend >/dev/null
IMAGE="vencira-mfa-custody-test:$(git rev-parse --short=12 HEAD)"
docker run --rm --network none \
 -e VENCIRA_ENV=test \
 -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_DEBUG=0 \
 -e DJANGO_SECRET_KEY=synthetic-only-not-for-production-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
 "$IMAGE" python manage.py test \
 reminders.test_mfa_key_config \
 reminders.test_mfa_disaster_recovery \
 --noinput --verbosity 1
echo "MFA_CUSTODIA_CRIPTOGRAFICA_SINTETICA=OK"
echo "CUSTODIA_EXTERNA_REAL=PENDING"
echo "RECUPERACION_ADMINISTRATIVA=PENDING"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "SIN_RESTAURACION_O5=1"
echo "SIN_MIGRACIONES_PERSISTENTES=1"
echo "CONSOLA_ABIERTA"
