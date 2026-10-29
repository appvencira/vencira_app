# VENCIRA — B18A: auditoría de caminos de escritura y captura (29/10/2026)

**Rama:** `feature/c-ficha-independent-attachments`. **Alcance:** inspección estática focalizada de código real en GitHub; NO es un inventario exhaustivo automatizado, ni ejecución del sistema. No se realizaron cambios en la BD, Docker, DEV o claves.

## Caminos inspeccionados

| Camino | Efecto | Barrera B06B | Resultado de inspección |
| --- | --- | --- | --- |
| `renewal_attachments/offline_intake.py::stage_authorized_attachment` | Journal + cuarentena cifrada + metadata en transacción | Sí, `advisory_barrier(capture=False)` envuelve el ciclo completo | Cobertura **solo ensayo**, por guard test-only |
| `reminders/attachment_quarantine_intake.py::stage_private_attachment` | Intento de journal, almacén y callback de persistencia; descarta objeto al fallar metadata | **No propia**; depende del llamador | Riesgo de invocación directa sin participación en barrera |
| `renewal_attachments/offline_transport_receiver_b17.py` | Evidencia de escaneo + nonce en transacción | Sí, antes de `transaction.atomic()` | Cobertura solo test-only |
| `renewal_attachments/offline_rejection_recovery.py` | Estado/intentos de outbox | Sí, antes de transacción | Cobertura solo test-only |
| `renewal_attachments/offline_recovery_persistence_d10.py::record_recovery_offline` | Expediente de recuperación y bloqueo de fila | **No** | Escritor de estado sin barrera común; comprobar si forma parte de inventario de captura |
| `renewal_attachments/offline_intake_journal.py` | Escritura del diario con `fsync` | **No propia** | Depende de que el coordinador llame desde una sección protegida |

## Hallazgos críticos

**B18A-01 — no existe barrera operacional universal.** `offline_write_barrier_b06b.py` restringe la sincronización a `VENCIRA_ENV=test`, `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED` y PostgreSQL. Su propia descripción reconoce que los escritores reales aún no siguen ese contrato. **BLOCKED**.

**B18A-02 — cobertura dependiente del llamador.** `stage_private_attachment` escribe objeto y diario y no adquiere lock por sí mismo. Un llamador adicional puede saltarse el protocolo. La fase operativa necesitará única entrada de escritura protegida, inventario de escritores, y pruebas negativas de acceso directo. **BLOCKED**.

**B18A-03 — estado mutable fuera del bloqueo compartido.** `record_recovery_offline` usa una transacción con `select_for_update`, que protege la fila pero no coordina con una captura que use el lock B06B. Hay que definir si los expedientes de recuperación quedan en el snapshot y protegerlos cuando corresponda. **BLOCKED**.

**B18A-04 — una transacción SQL no hace atómica la escritura en disco.** `stage_private_attachment` combina operación de filesystem, diario y persistencia. El descarte ante error puede fallar simultáneamente. Requiere protocolo de intención/outbox, freeze, marcador de captura durable y recuperación de huérfanos. Los tests anteriores de fallo/recuperación no acreditan operación en vivo. **BLOCKED**.

**B18A-05 — alcance de auditoría todavía no exhaustivo.** Se inspeccionaron seis módulos representativos; deben censarse todos los caminos que alteren metadatos, estados, evidencias, objetos, diario y outbox, incluyendo servicios ajenos a `renewal_attachments`. No declarar auditoría completa hasta crear un inventario exhaustivo. **OPEN**.

## Contrato propuesto antes de implementar B18B

1. Un coordinador de captura exclusivo bloqueará **todos** los escritores participantes, incluyendo filesystem, outbox y estado recuperable; los nuevos caminos de escritura sin barrera serán motivo de fallo de tests.
2. Capturar una frontera durable e identificable que una estado de DB + inventario de objetos cifrados + diario, con verificación posterior de integridad, no solo coincidencia de `snapshot_id`.
3. Ante cualquier escritor no cooperativo, error de sincronización, material incompleto, objeto huérfano o discrepancia de digest, abortar captura y no promoverla a copia recuperable.
4. Demostrar comportamiento con carreras y fallos inyectados en PostgreSQL 17 **efímero** y almacén sintético; distinguir rollback de SQL de compensación en filesystem.
5. Separar aceptación del conjunto de copia, autorización de restauración y autorización de producción. Ninguna es automática.

## Resultado B18A

```text
B18A_STATIC_REVIEW=COMPLETE_SCOPED
B18A_WRITER_INVENTORY=INCOMPLETE
B18A_OPERATIONAL_CAPTURE_BARRIER=BLOCKED
B18B_RUNTIME_TESTS=NOT_RUN
B18_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

**Próximo trabajo:** inventariar exhaustivamente escritores y puntos de mutación, después preparar una única batería B18B de carreras y restauración sintéticas. Mantener la especificación original y el plan maestro como referencias, sin reabrir fases B07–B09 ya documentadas.
