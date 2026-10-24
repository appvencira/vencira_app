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

## 24/10/2026 — PRE-FLIGHT O7/O8a integral confirmado; despliegue API + Web preparado, NO ejecutado

El usuario aportó resultado real de `scripts/validate_o7_o8_preflight.sh`, sobre checkout integrado con O7 y O8a, con: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.988RWtXC.log`. La salida compartida omite COMMIT pero el último HEAD de fuente preparado para ese gate fue `c86cd8e058262da8998505c80e37ab3cdfa0ca90`; no afirmar verificable vínculo a ese SHA sin nueva comprobación local.

**O7/O8a código funcionalmente testado en aislamiento, aún NO instalado en DEV**. El preflight confirma que no se modificó PostgreSQL persistente ni O5/Caddy/Restic.

Se versionó `scripts/deploy_o7_o8_no_migrations.sh`, despliegue de una sola ejecución para **solo API y Web del proyecto `vencira_localcheck`**, con gate de diff desde commit fuente validado c86cd8e (backend, clients, compose, deploy), identidad healthy y guard de API `migrate --check --noinput`, verificación de respaldo cifrado O5 post-OAuth y snapshot menor de 36 h, comprobación del esquema 0014 y número total de migraciones, etiqueta inmutable y restaurable de imágenes previas API/Web ANTES de construir; si faltan imágenes antiguas aborta sin cambios. Build de API y Web, `migrate --check` sobre nueva imagen, recreación individual `--no-deps --no-build` solo API y solo Web, verificación DB mismo contenedor y migraciones iguales, HTTP 200 y O7/O3 rutas anónimas 401/403, salud API/DB/Web, recibo privado. **No se hace rollback de DB automáticamente**, si falla con servicios ya recreados inspeccionar recibo y tags antes de recuperar; no repetir script a ciegas. Caddy/O5 y `vencira_preview` intactos.

**Siguiente gate:** sincronizar rama `integration/local-e2e-prep`, ejecutar `bash -n scripts/deploy_o7_o8_no_migrations.sh`, luego `bash scripts/deploy_o7_o8_no_migrations.sh` en la consola de Ubuntu. El script abortará antes de desplegar si fallan imágenes recuperables/backup/source check. Si todas las pruebas pasan, aceptación O7 en navegador de ordenador ancho >=800 como owner (Resultados, cambiar periodos, cuenta correcta); confirmar inaccesible empleado y móvil. O8a no tiene UI, son funciones puras. No afirmar despliegue real hasta recibir marcadores `DESPLIEGUE_O7_O8_LOCALCHECK=OK`, `POSTGRES_0014_SIN_CAMBIOS=OK`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`.

**Restricción de velocidad:** No incorporar más cambios a `backend/`, `clients/` o `deploy/` hasta que se complete este gate o se repita preflight. Mantener O5 diario activo. Después priorizar O8b/O9 y O11, según plan maestro.
