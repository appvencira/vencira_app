#!/usr/bin/env bash
# Puerta de seguridad estática para el rollout O9a, sin acceso a DB ni contenedores.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
bash -n scripts/deploy_o9a_no_migrations.sh
python3 - <<'PY'
from pathlib import Path

path = Path("scripts/deploy_o9a_no_migrations.sh")
source = path.read_text(encoding="utf-8")
must_have = [
    "VALIDATED=37d510e070ff8ccdd7e87b8f3365b913f029ed9f",
    "BACKUP_O5_RECIENTE_Y_CIFRADO=OK",
    "POSTGRES_0015_INTACTO_PRE=OK",
    "IMAGENES_ANTERIORES_RECUPERABLES=OK",
    "step BUILD_API_WEB",
    "step MIGRATIONS_CHECK_ONLY_NEW_IMAGE",
    "COMPILACION_SIN_CAMBIOS_EN_SERVICIOS_ACTIVOS=OK",
    "PHASE=DEPLOY_API",
    "PHASE=DEPLOY_WEB",
    "POSTGRES_0015_SIN_CAMBIOS=OK",
    "O9A_CONTROL_SIN_SESION_HTTP=",
    "O9A_EVALUACION_CONTROL_SOLO_LECTURA=OK",
]
positions = [source.find(item) for item in must_have]
assert all(position >= 0 for position in positions), "missing required guard"
assert positions == sorted(positions), "unsafe sequence: O9a rollout"
assert len(set(positions)) == len(positions), "duplicate operation"
disallowed = [
    "docker compose down", "down -v", "migrate reminders 0015",
    "migrate --noinput", "migrate --fake", "restic forget", "restic prune",
    "docker rm -f vencira_localcheck-db-1",
]
assert not any(item in source for item in disallowed), "unsafe operation present"
assert 'set -Eeuo pipefail' in source, "shell not fail-closed"
assert 'sudo docker compose -p vencira_localcheck' in source, "compose project not isolated"
assert 'SIN_MIGRACIONES_NI_REINICIOS_POSTGRES=1' in source, "no-migration contract missing"
print("O9A_DESPLIEGUE_CONTROL_ESTATICO=OK")
PY
