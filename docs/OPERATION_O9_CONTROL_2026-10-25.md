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
