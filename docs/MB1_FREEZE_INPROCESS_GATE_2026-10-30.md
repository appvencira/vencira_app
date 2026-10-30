# VENCIRA — MB1-FREEZE: primer componente ejecutable de corte (30/10/2026)

Se implementa un gate **estrictamente en memoria y de un solo proceso**, `backend/renewal_attachments/offline_freeze_mb1.py`, y sus ocho tests `test_freeze_mb1.py`. Es un ensayo de contrato, no el orquestador operativo diseñado en `MB1_FREEZE_RESTORE_INTEGRATION_DECISION_2026-10-30.md`.

El gate rechaza nuevas entradas `writer()` durante `freeze()`, espera escritores cooperativos activos, revierte el freeze ante timeout, libera el estado tras excepciones, rechaza un corte concurrente y exige los tres inventarios con `verify_capture_set` B18E. **Solamente protege llamadas dentro del mismo objeto Python.** No toca ni congela PostgreSQL, workers ajenos, otros contenedores, filesystem ni el diario. No proporciona snapshot transaccional ni ejecuta `pg_dump`. Usarlo con datos reales está prohibido.

Gate único (pendiente):
```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_mb1_freeze_synthetic.sh
echo "MB1_FREEZE_EXIT_CODE=$?"
```

Esperado: 8 tests OK; `MB1_FREEZE_INPROCESS_TESTS=OK`, `MB1_FREEZE_CROSS_PROCESS=NOT_IMPLEMENTED`, `MB1_FREEZE_FILESYSTEM=NOT_ENFORCED`, `MB1_FULL_RESTORE=NOT_RUN`, `MB1_FREEZE_RESULT=0`. Ninguno autoriza producción.

Siguientes integraciones necesarias para **MB1-FREEZE real en clon**: aislamiento de entradas y permisos de escritura de servicios, wait/stop verificable de trabajadores, conexión a captura DB PG17 y almacenamiento sintético, manifiesto durable; restauración B09E en destino independiente con fallos inyectados y custodia externa antes de cerrar MB1.

```text
MB1_FREEZE_INPROCESS=PENDING_VALIDATION
MB1_GLOBAL_FREEZE=NOT_IMPLEMENTED
MB1_OPERATIONAL_CAPTURE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
