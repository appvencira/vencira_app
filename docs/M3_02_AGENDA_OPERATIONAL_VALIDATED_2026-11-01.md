# VENCIRA — M3-02: agenda operativa integrada y validada (01/11/2026)

## Incidencia funcional corregida
La API de agenda diaria emitía `kind=operational_reminder` cuando había una ocurrencia interna activa, pero el parser de `VenciraAgendaEvent` en Flutter lo rechazaba. Esto podía impedir cargar la agenda de un día que contuviera avisos programados. La API tampoco aportaba el texto del motivo de cada ocurrencia, agrupando varios avisos en una sola marca.

## Implementación
- `backend/reminders/views.py`: `agenda_day` precarga solo las ocurrencias del día, activas y de anotaciones ya autorizadas (`Prefetch`); devuelve por aviso UUID, motivo, estado interno y `delivery_status=not_implemented`. Conserva una fila por anotación y la paginación existente. Añade `Cache-Control: no-store`.
- `clients/flutter/lib/api/vencira_api.dart`: validación estricta de `operational_reminder`, UUID, motivo 1–160 caracteres, estados `planned/pending/snoozed` y declaración explícita de ausencia de entrega.
- `clients/flutter/lib/ui/day_agenda_screen.dart`: etiquetas individuales con motivo del aviso real. Nuevo `agendaInternalReminder` en ES/CA.
- Regresiones Django: avisos múltiples, exclusión de completados, aislamiento de usuario/tenant, no cache y evento no entregado.
- Regresiones Flutter: contratos de respuesta, respuestas manipuladas, presentación en español y catalán y pantallas pequeñas. Corregido test del contador `agenda_today_inbox_test.dart` para consultar el `Text` identificado en vez de buscar un número ambiguo.

## Evidencia CI real
El trabajo se ha validado en una **rama aislada** desde `a6fa29a` para no interferir con cambios concurrentes de un adaptador de avisos nativos en la rama M3 principal.
- Rama: `feature/m3-02-agenda-operational-validation`.
- PR **#16** en borrador: https://github.com/appvencira/vencira_app/pull/16
- HEAD funcional verificado: `ed11c44f1a20554dd0eb60a026b542a2071687c1`
- GitHub Actions M3 run **41308152140**, 3 jobs `success`:
  - Django SQLite job `124852728922`: **57 tests, OK**.
  - Django PostgreSQL17 efímero job `124852728817`: **57 tests, OK**.
  - Flutter job `124852729063`: `flutter analyze` **No issues found**, **49 tests passed**, compilación release **Built build/web**.
- MB1 static security gates run **41308152257**: `success` (solo contratos estáticos).

## Límites y liberación
No son pruebas Android físico/iOS ni de avisos locales sin cobertura. No se ha enviado notificación alguna ni se ha habilitado un canal externo. El preview Web compilado no se ha desplegado. La PR #16 es una validación y **no está autorizada para fusionarse**; contiene historial de la rama M3, no solo el delta de agenda.

Los cambios concurrentes de avisos nativos en la rama general **no quedan validados** por esta CI aislada. No confundir éxito de esta rama con un PASS global de la PR #14.

**M3-02 sigue [ ]**. Hitos totales cerrados **2/15 = 13,3 %**. `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
