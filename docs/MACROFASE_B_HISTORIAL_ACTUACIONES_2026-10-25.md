# VENCIRA — Macrofase B / Historial de actuaciones
Fecha: 25/10/2026. Estado: **implementado en GitHub; NO validado ni desplegado**.

Tras validar el usuario las correcciones de fluidez, se completa el último bloque técnico de la bandeja.

## Contrato
- API nueva `GET /api/v1/workspaces/{ws}/renewals/{renewal}/operational-reminders/{reminder}/history/?page=1` en `backend/reminders/operational_history.py`.
- Requiere autenticación, membresía y visibilidad de la anotación. Cada aviso debe pertenecer a dicha anotación.
- Eventos de `OperationalReminderEvent` ya existente: `planned`, `cancelled`, `complete`, `tomorrow`, `another_day`. Actor solo si mantiene membresía actual; conserva evento aun si el usuario salió del equipo.
- Orden descendente, paginación 30/máximo 100, `Cache-Control: no-store`, no expone idempotencia y `delivery_status=not_implemented`. Sin cambios de BD ni mensajes externos.

## Flutter
- DTO `VenciraOperationalEvent`, `VenciraOperationalHistory` y método autenticado `fetchOperationalHistory`.
- `operational_history_screen.dart`: historial responsive ES/CA con fecha/hora de acción, actor, estado y fecha programada; «Mostrar más» sin borrar tarjetas.
- Desde los tres puntos de la bandeja y desde la ficha de anotación, incluso para avisos completados/cancelados.
- Pruebas: `backend/reminders/test_operational_history.py`, `clients/flutter/test/operational_history_test.dart`, y extensión de `operational_inbox_premium_test.dart`.

## Puerta de validación y despliegue
1. `cd /home/vencira/vencira-localcheck && git pull --ff-only origin integration/local-e2e-prep`.
2. `bash scripts/validate_macro_b_readonly.sh`. Exigir `MACRO_B_GATE_RESULTADO=0` y `FLUTTER_WEB_DOCKERFILE_PIN=OK`.
3. Solo después: `bash -n scripts/deploy_macro_b_history_api_web_guarded.sh` y `sudo env MACRO_B_HISTORY_CONFIRM=DEPLOY_HISTORY_API_WEB_NO_MIGRATIONS bash scripts/deploy_macro_b_history_api_web_guarded.sh`.
4. Verificar `HISTORIAL_PROXY_ANON_DENIED_HTTP` (401/403), `POSTGRES_0018_INTACTO=OK`, `RESULTADO_GLOBAL=0`. Confirmar en Android acceso a historial de avisos activos y ya completados.

Script de despliegue conserva imágenes previas y verifica O5/PG17, fuente pin `0e6f621d834e882d437acbbf8ca15c89075224c7`, no migra ni reinicia DB. No desplegar si hay fallos.

**Decisión de producto pendiente §18:** qué hacer con aviso no atendido. No se completan/cancelan automáticamente; los atrasados siguen visibles. No confundir acción interna con notificación enviada.
