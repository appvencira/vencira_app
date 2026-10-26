#!/usr/bin/env bash
# Read-only static deployment safety gate. Never execute rollout here.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
bash -n scripts/deploy_c2_no_migrations.sh
python3 - <<'PY'
from pathlib import Path
s = Path("scripts/deploy_c2_no_migrations.sh").read_text()
checks = [
 'VALIDATED=ea435a83f2e8a214cc1ba2b56ac1b35be1d68701',
 'FUENTES_IGUALES_GATE_VALIDADO=OK',
 'COMPOSE_IDENTIDAD_Y_MIGRATE_CHECK_ONLY=OK',
 'BACKUP_O5_RECIENTE_Y_CIFRADO=OK',
 'POSTGRES_0018_INTACTO_PRE=OK',
 'IMAGENES_ANTERIORES_RECUPERABLES=OK',
 'step BUILD_API_WEB',
 'step MIGRATIONS_CHECK_ONLY_NEW_IMAGE',
 'COMPILACION_SIN_CAMBIOS_EN_SERVICIOS_ACTIVOS=OK',
 'PHASE=DEPLOY_API',
 'PHASE=DEPLOY_WEB',
 'POSTGRES_0018_SIN_CAMBIOS=OK',
 'C2_CONTROL_SIN_SESION_HTTP=',
 'C2_DESPLIEGUE_CANDIDATO=OK',
]
pos=[s.find(x) for x in checks]
assert all(i>=0 for i in pos), "MISSING_GUARD"
assert pos==sorted(pos), "WRONG_GUARD_ORDER"
assert len(set(pos))==len(pos), "REPEATED_GUARD"
assert '0018_draft_reasons' in s, "WRONG_SCHEMA"
assert 'set -Eeuo pipefail' in s and 'vencira_localcheck' in s
assert all(x not in s for x in [
 'docker compose down', 'down -v', 'migrate --noinput',
 'migrate --fake', 'restic prune', 'restic forget',
 'docker rm -f vencira_localcheck-db-1',
]), "UNSAFE_COMMAND"
assert 'SIN_MIGRACIONES_NI_REINICIOS_POSTGRES=1' in s
print("C2_STATIC_DEPLOY_GATE=OK")
PY
