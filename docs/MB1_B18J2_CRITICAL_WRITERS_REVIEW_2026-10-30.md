# VENCIRA — B18J2: revisión de código de rutas críticas de escritura (30/10/2026)

**Estado:** revisión estática dirigida de **seis módulos** contra código en GitHub, no auditoría de los 34 archivos P0 ni de sus 131 llamadas. La cola P0 exacta sigue en el VPS y no se ha cruzado con este subconjunto. No asignar cobertura P0 cuantitativa sin dicho cruce.

## Hallazgos comprobados

| Módulo | Evidencia | Resultado |
|---|---|---|
| `renewal_attachments/offline_intake.py` | `stage_authorized_attachment` usa `advisory_barrier(capture=False)` alrededor de `stage_private_attachment` y de la creación ORM en `transaction.atomic` | Participa en B06B **solo ensayo**; no sirve frente a escritura directa |
| `reminders/attachment_quarantine_intake.py` | `stage_private_attachment` llama `journal.record_intent`, `store.put_quarantine` y `create_metadata` **sin adquirir barrera** | **Ruta primitiva no coordinada**; depende completamente del llamador. En error de metadata descarta objeto pero el fragmento no elimina intención en diario |
| `renewal_attachments/offline_intake_journal.py` | `record_intent` escribe JSON con `O_EXCL`, `fsync` de fichero y directorio; `_guard` de ensayo, sin B06B propio | Escritura durable de diario, sin fence propio. Debe protegerse por llamador |
| `renewal_attachments/offline_transport_receiver_b17.py` | `receive_envelope_offline` protege el bloque `transaction.atomic` y `AttachmentScanEvidence.objects.create` mediante B06B | Participación **en ensayo**, no universal |
| `renewal_attachments/offline_rejection_recovery.py` | `retry_rejected_discard_offline` protege `store.discard_quarantine`, `AttachmentDiscardJob.save` y transacción con B06B | Participación **en ensayo**, filesystem y SQL combinados; falla como protección si se llama a primitivas directamente |
| `renewal_attachments/offline_recovery_persistence_d10.py` | `record_recovery_offline` ya usa B06B antes de `transaction.atomic` (corrección B18B), y `get_or_create` | Participación **en ensayo**, no universal |

Las observaciones son sobre las funciones citadas, no garantizan que todas sus rutas sean alcanzables en una aplicación operativa. Hay que inspeccionar referencias/call sites y permisos de acceso a primitivas para demostrar que no existen entradas que eludan los guardas.

## Incidencia arquitectónica prioritaria

El primitivo `stage_private_attachment` **no puede demostrar**, por sí mismo, que se llama bajo la barrera. La API admite callbacks `create_metadata` y `journal`, lo cual permite una composición no cooperativa desde otros módulos. Por otra parte, el diario puede persistir la intención antes de escribir el objeto; si falla el guardado de objeto o los metadatos, el código examinado no acredita retirada/reconciliación de esa intención. No borrar a ciegas: reconciliar huérfanos y garantizar idempotencia/durabilidad.

**Plan técnico siguiente, sin activar producción:** añadir un contrato opt-in para primitivas sintéticas que requiera un contexto de barrera verificable ligado a la conexión/sesión, más tests negativos de llamada directa; revisar compensación de intención cuando falla la persistencia, sin perder trazabilidad. Evitar romper los tests anteriores o insinuar una barrera global. Paralelamente, clasificar todos los módulos de la cola real B18J antes de afirmar cobertura completa.

## Estado

```text
B18J2_SOURCE_MODULES_INSPECTED=6
B18J2_P0_QUEUE_CROSSCHECK=NOT_DONE
B18J2_UNIVERSAL_WRITER_CENSUS=NO
B18J2_FINDINGS=PRIMITIVE_BYPASS_RISK;JOURNAL_ORPHAN_RECONCILIATION_REQUIRED
MB1_GLOBAL_CAPTURE=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
