# VENCIRA — O8b: simulador de avisos por anotación, sin envíos

**24/10/2026 · Estado: código preparado en GitHub, NO validado todavía en Ubuntu, NO desplegado.** La producción DEV sigue en O7/O8a, commit `b61e357f06b7396d1018cb072ef39b6bc0974777`. O5 backups 03:00 Europe/Madrid sigue operativo. No migraciones, no cambios de tablas, no correos, push ni datos reales.

## Whitepaper §7, §8 y §18

- Tres anticipaciones iniciales: 60, 45 y 35 días respecto al vencimiento civil. El usuario debe poder personalizar días por anotación y elegir motivos, sin cambiar los demás registros.
- La pregunta «¿Se ha notificado a la aseguradora su no renovación?» se asocia al **último aviso estrictamente anterior** al límite de un mes civil (§8). El límite se calcula de fecha a fecha, nunca como 30 días.
- **No resueltos por decisión del promotor (§18):** anotación creada cuando parte de los avisos ya pasó; todos los avisos trasladados después del límite; motivos predeterminados; advertencia y reglas para Vida; qué hacer con un aviso no atendido.
- Por eso este lote NO guarda avisos ni los declara programados. Señala riesgos, no aplica reglas no aprobadas.

## Implementado sin mutación de base

- `backend/reminders/reminder_planning.py`: `preview_reminder_plan(expires_on, days_before, as_of=...)` admite 1–12 reglas de 0–365 días naturales, únicas, las ordena de mayor a menor anticipación y devuelve fechas, indicadores `control_question`, `already_elapsed`, `no_pre_cutoff_notice`, `late_control_needs_decision` y `cutoff_already_elapsed`. No crea retrospectivamente avisos vencidos.
- `validate_control_repeat_day`: ante futura respuesta «No», prohíbe intervalos nulos/incorrectos y fechas posteriores al tope. No registra respuesta ni seguimiento.
- `GET /api/v1/workspaces/{workspace-uuid}/renewals/{renewal-uuid}/reminder-preview/` admite ausencia de parámetros (60/45/35) o `?days=60,45,35`, formato CSV estricto sin duplicados; 400 para entradas inválidas; 405 para POST; 404 para anotaciones ajenas; 409 para archivadas; acceso autenticado y restringido a organización y responsable, salvo owner. `Cache-Control: no-store`. No devuelve nombre, nick, número de póliza, notas, email, teléfono, referencias ni identificadores de personas.
- El retorno JSON incluye `preview_only=true` y `delivered=false` expresamente. `life_rule_requires_review=true` para modalidad `vida`: **no es una validación legal de aplicación del artículo 22 a ese producto**.
- `test_reminder_planning.py` y `test_reminder_preview.py`: ejemplos whitepaper, entrada desordenada, control por último aviso anterior al tope, sin aviso pre-tope, creación tardía, topes 28/02, entradas inválidas, aislamiento tenant/usuario, anonimato, datos ficticios no filtrados, ausencia de escritura a `ReminderCandidate` y `ReminderPolicy`.

## Próximo gate O8b (solo pruebas, no despliegue)

En checkout `/home/vencira/vencira-localcheck` de la rama `integration/local-e2e-prep`, `git fetch` + `git merge --ff-only FETCH_HEAD` y ejecutar `bash scripts/validate_o7_o8_preflight.sh`. Es el validador ya aceptado que vuelve a ejecutar suites Django SQLite y PostgreSQL17 temporal, Flutter analyze/tests/build y salud de DEV sin modificar base persistente, API, web, Caddy, OAuth o Restic. **La denominación O7/O8 es histórica; incluye automáticamente todos los nuevos tests O8b.**

No desplegar O8b hasta disponer de pruebas verdes y aceptación de sus reglas por el promotor. El próximo lote de escritura O8c necesitará migración **0015 nueva** o una solución aditiva equivalente: defaults por cuenta, motivos configurables, overrides por anotación, versionado, idempotencia y auditoría; sujeto a la política O4 de migración con respaldo restaurado. Se decidirá después de resolver §18 y ver el simulador.
