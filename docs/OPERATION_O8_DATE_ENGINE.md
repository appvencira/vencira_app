# VENCIRA — O8a: cálculo civil legal y avisos predeterminados

**24/10/2026 — estado:** funciones puras y tests versionados, **sin ejecución de tests demostrada, sin integración con notificaciones, sin cambios de BD ni despliegue**.

## Fuente exacta
- Whitepaper §7, p. 9: cada nueva anotación tendría tres avisos: **60, 45 y 35 días** antes de `expires_on`. Ejemplo vence 15/03/2027: 14/01/2027, 29/01/2027, 08/02/2027.
- §8, p. 10–11: **fecha límite legal = un mes civil**, mismo día del mes anterior o el último día si ese número no existe; ejemplos 15/03/2027→15/02/2027, 31/03/2027→28/02/2027, 31/05/2027→30/04/2027, 15/08/2027→15/07/2027. **No equivale a 30 días**.
- §8: pregunta «¿Se ha notificado a la aseguradora su no renovación?» en el último aviso **anterior** al límite. Si el usuario cambia los avisos, debe reubicarse. «No» debe repetir la pregunta dentro del límite.
- §2 y §8: el plazo legal sirve como tope y no se presenta en la agenda como entrada propia. **El campo existente `Renewal.notice_deadline_on` es preaviso contractual introducido explícitamente por el usuario**, no el tope legal calculado.
- §16 y §18: modalidades Vida pueden seguir otra regla; falta decidir comportamiento cuando ningún aviso queda antes del límite, cuando se crea tarde, motivo de avisos por defecto y reintentos.

## Código nuevo
- `backend/reminders/legal_deadlines.py`: `one_month_before(date)` devuelve fecha civil pura y ajustada al calendario sin persistencia.
- `backend/reminders/default_reminders.py`: `DEFAULT_DAYS_BEFORE=(60,45,35)`, `default_reminders(date)` devuelve 3 `PlannedReminder` inmutables con fecha y un único indicador de pregunta de control en el último aviso anterior al límite.
- `backend/reminders/test_legal_deadlines.py`, `test_default_reminders.py`: ejemplos fuente, cambio anual, bisiestos, orden de avisos, elegibilidad de control y rechazo de inputs incorrectos.
- **No se ha activado la política `ReminderPolicy`, no se han creado `ReminderCandidate` adicionales ni comunicaciones.** La pregunta de control completa y el árbol de respuestas exigen O8b/O9.

## Criterios futuros de integración
- Reglas de una anotación deben ser editables y diferenciar eventos `PLANNED`, `QUEUED`, `SHOWN`, `ANSWERED` o equivalentes, sin confundir previsión con entrega. Los nombres de estados son propuesta técnica, no decisión comercial.
- Después de decidir motivos, creación tardía y casos Vida (§18), integrar transaccionalmente con migraciones aditivas, idempotencia, zona horaria y auditoría; antes migración real ejecutar O4 + copia/restauración probadas.
- No programar tarea de envío ni mostrar supuestas notificaciones en UI hasta que el sistema nativo (incluso sin cobertura) y la pregunta de control se hayan validado.
