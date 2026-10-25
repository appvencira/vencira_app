# VENCIRA — Macrofase C / C0 auditoría de contratos (25/10/2026)

**Rama inspeccionada:** `integration/local-e2e-prep`. **Estado:** auditoría estática de GitHub, sin ejecutar pruebas, sin cambios en servicios ni BD. Documento subordinado al whitepaper original `docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`, §§7–10, 16 y 18, y al handoff de cierre B. No sustituye gate dinámico ni aprobación del promotor.

## Capacidades ya implementadas: NO duplicar

- `control_responses.py`: pregunta Sí/No con tres alternativas, fecha civil y tope de un mes; Vida exige revisión manual.
- `control_response_api.py`: GET/POST autenticado manual, alcance por membresía/visibilidad, bloqueo de fila, revisión CAS, UUID idempotente, rechazo de cerradas/archivadas. «Sí» no cierra anotación; «No» llama a `plan_control_repeat` en la misma transacción.
- `control_repeat_schedule.py`: genera una `OperationalReminder` de tipo `control_repeat`, con `control_question=True`, vínculo a la respuesta y clave de origen estable. No envía mensaje ni ejecuta trabajo offline.
- `reminder_activate.py` y `operational_reconcile.py`: activación explícita de borrador y reconciliación de ocurrencias internas, incluidos motivos personalizados; no acreditan entrega.
- `OperationalReminder` y `OperationalReminderEvent`: estados planned/pending/snoozed/completed/cancelled y eventos; sin identidad de envío/recepción.
- `control_response_card.dart`: selector manual Sí/No, tres subopciones, días para No, historial y errores de conflicto; internacionalización mediante AppLocalizations.

## Brechas comprobadas en código (C0)

1. **Activación de pregunta y momento real:** la tarjeta de respuestas permite registro manual sin ligar la interacción a la aparición de una ocurrencia concreta; el backend marca explícitamente `origin=manual`. No afirmar que la pregunta haya «saltado» o se haya entregado.
2. **Motivo de repetición:** `control_repeat_schedule.py` almacena `reason="Comunicar no renovación"` genérico, mientras §8 prescribe «Comunicar no renovación de [nombre del cliente]». Resolver con criterio de PII y permisos; no insertar datos personales en notificaciones por defecto.
3. **Prueba de notificación:** `_serialize()` solo da `notice_delivered=False`; no existe contrato verificado de entrega push/email/offline. No confundir aparición interna con recibo de entrega.
4. **No con vida:** `control_response_api.py` fuerza revisión manual para modalidad `vida` sin distinción por tipo de respuesta. Es una barrera conservadora, no una regla legal aprobada para vida.
5. **Historial:** respuestas y eventos tienen actor/hora/clave de concurrencia, pero `RenewalControlResponse` no referencia directamente la ocurrencia que planteó la pregunta. Append-only está descrito como «lógico»; no asumir inmutabilidad criptográfica ni registro de entrega.
6. **Calendarios predeterminados y tardíos:** hay borradores y reconciliación, pero la política en §18 para altas tardías, cero avisos antes del límite y prioridades HOY no está aprobada. No imponerla unilateralmente.
7. **Presentación selector de días:** `control_response_card.dart` usa campo numérico y error general; validar UX del límite civil, señalización en rojo y recomendación de margen. La API ya rechaza repetición fuera del límite.

## Contrato obligatorio ya cerrado (§§8–10 y 16)

Pregunta literal: «¿Se ha notificado a la aseguradora su no renovación?». Sí: «Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí». No: «Avísame dentro de [selector de días]» y volver a preguntar en la fecha elegida, nunca tras el mes civil de corte. El Sí no cierra. «Notificado por mí» presupone autorización/firma del cliente; no afirmar comprobación documental automática. Las acciones Completada/Mañana/Otro día son diferentes de Sí/No.

## C1: decisiones pendientes del promotor — no aprobadas

1. Motivo predeterminado para avisos de 60, 45 y 35 días (la lista mínima editable de §7 sí es obligatoria).
2. Tratamiento de avisos no atendidos en HOY (propuesta PDF: mantener «Pendientes» arriba).
3. Altas tardías: generar solo avisos futuros, preguntar al guardar y/o advertencia roja.
4. Sin ningún aviso estrictamente previo al corte: impedir guardar o generar un control de forma explícita.
5. Advertencia y flujo especial de modalidad Vida, con revisión jurídica.
6. Evidencia/documento requerido para «Notificado por mí», sin tratar una selección como prueba de envío.
7. Política operativa de entrega, reintentos, privacidad en lockscreen, autorización del canal y experiencia offline; elección de proveedores es decisión técnica y exige seguridad/contratos.

**No volver a decidir:** tres opciones Sí, contenido de No, pregunta repetida (§10), fórmula del mes civil, no cierre automático y campos obligatorios ya resueltos A01. Otros puntos de §18 (MFA, permisos equipos, Excel, retención, pagos, etc.) permanecen como bloqueos v1, no se dan por aprobados.

## C2 diseño coherente condicionado a C1

Extender los mismos modelos y endpoints, no crear otro circuito. Separar estados *calculado*, *ocurrencia planificada*, *visible en bandeja*, *acción respondida*, *enviado a proveedor*, *aceptado por proveedor*, *entregado confirmado cuando exista prueba*. Asociar pregunta/control a una ocurrencia y una revisión de anotación; garantizar CAS/idempotencia y límites tenant. No usar delivery_status «delivered» sin recibo. Las reglas de prioridades, excepciones y envíos se implementan únicamente cuando exista decisión.

## C3 gates y despliegue

Primero tests de reglas y seguridad; después SQLite+PostgreSQL17 efímero, Flutter analyze/test/build y ES/CA 320/375/768 oscuro. Casos: Madrid fecha civil, 29/02, meses cortos, cierre/archivo, Vida, límite vencido, 20/15, idempotencia y carreras, permisos owner/asignado/tenant. Para migraciones, restauración O5 en clon y protocolo O4; comprobar esquema vivo antes de deploy, sin `down -v`. Proteger O5, OAuth, Caddy y datos persistentes. No activar emails/push/local/offline sin consentimiento/diseño validado.

## Evidencia y próxima acción

C0 es revisión estática de estos archivos de GitHub: `control_responses.py`, `control_response_api.py`, `control_repeat_schedule.py`, `reminder_activate.py`, `operational_reconcile.py`, `control_assessment.py`, `models.py`, `control_response_card.dart`. **No hay un nuevo resultado de suites** ni despliegue ni migración. Próxima acción: cerrar decisiones C1 con el promotor y transformar el contrato acordado en cambios testables sobre la rama de desarrollo, sin repetir B.


## C1 — Primera decisión aprobada (25/10/2026)

El promotor respondió «Ok, mantenemos actualizados durante los trabajos, seguimos» a la propuesta de motivos. Se registra **aprobación conversacional** de los motivos predeterminados editables: **60 días** «Revisar vencimiento y contactar con el cliente»; **45 días** «Enviar notificación de no renovación»; **35 días** «Comprobar comunicación de no renovación y responder a la pregunta de control». Ello no supone envío real. La pregunta aparece en el último aviso elegible estrictamente anterior al límite del mes civil, que puede no ser el de 35 días. La configuración por cuenta/anotación sigue el §7 y no se alteran borradores existentes sin acción expresa. Esta actualización documental no ejecuta cambios funcionales, gates ni migraciones.

**C1 abierto:** avisos pendientes HOY, alta tardía, ausencia de aviso anterior al corte, Vida, autorización/evidencia de «Notificado por mí», canales y reintentos. Las propuestas §18 no equivalen a decisiones. Antes de C2 cotejar código existente y preparar pruebas; no repetir fases A/B.


## C1 — Altas tardías aprobadas (25/10/2026)

Aprobación expresa del promotor: no crear retrospectivamente avisos como si hubieran aparecido; mantener programación futura válida; si ya pasó el último aviso de control, mostrar advertencia destacada al guardar y acceso a la pregunta de no renovación; si el corte civil ya pasó, advertencia roja y revisión manual, sin afirmar plazo legal vigente; permitir guardar para no perder datos y registrar necesidad de revisión. La aprobación cubre **altas tardías**, pero **NO decide todavía** qué hacer cuando el usuario configura todos los avisos después de la fecha límite (impedir guardar frente a crear control explícito); ese caso queda separado. No hay cambios de código, pruebas ni despliegue por esta decisión.


## C1 — Sin aviso elegible anterior al límite (aprobado 25/10/2026)

El promotor aprueba **permitir guardar la anotación** aunque no exista ningún aviso configurado estrictamente anterior al límite civil de un mes, pero con **advertencia roja visible y revisión manual obligatoria**. Si todavía existe margen anterior al límite, la interfaz **ofrecerá crear expresamente un aviso de control**, sin crearlo automáticamente y sin superar jamás el tope civil. Si el plazo ya ha transcurrido, no ofrecer agendar retroactivamente ni afirmar que la oposición esté en plazo; advertir y solicitar revisión humana. Registrar la incidencia sin fingir envío/entrega, conservar derechos y permisos de anotación. Esta es decisión funcional C1, **aún no implementada ni validada**: reutilizar cálculo `preview_reminder_plan` y ocurrencias A/B, probar meses cortos, 29/02, límite hoy, cero avisos elegibles, roles y reintentos. Sin migración ni despliegue con esta actualización.
