# VENCIRA — MB1 / B18H: censo de escritores, etapa 1

Fecha: 30/10/2026. **Inventario preliminar estático, no autorización**.

## Estado anterior

B18G pasó 6 pruebas en PG17 efímero sobre checkout `2a53f5c`; `B18G_COOPERATIVE_CUT=OK`, `B18G_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED` y `B18G_EXIT_CODE=0`. Evidencia comunicada por operador, documentada en [B18G](MB1_B18G_COOPERATIVE_CAPTURE_2026-10-29.md).

B18C probó que los escritores no cooperativos atraviesan el advisory lock, B18D/F probaron que el lock SQL de una o dos tablas tampoco impide alteraciones en filesystem, y B18E comprobó integridad de inventarios sintéticos. No repetirlos.

## B18H: observación de código completo

`scripts/audit_b18h_candidate_writers.py` escanea mediante AST los archivos Python bajo `backend`, excluyendo migraciones y pruebas. Emite JSON determinista con ubicación, línea, función/call y categoría para llamadas potencialmente mutadoras (ORM, SQL, filesystem y procesos). Es **solo lectura**. No ejecuta imports del backend, no accede a PostgreSQL, no modifica archivos, claves, contenedores o servicios.

Este detector **no proporciona inventario exhaustivo**: aliases y wrappers, escrituras indirectas, métodos dinámicos, componentes Dart/Flutter, shell, otros procesos y operaciones remotas no quedan necesariamente identificados. Incluye falsos positivos. Se utiliza para guiar una **revisión humana del grafo de llamadas** y para crear posteriormente una lista curada de caminos de escritura.

## Ejecución individual en servidor

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
python3 scripts/audit_b18h_candidate_writers.py > /tmp/vencira-b18h-writer-candidates.json
echo "B18H_AUDIT_EXIT_CODE=$?"
python3 - <<'PY'
import json
p='/tmp/vencira-b18h-writer-candidates.json'
d=json.load(open(p))
print('B18H_CLASSIFICATION='+d['classification'])
print('B18H_CANDIDATE_FILES='+str(d['candidate_files']))
print('B18H_CANDIDATE_CALLS='+str(d['candidate_calls']))
print('B18H_SCAN_ERRORS='+str(len(d['errors'])))
print('B18H_OPERATIONAL_FREEZE=NOT_VERIFIED')
print('NO_DEPLOY_NO_LIVE_MIGRATION=1')
PY
```

Compartir únicamente el resumen; el archivo local JSON contiene rutas de código, no secretos, y es evidencia de inventario para revisión. El estado del registro curado debe basarse en el análisis de candidatos y de caminos no detectados, no en el mero `exit code=0`.

## Puerta siguiente

Cruzar el JSON con la lista de rutas Django y tareas, comprobar los mutadores de objeto/diario y SQL no cooperativos; diseñar una barrera de escritor integral en un clon, con negativos de bypass y restauración verificada. No introducir locks multitabla en DEV sin diseño y autorización.

```text
B18H_CANDIDATE_SCAN=PENDING_OPERATOR
B18H_WRITER_CENSUS=INCOMPLETE
MB1_GLOBAL_FREEZE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Primera ejecución — 30/10/2026

El operador confirma `B18H_AUDIT_EXIT_CODE=0`, `B18H_CLASSIFICATION=HEURISTIC_ONLY_NOT_COMPLETE`, `B18H_CANDIDATE_FILES=76`, `B18H_CANDIDATE_CALLS=264`, `B18H_SCAN_ERRORS=0`, `B18H_OPERATIONAL_FREEZE=NOT_VERIFIED`. Se trata de **76 archivos y 264 llamadas candidatas**, no de 264 escrituras efectivas, fallos ni caminos certificados. El listado detallado está solo en `/tmp/vencira-b18h-writer-candidates.json` del VPS y no se ha analizado individualmente desde GitHub. **Pendiente** clasificar llamadas y grafo de ejecución (incluyendo procesos externos y filesystem). `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
