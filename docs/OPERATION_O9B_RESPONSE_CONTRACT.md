# VENCIRA — O9b: contrato de respuestas a la pregunta de control

**Fecha:** 25/10/2026. **Estado: propuesta funcional y técnica para revisión; SIN código de respuestas, SIN migración, SIN envíos.** O9a sí está desplegada, con lectura y UI verificadas en DEV. El esquema persistente sigue en `reminders.0015_renewal_reminder_drafts`.

## Base documentada

- Whitepaper §8 según `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`: pregunta en el último aviso anterior a la fecha informativa de **un mes civil** antes del vencimiento; opciones **«Sí» (3 alternativas) / «No»**; selector de repetición que jamás exceda la fecha límite y auditoría actor/instante.
- El mismo roadmap §18 deja **sin aprobar** los nombres exactos/efectos de las tres alternativas «Sí», respuesta «No» y repetición, tardíos, avisos sin fecha válida y régimen Vida. Sin texto completo verificado para estos subapartados, **no rellenar las alternativas con supuestos ni asociar «Sí» automáticamente a renovación cancelada**.
- O9a calcula `control_day` a partir del borrador O8c o 60/45/35 y devuelve `assessment_only=true`, `answer_recorded=false`, `scheduled=false`, `delivered=false`. Cuando no hay un aviso anterior al tope o éste ya pasó, marca `manual_review_required`; no afirma incumplimiento ni que se haya enviado algo.

## Decisión funcional requerida antes de habilitar el registro

| Asunto | Situación pendiente | Valor seguro hasta aprobación |
| --- | --- | --- |
| Respuesta **Sí** | Nombres, tres subopciones y su significado exacto | Ninguna opción seleccionable |
| Respuesta **No** | Efecto exacto y si se exige una nueva fecha | No repetir automáticamente |
| Intervalo de repetición | ¿Qué días pueden seleccionarse? ¿una o varias veces? | Prohibir selección futura hasta decidir |
| Falta de aviso real | Se calcula un control aunque nunca se entregaron avisos | No habilitar respuesta como si procediera de aviso entregado |
| Fecha contractual vs informativa | `notice_deadline_on` es opcional y contractual; fecha de un mes civil es orientativa | No presentar como dictamen jurídico ni permitir rebasar el límite más estricto que resulte aplicable tras revisión |
| Vida / alta tardía / vencida | Tratamiento legal y comercial pendiente | `manual_review_required`, sin acciones automáticas |
| Permisos | Owner y responsable asignado actualmente pueden leer la evaluación | Escritura futura solo tras autorización explícita; no ampliar ámbito de acceso |

## Contrato de datos propuesto, NO implementado

Definir en O9b una tabla separada de `RenewalReminderDraft`, **aditiva** (candidata `0016`) con `workspace/renewal`, `control_assessment_revision`, `response_choice`, `response_reason_code` **aprobado**, `repeat_on` (nullable), `answered_by`, `answered_at`, `revision` y sello de origen `source='manual_user_action'`. Considerar historial inmutable de revisiones/eventos en tabla independiente: ninguna corrección debe borrar la respuesta anterior. No incluir el nombre/contacto del cliente en payloads/logs/eventos si basta ID de anotación autorizado.

**No aceptar** `answer_recorded=true` como efecto de un GET, la existencia de `ReminderCandidate`, un simple cálculo O9a o un borrador de O8c. Crear y registrar una respuesta requeriría acción autenticada con CSRF, validación estricta, revisión contra cambios concurrentes, auditoría y comprobación del estado de la anotación.

### Reglas técnicas seguras que pueden fijarse sin decidir aún los motivos

1. Validar día natural en zona `Europe/Madrid`, con fechas civiles (incluidos finales de mes, febrero bisiesto y cambios de hora). El límite de un mes es una fecha civil, no 30 días fijos.
2. Nunca permitir selector de repetición **posterior** al límite aplicable; impedir también fechas anteriores a hoy si no se ha aprobado un tratamiento de atrasos. Si el límite ya pasó, bloquear programación y derivar a revisión manual.
3. Verificar pertenencia al workspace y asignación en cada escritura, cerrada/archivada 409, cross-tenant 404, sesión y CSRF obligatorios; `Cache-Control: no-store`, sin datos personales en respuesta.
4. Concurrencia optimista: cada cambio requiere versión vigente de anotación y respuesta, con 409 ante cambios. No convertir automáticamente «No» en aviso programado. 
5. Mantener separados `evaluated`, `answered`, `scheduled`, `queued`, `delivered` y `displayed`; solo los estados con evidencia genuina podrán afirmarse. El sistema actual NO está enviando notificaciones.
6. Pruebas obligatorias: `Sí` sin motivo válido, `No` sin repetición definida, tope vencido, 20/15 sin control, Vida, alta tardía, respuesta duplicada, conflictos y auditoría sin PII.

## Secuencia de desarrollo propuesta

**O9b-1**: aprobar textos, motivos y efectos con el usuario (y revisión jurídica para casos especiales); añadir motor puro de validación de selección/fecha y pruebas **sin persistencia**.

**O9b-2**: crear migración aditiva `0016` para respuestas y auditoría, sin backfill, con ensayo O4 sobre copia O5 restaurada en PG17 temporal.

**O9b-3**: UI ES/CA de respuestas explícitas, sin envíos, pruebas responsive y permisos. Solo después de aceptación funcional O9b se permitirá diseñar O10 — bandeja/entrega real, notificaciones y reintentos.

**Ningún paso requiere volver a desplegar O9a**, que ya fue verificada con `O9A_DESPLIEGUE_SIN_MIGRACION=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, más captura Android consistente con días guardados 20/15 y control vencido.
