# VENCIRA — MB1 ensayo E2E de recuperación en dos PG17 aislados

**Fecha:** 30/10/2026. Preparado en GitHub; **pendiente ejecución en Ubuntu**.

Se implementó `scripts/rehearse_mb1_pg17_e2e_disposable.sh` para reducir el número de microgates. Crea una red Docker interna y dos contenedores PostgreSQL 17 **desechables** (origen y destino), construye Django desde la rama, aplica el esquema independiente hasta `renewal_attachments.0006` en origen, inserta un expediente/adjunto **exclusivamente sintético** mediante ORM, escribe objeto y diario sintéticos en `/tmp`, hace `pg_dump -Fc` real, restaura con `pg_restore` real en destino, comprueba el registro con ORM y verifica SHA-256 del dump, objeto y diario. Al terminar (incluidos fallos) destruye los contenedores y la red de ensayo. No se publican puertos ni se conecta a DEV. El log local permanece en directorio `/tmp/vencira-mb1-e2e.*` con permisos privados. `clients/flutter/pubspec.lock` queda intacto.

**Este gate es una integración real de pg_dump/pg_restore, pero NO constituye el backup integral autenticado B09E ni una recuperación operativa.** Los bytes del objeto son un fixture y sus hashes no están ligados criptográficamente al manifiesto de PG17. No implementa cifrado de su `source.dump` (solo datos sintéticos), no crea un manifiesto autenticado, no demuestra que todos los escritores externos estén excluidos, ni valida custodia de claves fuera del VPS. B09E ya había probado restauración autenticada de materiales sintéticos por separado: este nuevo gate cubre una necesidad distinta (Django+dos servidores PG17 reales), pero no agrega automáticamente todas las garantías.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_E2E_EXIT_CODE=$?"
```

Solo si el operador ejecuta y pasa el gate se esperan:
```text
MB1_E2E_PG17_SOURCE_TARGET=OK
MB1_E2E_REAL_PG_DUMP_RESTORE=OK
MB1_E2E_SYNTHETIC_OBJECT_JOURNAL_HASH=OK
MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=NOT_CREATED
MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED
MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED
MB1_E2E_RESULT=0
MB1_E2E_EXIT_CODE=0
```

Criterios pendientes de cierre MB1: cortar de forma efectiva entradas y procesos de escritura BD/filesystem en un clon, capturar un conjunto autenticado y cifrado de la MISMA época, inyectar fallos en captura/restauración y reconciliar anomalías, custodia independiente de claves, recuperación ante pérdida de VPS. Nunca usar este script sobre datos reales.

```text
MB1_E2E_EXECUTION=PENDING
MB1_GLOBAL_FREEZE=BLOCKED
MB1_OPERATIONAL_DR=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
