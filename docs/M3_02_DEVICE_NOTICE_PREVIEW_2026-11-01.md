# VENCIRA — M3-02: previsualización de avisos para futuro dispositivo (01/11/2026)

## Motivación y alcance del whitepaper
El documento original, sección 4 (§4) y §7, exige que Android e iOS disparen notificaciones **locales incluso sin conexión**, con hora configurable (09:00 por defecto) y sonido opcional. Un correo enviado por un servidor no satisface ese requisito. Esta entrega implementa **solamente la fuente autorizada y paginada de ocurrencias candidatas**; no instala plugins de alarmas, no escribe datos locales ni promete notificaciones.

## Backend: lectura controlada
- `GET /api/v1/workspaces/{workspace_id}/device-notice-preview/?from=YYYY-MM-DD&through=YYYY-MM-DD&page=1`
- Ventana máxima de **31 días civiles inclusivos**, con fechas ISO canónicas y página positiva. Paginación de **50** candidatos por página con `count` y `next`; no hay truncamiento silencioso.
- `_membership` y `_visible_renewals`: solo el tenant y las anotaciones visibles para el usuario, excluyendo archivadas/cerradas. Se reutilizan las ocurrencias persistidas `planned`, `pending`, `snoozed`.
- Datos mínimos: UUID de aviso y anotación, fecha, motivo, estado, pregunta de control y generación. **No retorna correo, teléfono, nombre completo ni póliza**.
- Respuesta `Cache-Control: no-store`, zona `Europe/Madrid`, `delivery_status=not_implemented` y `capabilities.native_alarm_scheduling=false`, `offline_storage=false`, `delivery=false`.
- GET de solo lectura: sin eventos, sin reconciliación, sin colas de envío ni migraciones.

## Flutter: contrato preparado, no activado
- `fetchDeviceNoticePreview` en `VenciraApi` y `HttpVenciraApi` valida UUID, fecha civil y ventana, sin seguir enlaces externos del servidor.
- `VenciraDeviceNoticePreview` y `VenciraDeviceNoticeCandidate` rechazan estados desconocidos, identidades inválidas, ventanas alteradas, repetidos, fechas fuera de ventana y cualquier afirmación `true` de capacidad local/offline/envío.
- No hay todavía pantalla ni programador nativo que llame a este adaptador. **Esto NO convierte VENCIRA en una app offline ni acredita aviso entregado.**

## Pruebas
- Backend `reminders.test_device_notice_preview`: cinco pruebas de autorización, tenant, minimización, ventana/paginación, ausencia de efectos y acceso anónimo.
- Flutter `test/device_notice_preview_test.dart`: cinco pruebas de parseo estricto, atributos de entrega y capacidades, paginación, cliente HTTP y su ventana.
- CI M3 ejecuta las pruebas Django agrupadas sobre SQLite temporal y PostgreSQL 17 efímero, Flutter analyze/test y compilación Web sin publicación.
- **Estado inicial:** CI específica de esta rama pendiente de validar. No afirmar PASS hasta consulta del run.

## Próximas decisiones imprescindibles
- Aprobación de diseño de offline: almacenamiento cifrado móvil, credenciales/sesión, revocación, reconciliación y conflictos multidevice (§18).
- Programador local Android/iOS, permisos y límites OS, zona horaria y cambios DST, hora/sonido por usuario, reprogramación tras reinicio, cancelación por cierre y deduplicación.
- Pruebas físicas de alarma sin red/app cerrada; aceptación, privacidad de lockscreen y revisión de cumplimiento.
- Correo resumen diario sigue opcional/desactivado por defecto; no implementarlo como sustitución.

Estado formal: M3-02 **abierto**, 2/15 hitos (13,3 %). MB1 release NO, MFA release NO, C-FICHA release NO, NO_DEPLOY_NO_LIVE_MIGRATION=1. Rama aislada para evitar cancelaciones de CI por actividad concurrente.
