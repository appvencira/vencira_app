# VENCIRA — O2 «Recuérdamelo» (diseño previo, NO implementado)

Fecha: 2026-10-23. Rama `integration/local-e2e-prep`.

## Origen del requisito
White paper original `White_paper_agenda_vencimientos.pdf`, páginas 7, 12 y 14:
- La agenda muestra «recuérdamelo» en el día elegido, diferenciado de límites y vencimientos.
- Uno de los cuatro desenlaces futuros será «Aún sin decidir, recuérdamelo en [selector de días]»: conserva abierta la anotación hasta esa fecha.
- El historial registra cada «recuérdamelo» con fecha/hora/usuario. No es lo mismo que «Mañana» u «Otro día…» para una notificación generada.
- Un aviso previsto no puede presentarse como notificación efectivamente entregada.

## Orden de implementación
**O1** (completada técnicamente en servidor 23/10/2026): registro manual «Contactado» / «Pendiente» desde ficha; Flutter test/build/deploy verdes sobre `a2f109ee`. Pendiente verificación móvil funcional directa con anotación ficticia; ningún dato real.

**O2** (preparación actual): «Recuérdamelo» manual. Esta fase no cierra negocio ni envía avisos, y **no implementa todavía la opción «Aún sin decidir» como uno de los 4 resultados**; esa integración corresponde a O3. Se puede preparar una fecha de seguimiento independiente para que no desaparezca una gestión abierta.

## Propuesta funcional O2
1. Desde ficha de anotación pendiente o contactada, acción **«Recuérdamelo»**. Elegir día mediante fechas rápidas «Mañana», «En 3 días», «En 7 días» u «Otra fecha» (calendario). Mostrar la fecha de seguimiento activa y permitir cambiarla o cancelarla.
2. Cada anotación puede mantener **como máximo un seguimiento manual activo**; nuevas programaciones sustituyen/cierran explícitamente el previo con rastro de auditoría, no lo borran sin evidencia.
3. El día seleccionado aparece en agenda diaria y mensual como **«Seguimiento»** con color/ícono distinto de vencimiento y límite contractual. La prioridad de marcas/celdas de eventos requiere regla explícita de concurrencia. No reutilizar `ReminderCandidate` asociado a políticas.
4. Las fechas se guardan como día civil `YYYY-MM-DD` sin conversión UTC; las acciones de «Mañana»/«En N días» se calculan en el dispositivo con día local, la API valida formato y límites. Elegir política para fecha pasada y para anotación cerrada.
5. Abrir la anotación desde un seguimiento en agenda permite reprogramar o marcar como atendido (esto último registra cumplimiento manual del usuario, no envío certificado). No mover `expires_on` ni `notice_deadline_on`.
6. No se activa correo, push, notificación de navegador ni trabajo programado de backend. La agenda muestra fechas **previstas**. No afirmar contacto, mensaje o recordatorio entregado.

## Modelo propuesto (revisar antes de migrar)
- Modelo nuevo `RenewalFollowUp` relacionado con `Renewal`, identificador UUID, `scheduled_for:DateField`, `state` {planned,completed,cancelled}, `created_by`, `created_at`, `updated_at` y versión lógica para concurrencia.
- Nunca vincular registros de pólizas como un CRM. Obtener workspace del `Renewal` autorizado; no aceptar `workspace` ni `renewal` en cuerpos de entrada.
- Historial: bitácora nueva apéndice por acción o ampliación segura de `RenewalAuditEvent` con nombres de campo/cambios no sensibles; no guardar información personal ni notas en metadatos. No describir la auditoría existente como inmutable.
- Aislamiento actual Django: `_membership`, `_visible_renewals` (owners ven cuenta, members solo asignados), `select_for_update` y escritura CSRF. Especificar permisos para crear/editar/atender/cancelar y negar siempre IDs ajenos con 404.
- Una restricción SQL parcial para máximo un `planned` por anotación y prueba de carreras transaccionales. Mantener los históricos aunque la cita se reprograme.
- Agregar API aditiva (`GET/POST` por ficha, `PATCH` sobre una acción) sin romper clientes Flutter anteriores. Validación de zona horaria `Europe/Madrid` y DST; no confiar en fecha UTC del servidor para la agenda civil.

## Plan de pruebas antes del despliegue
- Django tests con SQLite y **PostgreSQL efímero**: tenant/role, CSRF, filtrado, transiciones y concurrencia/único plan activo, formato de fecha, idempotencia, histórica, no activar avisos reales.
- Flutter: simuladores para 320/375/768 y ES/CA (modo claro/oscuro); botones/días rápidos, cancelación, reprogramación, agenda mensual y diaria, prioridad de colores, preservación de texto e interacción accesible.
- Comprobar que `ReminderPolicy` y `ReminderCandidate` siguen igual y que las anotaciones `closed` no vuelven a agenda por una fecha de seguimiento.
- **Antes de aplicar la migración real:** comprobación de identidad Compose (solo `vencira_localcheck`), backup previo `pg_dump -Fc` en directorio protegido, `sha256sum`, `pg_restore -l`, plan de migración y verificación restauración en PostgreSQL efímero cuando sea posible. No reiniciar API (auto-migra en arranque) ni ejecutar `docker compose up --build` sin backup.
- Despliegue posterior con un **solo script consolidado** dividido en preflight/backup verificado, pruebas efímeras, migración controlada, healthchecks y rollback plan; evitar afectar `vencira_preview`. Sin GitHub Actions, cuota agotada.

## Estado
**Solo diseño/plan y dependencias documentados. No hay migración, API, Flutter O2 ni despliegue realizados todavía.** O1 mantiene versión desplegada validada; no introducir datos reales ni activar avisos hasta completar seguridad/RGPD.
