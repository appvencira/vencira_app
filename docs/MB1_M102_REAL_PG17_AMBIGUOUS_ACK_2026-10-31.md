# VENCIRA — M1-02: prueba aislada de confirmación SQL ambigua con PG17 real

Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## Estado

**Preparado, pendiente de ejecución del operador.** La validación anterior de 30 tests (`Ran 30 tests in 0.040s`, `OK`, `MB1_M102_GROUP_EXIT_CODE=0`) ya se ha registrado y **no se vuelve a ejecutar**.

Código nuevo:
- `backend/renewal_attachments/offline_mb1_pg17_ambiguous_commit_drill.py` (commit `7568027`).
- `scripts/rehearse_mb1_m102_real_pg17_ambiguous_ack.sh` (commit `151a916`).

El nuevo ensayo instala el esquema exclusivamente en un PostgreSQL 17 Docker de laboratorio, con una red interna y dos volúmenes privados temporales. Usa Django real, `RenewalAttachment`, `PrivateQuarantineStore` (Fernet), `IntakeJournal` y `stage_private_attachment` corregido.

Escenario A: el callback guarda metadatos y **sale de `transaction.atomic()`**, confirmando PostgreSQL antes de generar un TimeoutError de reconocimiento perdido. Después, **otro proceso Django** verifica que la fila existe y que el objeto cifrado y diario se conservan, sin publicar ni borrar.

Escenario B: el callback escribe metadatos dentro de `transaction.atomic()` pero falla **antes del commit**; una conexión independiente debe comprobar que la fila no existe, mientras el objeto cifrado y el diario permanecen en cuarentena como evidencia para conciliación.

Ambos casos se verifican por lectura con clasificador conservador, sin realizar reparación ni eliminación. Después se destruyen contenedor, red y volúmenes de laboratorio. Ni O5 ni DEV participan.

## Ejecutar una sola vez

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    bash -n scripts/rehearse_mb1_m102_real_pg17_ambiguous_ack.sh
    sudo env MB1_M102_REAL_PG17_LAB=YES bash scripts/rehearse_mb1_m102_real_pg17_ambiguous_ack.sh
    echo "MB1_M102_REAL_PG17_EXIT_CODE=$?"

Aceptar solo con:
- `MB1_M102_PG17_PRECHECK=OK`
- `MB1_M102_PG17_DISPOSABLE_DATABASE=OK`
- `MB1_M102_PG17_PRIVATE_VOLUMES=OK`
- `MB1_M102_PG17_TEMP_MIGRATIONS=OK`
- `MB1_M102_REAL_PG17_METADATA_PATHS_TRIGGERED=OK`
- `MB1_M102_REAL_PG17_COMMIT_PERSISTS_AFTER_LOST_ACK=OK`
- `MB1_M102_REAL_PG17_ROLLBACK_ABSENT=OK`
- `MB1_M102_REAL_FERNET_JOURNAL_PRESERVED=OK`
- `MB1_M102_REAL_READONLY_RECONCILIATION=OK`
- `MB1_M102_REAL_PG17_NO_AUTODELETE=OK`
- `MB1_M102_REAL_PG17_AMBIGUOUS_COMMIT_GATE=OK`
- `MB1_M102_REAL_PG17_RESULT=0`
- `MB1_M102_REAL_PG17_EXIT_CODE=0`

## Alcance y límites

Esta es una **transacción PostgreSQL real con excepción provocada después del commit** y un caso rollback real. Sin embargo, el timeout posterior se simula dentro del proceso y no equivale a pérdida de conectividad durante el protocolo COMMIT ni demuestra el resultado de una desconexión de red en un instante ambiguo. Es una prueba de conservación y coherencia en dos caminos, no un cierre general del commit ambiguo.

El mecanismo resultante conserva evidencia privada ante dudas, pero no ofrece aún **reconciliación operativa autorizada** de huérfanos, resolución idempotente, cortes de energía reales o exclusión universal de escritores. No cerrar M1-02 solo por PASS; integrar en clon y definir reconciliación antes de liberar.

```text
MB1_M102_REAL_POWERLOSS=NOT_VERIFIED
MB1_M102_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED
MB1_M106_EXTERNAL_CUSTODY=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
