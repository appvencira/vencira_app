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

## Implementación O2 en GitHub, pendiente de validación (23/10/2026)

**Estado vigente de O2:** código Django + Flutter + pruebas + preflight aislado subidos a `integration/local-e2e-prep`, **sin pruebas ni migraciones ejecutadas aún en el servidor**. Las afirmaciones previas «solo diseño» son históricas. **O1 sigue desplegada y aceptada funcionalmente por el usuario en Android**, sin necesidad de repetir sus pruebas.

- Django `backend/reminders/models.py`: `RenewalFollowUp` guarda día civil, estado `planned/completed/cancelled`, creador, usuario que atiende/cancela, fechas. Restricción SQL parcial impide varios seguimientos `planned` por anotación y permite histórico.
- Nueva migración **aditiva `0013_renewal_manual_followups.py`**: crea tabla, índices y constraint; no toca valores existentes de `Renewal` ni `ReminderCandidate`. **NO APLICADA**.
- API `backend/reminders/follow_up.py` y `backend/reminders/urls.py`: `GET/POST/PATCH .../renewals/{uuid}/follow-up/`. GET devuelve `active` o null, POST establece/reprograma por fecha ISO, PATCH completa/cancela con identificador exacto y confirmación previa en frontend. Permisos mediante `_visible_renewals`, sesiones/CSRF, escritura con `select_for_update` y bitácora `RenewalAuditEvent` sin PII. Sin correo, push, tareas ni avisos enviados.
- Agenda diaria `backend/reminders/views.py` muestra `kind:'follow_up'` como evento previsto; mensual `backend/reminders/agenda_month.py` agrega `follow_up:{pending,contacted}` manteniendo filtros/roles y ninguna referencia personal.
- Flutter `clients/flutter/lib/api/vencira_api.dart`: contrato y métodos HTTP seguros, parser de evento y contadores (compatible con respuestas anteriores sin nuevo campo).
- Flutter ficha `clients/flutter/lib/ui/renewal_detail_screen.dart`: tarjeta «Recuérdamelo», botones Mañana / 3 días / 7 días / Otra fecha, reprogramar, atendido/cancelar con confirmación, fechas locales calendario (sin sumar bloques UTC), mensajes ES/CA, historial técnico accesible solo en web escritorio.
- Flutter agenda `clients/flutter/lib/ui/day_agenda_screen.dart` y `month_agenda_screen.dart`: categoría violeta con marcas y celdas coloreadas. Vencimiento y preaviso conservan prioridad, los seguimientos no se confunden con recordatorios automáticos ni comunicaciones efectivamente entregadas.
- Test `backend/reminders/test_manual_follow_up.py`: plan/cancelar/atender/reprogramar, historial, CSRF, aislamiento workspace/miembros, fechas, agenda diaria/mensual, bloqueo de cerradas. Test `clients/flutter/test/manual_follow_up_test.dart`: flujo ES/CA y parser. API test cubre mismas rutas, CSRF e identificadores.
- **Preflight seguro disponible:** `scripts/validate_operativa_o2_preflight.sh`. Construye imagen API de prueba, check/makemigrations --check, Django completo SQLite, PostgreSQL 17 temporal por contenedor/red exclusivos, Django O2 sobre Postgres, Flutter analyze/test/build. No reinicia `api/db/web_preview` ni aplica migración a `vencira_localcheck`; elimina contenedor y red de pruebas. Toda salida agrupada por fase en `/tmp/vencira-operativa-o2-preflight.*.log` y `RESULTADO_GLOBAL`.
- **Siguiente puerta:** usuario ejecuta una vez preflight tras `git fetch` y `git merge --ff-only`; si falla, corregir directamente en GitHub. Con verde, preparar **fase distinta de backup seguro + migración 0013 + web+API rollout controlado** (arranque de API migra automáticamente), con comprobaciones de restauración, rollback y salud. No hacer despliegue O2 antes de disponer de respaldo verificado.


## Preflight O2 — hito Django aprobado, incidencia móvil de prueba corregida (23/10/2026)

La segunda ejecución consolidada (commit `a6614836`) confirmó `DJANGO_CHECK_Y_MIGRACION_EN_SECO=OK`, `DJANGO_SQLITE_SUITE=OK` y `DJANGO_POSTGRES_O2_TESTS=OK` sobre PostgreSQL 17 efímero. `FLUTTER_O2_SUITE_Y_BUILD` se detuvo en el test móvil ES/CA `manual_follow_up_test.dart`: el botón existente quedaba en y≈1000, fuera de la pantalla de 900 px; `scrollUntilVisible` no desplazó la lista ya construida. Corregido en GitHub (`08380e0c`) usando `ensureVisible` y `pumpAndSettle` antes de pulsar los botones de programación y atención. **No se modificó lógica de producción con ese parche.** Pendiente repetir el preflight completo y comprobar Flutter. **No hay migración 0013 real ni despliegue O2**; la versión O1 sigue funcionando.

## Preflight integral aprobado y puerta de respaldo/restauración (23/10/2026)

- Tercera ejecución O2 en `vencira_localcheck`, commit `f7a62e3debe1e7534572ed6ec5e0e81ce1913539`: **`RESULTADO_GLOBAL=0`**; Django check y `makemigrations --check`, suite total SQLite, tests O2 PostgreSQL 17 efímero y suite completa Flutter (analyze/test/build release) todos `OK`. Log `/tmp/vencira-operativa-o2-preflight.CIKXNCqx.log`. `MIGRACION_0013_AUN_NO_APLICADA=1`, `SIN_DESPLIEGUE_NI_MIGRACION_PERSISTENTE=1`. No volver a gastar pruebas en código inalterado.
- Próxima ejecución **solo de backup/restauración**, script nuevo `scripts/prepare_operativa_o2_backup.sh`: verifica código de producción idéntico al commit probado, etiquetas del proyecto localcheck y esquema a `0012`; realiza backup PostgreSQL custom `-Fc` protegido, valida índice y huella SHA-256; prueba restauración íntegra en contenedor Postgres 17 efímero **sin red**, comprueba `django_migrations` y conteos no personales; emite un recibo `.verified` solo con éxito. Un fallo no toca migración ni reinicia ningún servicio del entorno.
- Directorio de backups `/home/vencira/vencira-db-backups`: modo 700. Archivos dump/checksum/recibo: modo 600. **Un archivo dump NO está cifrado**; no adjuntarlo a ChatGPT ni compartirlo ni subirlo a GitHub. Existe prueba de restauración como puerta necesaria; `pg_restore -l` por sí solo no bastaría.
- **Estado vigente:** preflight probado, backup O2 **todavía no ejecutado**, migración `0013` no aplicada, API/Web O2 no desplegadas. Después de éxito explícito `BACKUP_RESTAURACION_VERIFICADOS=1`, preparar script independiente de `migrate --plan`, despliegue API+Flutter Web exclusivo `vencira_localcheck` y health checks; API aplica migraciones automáticamente al levantarse, por eso no reiniciarla ni construirla contra DB real antes del respaldo.

## Restauración real verificada y siguiente puerta de despliegue (23/10/2026)

- El usuario ejecutó `scripts/prepare_operativa_o2_backup.sh` correctamente en `vencira_localcheck`: `PG_DUMP=OK`, `PG_RESTORE_INDEX=OK`, `SHA256=OK`, `RESTAURACION_INTEGRAL=OK`, `CONTENIDO_RESTAURADO=VERIFICADO`, `RESULTADO_GLOBAL=0`, `BACKUP_RESTAURACION_VERIFICADOS=1`, `RESULTADO_EJECUCION=0`, `NO_SE_APLICARON_MIGRACIONES=1`, `NO_SE_REINICIARON_SERVICIOS_LOCALCHECK=1`. Se mantiene esquema `0012`. Log `/tmp/vencira-o2-backup.thwFlo0Y.log`.
- Respaldo privado `/home/vencira/vencira-db-backups/pre0013_20261023T084917Z_EQESO7FF.dump`, sha256 `6f3df512b225a361182248a25a718715106fb4d566af5f11f1e479cace7b8f1c`. La copia ha demostrado restauración íntegra y comparación de recuentos. Conservación de `.verified`, `.sha256` y dump con permisos 600; directorio 700. **El archivo no está cifrado**.
- Siguiente script `scripts/deploy_operativa_o2.sh` creado en GitHub (`bf5c0d4d`), no ejecutado. Ata el commit de producción al preflight Django/PG/Flutter verde `f7a62e3d` y a la huella y recibo del respaldo; guarda antiguas imágenes de API/Web para recuperación manual, construye API y Web sin parar servicios, comprueba `migrate --plan` mediante comando explícito sin deps, recrea SOLO API (su arranque aplica automáticamente `0013`), comprueba schema/constraint/healthy, y después recrea SOLO Web. Ejecuta HTTP y autenticación anónima de O2; HTTPS externo 401 meramente informativo. Nunca reiniciar `db` ni tocar `vencira_preview`. Si falla una fase posterior a migrate, **nunca hacer pg_restore automático**, porque puede destruir datos posteriores.
- **Estado actual:** preparación de O2 terminada, migración real y despliegue O2 pendientes de script. Tras ejecución verde verificar app Android con una anotación de demostración, fechas rápidas, cambio de fecha, resolver y comprobar calendario.

- Protección adicional antes de migrar: `scripts/deploy_operativa_o2.sh` rechaza una copia de **más de 24 horas** o con marca de tiempo inconsistente (commit `43e31191`). Si se supera ese límite, realizar una nueva copia y ensayo de restauración y actualizar la referencia del script; no reutilizar un backup obsoleto. No cambia el código de producción ensayado.

## O2 — despliegue completado y agenda Android comprobada (23/10/2026)

- **Servidor validado**: ejecución de `scripts/deploy_operativa_o2.sh` sobre commit `e8d5ccf96bed82f9a91183577bd5211bd20c7a57`, `RESULTADO_GLOBAL=0`, `DESPLIEGUE_OPERATIVA_O2_LOCALCHECK=OK`, `RESULTADO_EJECUCION=0`; API, PostgreSQL y Web `healthy`, cuatro rutas HTTP internas 200 y `FOLLOW_UP_SIN_SESION_HTTP=403`. El HTTP 401 externo es la protección anónima. La migración **`0013` consta aplicada**, tabla/índice verificados. **No seguir usando instrucciones anteriores que indican migración pendiente.**
- **Protección cumplida**: backup PostgreSQL previo restaurado y validado íntegramente antes de migrar; imágenes anteriores O1 conservadas bajo etiquetas `vencira-prev-o2-api:20261023T090605Z_1107929` y `vencira-prev-o2-web:20261023T090605Z_1107929`; recibo `/home/vencira/vencira-db-backups/deploy_o2_20261023T090605Z_1107929.receipt`; log `/tmp/vencira-o2-deploy.rPicfp4d.log`. No restauración automática. Backups sin cifrar, no difundir.
- **Captura Android recibida**: Agenda diaria para **30 de octubre de 2026** muestra 2 anotaciones, una con límite de preaviso contractual y otra con chip violeta **Seguimiento manual**. Marcas diferenciadas en tira semanal y sin overflow visible. Es evidencia de calendario diario O2 real, **no** una prueba completa de reprogramación ni de atención/cancelación.
- **Pendiente aceptación funcional O2**: sobre datos ficticios, reprogramar un seguimiento y comprobar cambio de fecha en agenda; cancelar y comprobar que deja de aparecer; programar otro y marcarlo «Atendido»; verificar color en calendario mensual. Auditoría técnica escritorio si procede. No se ha activado ningún canal de notificaciones salientes.
- **Siguiente fase, tras aceptación**: especificar y desarrollar O3 (cuatro desenlaces del whitepaper), mantener semántica de seguimiento separada de cierres y guardar historial. Prohibido dar por completa O2 sin esas comprobaciones ni modificar Django DB sin nuevas pruebas y respaldo.
