#!/usr/bin/env bash
# O8c static safety gate: syntax + key ordering, no side effects.
set -Eeuo pipefail
cd /home/vencira/vencira-localcheck
bash -n scripts/deploy_o8c_0015_guarded.sh
python3 - <<'PY'
from pathlib import Path
p = Path('scripts/deploy_o8c_0015_guarded.sh')
s = p.read_text(encoding='utf-8')
markers = [
    'VALIDATED=80a5ac618f476a2d3b256499047dfdd1ada01c12',
    'RECIBO_RESTAURACION_O8C_VALIDO=OK',
    'API_MIGRATE_CHECK_ONLY=OK',
    'POSTGRES_0014_PRE_MIGRACION=OK',
    'O5_CIFRADO_ACTIVO=OK',
    'IMAGENES_O8B_CONSERVADAS=OK',
    'step BUILD_API_WEB',
    'step PLAN_MIGRACION_0015',
    'step BACKUP_O5_FRESCO_CIFRADO',
    'step APLICAR_0015_EXPLICITAMENTE',
    'step CHECK_MIGRACIONES_POST0015',
    'step DESPLEGAR_API',
    'step DESPLEGAR_WEB',
    'ENDPOINTS_PRIVADOS_PROTEGIDOS=OK',
    'O8C_GUARDADO_SOLO_BORRADOR=OK',
]
positions = [s.find(marker) for marker in markers]
assert all(p >= 0 for p in positions), 'missing O8c safety gate'
assert positions == sorted(positions) and len(set(positions)) == len(positions), 'unsafe operation ordering'
for unsafe in ['down -v', 'migrate --fake', 'restic forget', 'restic prune', 'pg_restore -d "$POSTGRES_DB"']:
    assert unsafe not in s, f'unsafe command: {unsafe}'
assert 'exit 78' not in s, 'deployment remains explicitly disabled'
assert s.startswith('#!/usr/bin/env bash'), 'missing Bash interpreter'
assert 'set -Eeuo pipefail' in s, 'missing fail-closed shell mode'
print('O8C_CONTROL_ESTATICO=OK')
PY
