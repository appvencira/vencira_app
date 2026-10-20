# Auditoría inicial de vencimientos — VENCIRA

**Fase de desarrollo. No es una auditoría jurídica ni un log inmutable.**

## Qué registra

Las peticiones POST/PATCH autenticadas a la API v1 de vencimientos generan eventos `RenewalAuditEvent` en la **misma transacción** que la escritura.

- Identificador de organización y vencimiento, usuario de la acción (FK con SET_NULL), momento y operación (`created`/`updated`).
- Campos modificados; para `expires_on` y `status`, valores anteriores y posteriores.
- La referencia del cliente **nunca se incluye en el payload de auditoría**, aunque sí consta el nombre del campo cuando cambia.
- Las solicitudes rechazadas y los PATCH sin cambio efectivo no generan eventos; los registros preexistentes no reciben historial retroactivo.

## Garantías y límites

- El acceso a auditorías **no está expuesto** por REST ni Django Admin.
- No cubre modificaciones mediante shell, management commands, señales, operaciones masivas ni cambios hechos directamente en BD.
- Los eventos **no son a prueba de manipulación** por administradores de BD; no tienen firma ni almacenamiento externo append-only.
- La política de retención y derecho de supresión no están resueltos. Los eventos usan PROTECT sobre la entidad y el vencimiento, impidiendo su eliminación accidental mientras existan eventos.
- Necesitan supervisión/alertas, acceso restringido a auditores, y controles sobre acciones administrativas antes de un despliegue real.

## Pruebas

Creación, modificación, no-op, aislamiento tenant, rechazo de campos extraños, omisión de referencia personal y rollback cuando falla el registro de auditoría, tanto con SQLite de CI como PostgreSQL 17.
