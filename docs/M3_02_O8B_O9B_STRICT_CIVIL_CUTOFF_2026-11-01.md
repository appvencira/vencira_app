# VENCIRA — M3-02: unificación de la fecha civil O8b/O9b (01/11/2026)

## Discrepancia real

`backend/reminders/reminder_planning.py:validate_control_repeat_day` admitía `scheduled == one_month_before(expires_on)`, aunque:
- `control_responses.validate_control_response` ya rechaza `repeat_on >= cutoff`;
- `operational_transitions.transition_reminder` rechaza aplazar preguntas de control al corte;
- el calendario Flutter M3-02 limita hasta el día **anterior** a dicho corte.

Esta discrepancia podía representar en la vista previa una fecha que no podría confirmarse en el registro manual. El módulo O8b era puro/sin persistencia, pero el resultado inducía a error.

## Corrección

`validate_control_repeat_day` aplica `as_of < cutoff` y `scheduled < cutoff`, con gestión de `OverflowError`. No se añade ninguna regla jurídica nueva ni se envían notificaciones.

`backend/reminders/test_reminder_planning.py`: para vencimiento 31/03/2027 el 27/02 es válido y el 28/02 (corte) inválido; para 31/03/2028 el 28/02 es válido y el 29/02 inválido. Se incorpora el módulo a la batería M3 tanto para SQLite como PG17 efímero y a los triggers de PR.

## Estado

Los cambios están en rama `feature/mb1-m104-transition-contract-batch`, PR #14 en borrador. Commits: `2144361`, `657edf1`, `d89d042`. **No existe PASS observado de la CI de esta corrección al documentar**; los PASS anteriores (62 SQLite + 62 PG17 + 49 Flutter + build Web) corresponden a la versión del acceso «Hoy» anterior a esta corrección.

No merge, no deploy DEV, no migraciones, no cambio de MFA o adjuntos. M3-02 pendiente, progreso 2/15 (13,3 %).
