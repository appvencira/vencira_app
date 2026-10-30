# MB1 — contrato ante interrupción de intake (30/10/2026)

**Estado: pruebas implementadas, ejecución pendiente.**

La suite `backend/reminders/test_mb1_intake_failure_contract.py` invoca el flujo real `stage_private_attachment` con almacenamiento, diario y confirmación de metadatos simulados. Cubre orden correcto de intención → objeto → metadatos; fallo de intención; fallo de escritura de objeto; fallo en DB; retorno de metadatos ausente y fallo de limpieza.

## Hallazgo que impide declarar consistencia operativa

El flujo escribe el diario **antes** del objeto y de la transacción de metadatos. Si la escritura del objeto falla, puede persistir una **intención huérfana**. Si la transacción falla, se intenta eliminar el objeto, pero un fallo de limpieza deja un estado que necesita conciliación. Esto es un mecanismo de recuperación a completar, no una transacción atómica única entre filesystem y PostgreSQL. Tampoco cubre muerte abrupta de proceso, concurrencia o pérdida de energía.

## Gate sin acceso a DEV

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
sudo bash scripts/validate_mb1_intake_failure_contract.sh
echo "MB1_FAILURE_GATE_EXIT_CODE=$?"
```

Solo se construye la imagen Django local de la rama y se ejecutan tests SQLite sintéticos en un Docker sin red. Ningún `migrate` sobre DEV ni operaciones de escrituras en DB persistente. Un PASS confirma **el comportamiento observado**, incluida la necesidad de conciliación; no significa que los fallos estén resueltos. Se mantienen `MB1_GLOBAL_FREEZE=NOT_VERIFIED` y `MB1_RELEASE_AUTHORIZED=NO`.

## Estimación de cierre

Recuperación independiente sintética y persistencia PG17/objetos/diario tras recreación: validados. Pendientes MB1: cerrar estados huérfanos bajo fallos y caídas abruptas, exclusión completa de escritores y captura coherente PG17/archivos, y custodia externa operativa con retención y restauración de claves fuera del VPS. No asignar porcentajes ni plazos sin conocer infraestructura y las pruebas pendientes. MB2 MFA/adjuntos operativos sigue bloqueado por sus propios gates, y MB3 comercial no está cubierto por MB1.


## Validación del operador — PASS

`Ran 6 tests in 0.003s`, `OK`, `MB1_INTENT_OBJECT_METADATA_FAILURE_CONTRACT=OK`, `MB1_ORPHAN_INTENT_RECONCILIATION=REQUIRED`, `MB1_FAILED_CLEANUP_RECONCILIATION=REQUIRED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MB1_FAILURE_GATE_EXIT_CODE=0`. Son pruebas simuladas del orden de operaciones, no fallos físicos ni conciliación completada.
