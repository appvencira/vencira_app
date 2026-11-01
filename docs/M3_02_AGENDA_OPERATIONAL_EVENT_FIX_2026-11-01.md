# VENCIRA — M3-02: agenda diaria con avisos operativos y motivos (01/11/2026)

## Incompatibilidad funcional identificada
Django `agenda_day` ya incluía el evento `operational_reminder` para avisos internos programados, pero `VenciraAgendaEvent.fromJson` de Flutter solo admitía `expiry`, `notice_deadline`, `reminder` y `follow_up`. Una anotación con aviso operativo hacía que la agenda del día no se pudiera deserializar correctamente.

## Corrección de producto de extremo a extremo
- Backend `views.agenda_day`: por cada anotación autorizada se precargan las ocurrencias internas activas del día, eliminando consultas N+1. Cada evento incorpora UUID de aviso, motivo real, estado (`planned`/`pending`/`snoozed`) y `delivery_status=not_implemented`. No duplica anotaciones; conserva la paginación por anotación y el filtro de asignación y workspace. La respuesta se marca `Cache-Control: no-store`.
- Flutter: `VenciraAgendaEvent.fromJson` acepta y valida estrictamente `operational_reminder`, motivo no vacío de hasta 160 caracteres, UUID, estados permitidos y **entrega no implementada**. La agenda muestra una etiqueta ES/CA con el motivo de cada ocurrencia.
- Seguridad: no hay escritura, envío de notificaciones, apertura de canales ni nuevas migraciones.
- Pruebas nuevas o extendidas: `backend/reminders/test_agenda.py` (múltiples avisos, completados no visibles, aislamiento tenant/usuario, no-cache); `clients/flutter/test/agenda_operational_event_test.dart` (rechazo de información manipulada y estados no válidos) y `clients/flutter/test/day_agenda_test.dart` (representación móvil español/catalán y ausencia de overflow).
- La CI M3 incluye estas pruebas en SQLite y PG17 temporal, más Flutter/Web.

## Registro de ejecución
GitHub Actions run `41307322694` (rama de validación PR #14): **Django SQLite PASS**, **Django PG17 temporal PASS**. Las pruebas de agenda operativa Flutter ES/CA y parser pasaron, pero el job Flutter global fue **FAIL (48 PASS, 1 FAIL)** por una aserción excesivamente amplia en `agenda_today_inbox_test.dart`, una prueba de un atajo simultáneo que comparaba el texto `1` en toda la pantalla. El test se corrigió para comprobar el contador dentro de `agenda-due-count` (commit `3a876f1`). La siguiente ejecución `41307454540` fue cancelada por un nuevo push antes de obtener un resultado global de Flutter. **No hay PASS integral posterior confirmado para esta tanda.** Las comprobaciones anteriores de M3 sobre otros cambios conservan sus PASS propios, sin extrapolarlos.

## Estado
PR #14 sigue en borrador. **M3-02 abierto**, 2/15 hitos (13,3%). Validación Flutter pendiente de ejecución integral no cancelada. No despliegue, no migración DEV, no habilitar MFA/C-FICHA ni notificaciones externas.
