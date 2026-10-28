# VENCIRA — O9a: evaluación informativa de la pregunta de control

**Fecha:** 25/10/2026. **Estado:** primera implementación en GitHub, **NO validada todavía en Ubuntu**, **NO desplegada**. No crea/entrega avisos ni registra respuestas. No modifica esquema `0015`.

## Fundamento documental

El plan de alineación al whitepaper v1, `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md` (§7, §8 y §18), exige identificar el último aviso anterior al límite de **un mes civil**, mostrar pregunta de control, registrar respuesta y eventualmente repetir dentro del tope. La fórmula existente `one_month_before()` es una **fecha informativa**, no una determinación legal particular; `Renewal.notice_deadline_on` es otra fecha contractual opcional. El whitepaper primario no se ha podido abrir directamente en este corte: este lote se fundamenta en las transcripciones y decisiones recogidas en el roadmap; no adjudicar significados a motivos de «Sí» ni reglas «No» que no estén aprobados.

## Alcance exacto O9a (SOLO LECTURA)

- Función pura `backend/reminders/control_assessment.py`, `assess_control(expires_on,days_before,as_of,requires_life_review)`. Reutiliza O8a/O8b: último aviso estrictamente anterior al mes civil, con fecha, días de anticipación y motivos normalizados.
- Endpoint `GET /api/v1/workspaces/{workspace}/renewals/{renewal}/control-assessment/`, solo sesión autenticada y miembro autorizado según `_membership` y `_visible_renewals`; 404 cruzado/otros empleados, 409 cerrada/archivada, 400 query params, 405 métodos no-GET, `Cache-Control: no-store` y sin PII. Lee `RenewalReminderDraft` guardado o defaults 60/45/35 si no existe, sin crear registros. `assessment_only=true`, `answer_recorded=false`, `scheduled=false`, `delivered=false`.
- Estados estrictamente informativos: `control_day_future_preview`, `control_day_today_preview`, `manual_review_required`. Razones de revisión: `life_case_needs_review`, `no_notice_before_cutoff`, `informational_cutoff_reached`, `control_date_already_past_no_execution_evidence`. **«Fecha pasada» no significa aviso enviado, recibido, desatendido ni incumplimiento confirmado.**
- Flutter: `VenciraControlAssessmentCard` aparece solo al desplegar la sección de simulador, después del borrador; texto ES/CA sin botones de respuesta, fechas e indicadores claros, espacio entre avisos. Botón **Actualizar evaluación** para volver a consultar después de guardar nuevos días. Cliente tipado rechaza resultados remotos `delivered=true`, `answer_recorded=true`, `scheduled=true` o fechas inválidas.
- Cero migraciones, cero colas, cero jobs y **sin contacto con cliente final**. O8b y O8c siguen funcionando y la tabla `0015` permanece intacta.

## Puerta técnica antes de permitir despliegue

`scripts/validate_o7_o8_preflight.sh` ahora añade Flutter `control_assessment_test.dart` al grupo dirigido, antes de tests Flutter completos. Django SQLite y PostgreSQL17 temporal ejecutan la suite completa, que incluye `test_control_assessment.py`: mes civil/leap, 60/45/35, 20/15 sin elegible, 30/15 con fecha válida, Vida, fecha pasada, permisos, aislamiento tenant, 409 y prohibición de envíos/escrituras. Flutter analiza, prueba ES/CA claro/oscuro 320 px y compila web. **No se ha ejecutado aún esta batería en Ubuntu para O9a**, por lo que ninguna parte está aceptada/desplegada.

## Requisitos aún sin aprobar para O9b

1. Texto exacto de la pregunta y las tres razones/respuestas asociadas a «Sí» (según whitepaper §8), sus efectos y auditoría; no inventar.
2. Qué respuesta concreta representa «No», su explicación, intervalos de repetición permitidos y quién decide nueva fecha; nunca programar más allá del tope.
3. Casos tardíos, sin ningún aviso anterior al límite y caso Vida: propuesta/manual review según §18; **no tomar decisiones comerciales o legales implícitas**.
4. Qué implica entrega efectiva y respuesta sobre un aviso nunca emitido: O10 debe separar `planned`, `queued`, `delivered`, `displayed`, `answered`.
5. Persistencia de respuesta en futura migración (por ejemplo `0016`) aditiva y auditada tras O4, sin tocar `RenewalReminderDraft` ni permitir falsos estados. No implementarla hasta cerrar contrato.

**Próxima acción:** sincronizar GitHub y ejecutar SOLO `bash scripts/validate_o7_o8_preflight.sh`. NO repetir el despliegue de O8c ni ejecutar una migración. Con resultado verde, crear script específico API+Web sin migración, con checks de esquema **0015**, imágenes rollback y endpoints sin sesión bloqueados, antes de UAT.

## 25/10/2026 — O9a preflight integral VERDE; rollout API+Web sin migraciones preparado, NO EJECUTADO

**Salida real del usuario tras sincronizar código O9a:** `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local privado `/tmp/vencira-o7-o8-preflight.jYamaKcr.log`. El checkout de fuentes para esta validación corresponde al commit `37d510e070ff8ccdd7e87b8f3365b913f029ed9f`. La salida no incluye línea `COMMIT` en el fragmento, pero el preflight script valida HEAD y ese fue último HEAD de código antes de la ejecución. **No se ha desplegado ni migrado durante estas pruebas.** DB persistente sigue `0015`; O8c operativa.

**Preparado (aún NO ejecutado) rollout de O9a:** `scripts/deploy_o9a_no_migrations.sh`, especializado para API+Flutter Web de `vencira_localcheck`, fuentes backend/clients/compose/deploy pin al commit verde anterior, comprueba DB `reminders.0015_renewal_reminder_drafts` y tabla drafts existente, API `migrate --check` no automigra, O5 backup sano/reciente y acceso remoto; guarda tags recuperables de imagen API/Web, construye ambas, ejecuta `manage.py migrate --check --noinput` solo lectura y comprueba contenedores originales intactos antes de actualizar API, luego Web. Postchecks DB ID y count migraciones iguales, HTTP local (200), autenticación anónima denegada en O7, O8b, O8c, O9a y desenlaces (401/403), salud API/DB/Web, recibo y etiquetas. O5, Caddy, tokens, PostgreSQL y el esquema 0015 no se reinician o cambian. Ante fallo después de recrear servicios, revisar recibo y evitar repetir a ciegas.

**Control estático nuevo:** `scripts/check_o9a_deploy_static.sh` verifica `bash -n`, secuencia seguridad, ausencia de comandos de migración/destrucción, nombre proyecto correcto. **Próxima orden**: checkout actualizado por `git fetch` y `git merge --ff-only`; `bash scripts/check_o9a_deploy_static.sh` y solo si OK `bash scripts/deploy_o9a_no_migrations.sh`, dentro de subshell, imprimir `RESULTADO_EJECUCION` y `CONSOLA_ABIERTA`. NO volver a ejecutar deploy O8c ni migración 0015. Despliegue solo se considera verificado al recibir `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Luego UAT de nueva tarjeta O9a en ficha DEMO, refresco tras editar draft.

**O9b sigue pendiente decisiones §18**: qué opciones «Sí», «No», motivos y intervalos/repeticiones; Vida y fecha civil informativa requieren revisión. Ninguna respuesta se almacena en O9a ni se envía aviso. Mantener `docs/NEXT_CHAT_HANDOFF_SHORT.md` actualizado en siguiente turno.

## 25/10/2026 — O9a DESPLEGADA con resultado 0; pantalla validada en Android

**Evidencia real del usuario:** commit desplegado `30a2f20d66836b222c446398d33578f5efd4c222`, `O9A_DESPLIEGUE_CONTROL_ESTATICO=OK`, `FUENTES_IGUALES_GATE_VALIDADO=OK`, `BACKUP_O5_RECIENTE_Y_CIFRADO=OK`, `POSTGRES_0015_INTACTO_PRE=OK`, etiquetas antiguas guardadas, `BUILD_API_WEB=OK`, `MIGRATIONS_CHECK_ONLY_NEW_IMAGE=OK`, `DEPLOY_API=OK`, `DEPLOY_WEB=OK`, `POSTGRES_0015_SIN_CAMBIOS=OK`, HTTP local y público 200, O7/O8b/O8c/O9a/O3 anónimos HTTP 403, `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, `O9A_EVALUACION_CONTROL_SOLO_LECTURA=OK`, `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Sin reinicio PostgreSQL, OAuth, Restic ni Caddy.

**Recibo** `/tmp/vencira-o9a-20261025T070242Z_2658759.Zkb4kHCT.receipt`, **log** `/tmp/vencira-o9a-deploy.UzuqBbWh.log`. Etiquetas rollback recuperables: `vencira-o9a-pre-api:20261025T070242Z_2658759`, `vencira-o9a-pre-web:20261025T070242Z_2658759`. No repetir despliegue ni migración O8c.

**Captura móvil Android de aceptación parcial de O9a:** ficha anotación y tarjeta `Pregunta de control: evaluación` perfectamente visibles, sin solapamientos evidentes; borrador persistido `20,15`; mensaje `Revisión manual pendiente`, referencia de un mes civil `21/10/2026`, avisos «No existe un aviso anterior a la fecha de referencia» y «La fecha de referencia ya ha llegado o pasado». Son coherentes con los parámetros aportados y con el día actual 25/10/2026. Botón `Actualizar evaluación` visible; la captura no demuestra que haya sido pulsado o prueba de renovación futura/Vida. **O9a desplegada con pantalla comprobada para este caso; no declarar aceptación exhaustiva de todos los casos.** No se han registrado preguntas ni entregado notificaciones.

**Siguiente foco: O9b especificación de respuestas reales y auditoría, sin decisiones legales/comerciales tácitas.** §8 del roadmap exige «Sí» (3 opciones), «No» y selector/repetición que nunca supere fecha límite; §18 deja por confirmar opciones/efectos, casos tardíos, Vida y cómo manejar preguntas sin envío. Documento `docs/OPERATION_O9B_RESPONSE_CONTRACT.md` define contrato propuesto. No implementar migración de respuesta real ni job de repetición hasta decisiones del promotor.

