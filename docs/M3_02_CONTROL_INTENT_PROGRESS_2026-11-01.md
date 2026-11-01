# VENCIRA — M3-02 contrato de control

Implementado `backend/reminders/control_intent.py`: respuestas Sí con tres motivos aprobados y No con repetición restringida al límite de mes civil. Los objetos de decisión no implican entrega, cierre ni escritura. Incorporadas pruebas en `backend/reminders/test_control_intent.py` y workflow `.github/workflows/m3-product-contracts.yml` para ejecutar dichas pruebas y la priorización de sugerencias Clientes.

Estado: código publicado, pruebas automáticas pendientes de confirmar. No hay endpoint, persistencia, auditoría real ni notificaciones; no se cierra M3-02. DEV intacto; no deploy ni migraciones. Total formal 2/15 (13,3%).

## Corrección de integración (01/11)

La inspección del backend confirmó que **ya existían** `RenewalControlResponse`, `control_response_api.py` (GET/POST autenticados con bloqueo de fila, revisiones e idempotencia), `control_repeat_schedule.py` y `control_responses.py`. Por tanto, no crear una segunda tabla, API o lógica de escritura. `control_intent.py` pasa a delegar en la validación operativa original, evitando contradicción de la fecha límite: el recordatorio repetido debe ser **estrictamente anterior** al tope, no en el propio día. Tests ajustados a 27/02/2027 permitido para vencimiento 31/03/2027 y 28/02/2027 rechazado. El endpoint ya tiene persistencia de respuesta manual y programa ocurrencia interna para «No», **sin entrega externa**. Pendiente cobertura HTTP y CI verificada. La frase anterior que indicaba «sin endpoint/persistencia» se refería únicamente al módulo auxiliar nuevo y no al sistema total.

## Fase agrupada de regresión HTTP (01/11)

Ampliado `backend/reminders/test_control_response_api.py` con dos pruebas nuevas: la misma clave idempotente con contenido cambiado se rechaza, las revisiones obsoletas producen conflicto y las solicitudes inválidas o de póliza Vida no persisten respuestas. Integradas en `.github/workflows/m3-product-contracts.yml` junto a las baterías de validación pura O9b. Son pruebas de cliente DRF con base de datos de test, no E2E con Caddy/Android; el PASS de Actions sigue sin confirmar. No se ha modificado endpoint ni esquema. M3-02 continúa abierto y el porcentaje formal queda 2/15.

## Integración API → agenda operativa (01/11)

Prueba añadida a `backend/reminders/test_control_response_api.py`: el POST manual «No» crea una sola ocurrencia `CONTROL_REPEAT` enlazada por `created_by_response`, la consulta a `operational-inbox/` para el día anterior no la incluye y la del día programado sí, `delivery_status` permanece `not_implemented`, y el mismo POST idempotente no duplica respuesta ni recordatorio. El workflow `m3-product-contracts.yml` ya ejecuta este módulo junto al resto de pruebas. Se verifica en base temporal de test, no en DEV ni por Flutter o proxy. **No hay resultado PASS confirmado aún**. Es avance funcional de trazabilidad, no cierre M3-02.
