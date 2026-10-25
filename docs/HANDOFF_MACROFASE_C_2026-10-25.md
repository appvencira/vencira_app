# VENCIRA — Handoff de cierre de macrofase B y entrada a macrofase C

> **ACTUALIZACIÓN DOCUMENTAL 25/10/2026:** auditoría C0 terminada como revisión estática de código y registrada en [MACROFASE_C_C0_AUDITORIA_2026-10-25.md](MACROFASE_C_C0_AUDITORIA_2026-10-25.md). Se han sincronizado plan maestro y continuidad con este estado, sin cambiar el whitepaper original, sin ejecutar suites, migrar ni desplegar. **Próximo paso C1:** obtener decisiones explícitas del promotor solo para puntos pendientes §18; no asumir aprobadas las propuestas. Después C2 y C3 con gates. No reiniciar macrofases A/B.

**Fecha del cierre comunicado:** 25 de octubre de 2026.
**Repositorio:** `appvencira/vencira_app` (privado).
**Rama de desarrollo y DEV:** `integration/local-e2e-prep`.
**Servidor localcheck:** `/home/vencira/vencira-localcheck`.
**Preview:** `https://dev.vencira.es`.

## Resumen para reanudar sin reconstruir el historial de chats

**Macrofase B — aceptada por el promotor.** El usuario informó «Done, todo ok» tras las validaciones y despliegue web de la última mejora premium; es una **confirmación aportada por el usuario**, no un recibo del script pegado en esta conversación. En pasos anteriores sí reportó gates integrales con `FLUTTER_WEB_DOCKERFILE_PIN=OK`, `MACRO_B_GATE_INTEGRAL=OK`, `MACRO_B_GATE_RESULTADO=0`, y capturas Android de componentes previos. No inventar una nueva salida `RESULTADO_GLOBAL=0` ni reiniciar este despliegue.

**Entregado a nivel de código:**
- Backend de avisos internos, acciones `complete/tomorrow/another_day`, bandeja `due/today/overdue/upcoming`, historia cronológica de ocurrencias aislada por workspace/usuario, sin pretender entrega por correo/push. 
- Flutter Web ES/CA: bandeja con filtros 2×2 y menú de acciones compacto, mejoras globales contra parpadeos/scroll, `Historial de avisos` en fichas activas y archivadas, índice de ocurrencias y su detalle de acciones, paginador reutilizable y centrado en Inicio/Agenda/Archivo/Bandeja/historial.
- Refinamiento final: CTA `Historial de avisos` en `renewal_detail_screen.dart` como **Card.outlined full width** y alineada con Contacto/Póliza, icono, título, subtítulo «Consultar actuaciones registradas», flecha derecha, ES/CA, pruebas 320/375/768px con tema oscuro real.
- Fuente de última validación prevista por script `scripts/deploy_macro_b_premium_ui_web_guarded.sh`: `VALIDATED=d891c2df6e742698c99d4cf84cbc3573025feefd`. Este pin corresponde a fuentes y pruebas; commits posteriores de despliegue/documentación **no implican cambios en los archivos protegidos**. Verificar en GitHub al comenzar si surgieron nuevos commits.
- PostgreSQL persistente: migraciones `reminders.0018_draft_reasons` según gates y deploy anteriores; comprobar en vivo al preparar cualquier intervención. Infraestructura Caddy, OAuth, Restic/O5, timers y copias no deben tocarse por tareas UI.

**Diferenciar alcance real:** B gestiona **ocurrencias internas** y su historial, no notificaciones realmente disparadas/entregadas. El `delivery_status` sigue siendo `not_implemented`, sin envío email/push ni motor offline; no inferir cumplimiento legal de la existencia de una programación.

## Siguiente propuesta ordenada: MACROFASE C — motor funcional de avisos y control de no renovación

**No iniciar implementaciones ni migraciones sin auditar primero lo que YA está programado**; los documentos base `docs/WHITEPAPER_EXECUTION_ROADMAP_2026-10-24.md`, `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md` y `docs/OPERATION_O9B_RESPONSE_CONTRACT.md` son cortes anteriores y **contienen estados de despliegue ya obsoletos**.

1. **C0 — Auditar contratos existentes vs whitepaper original** `docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`, §§7–10, 16, 18. El código YA contiene `backend/reminders/control_responses.py`, `control_response_api.py`, `control_repeat_schedule.py`, `reminder_activate.py` y `clients/flutter/lib/ui/control_response_card.dart`. Hay respuestas **manuales** Sí/No y repetición planificada como aviso interno; no crear un segundo modelo ni reimplementar esa capacidad. Inventariar diferencias entre el comportamiento actual y el PDF y sus pruebas, incluidas activaciones, controles y pistas de auditoría.
2. **C1 — Cerrar únicamente las decisiones pendientes que bloquean reglas** del §18 con el promotor: motivos predeterminados para los tres avisos 60/45/35, avisos no atendidos y prioridad en HOY, anotaciones de alta tardía, no existencia de aviso anterior al límite, advertencias especiales Vida, y política de repetición/reintentos/entrega. **No tratar propuestas del PDF como decisiones aprobadas**. Lo definido en §§8–10 sí es obligatorio y NO está pendiente: pregunta exacta «¿Se ha notificado a la aseguradora su no renovación?», opciones Sí «Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí»; opción No «Avísame dentro de [selector de días]» con tope de un mes civil antes del vencimiento, y volver a preguntar en repetición. El «Sí» no cierra automáticamente. «Notificado por mí» presupone autorización/firma del cliente según §16.
3. **C2 — Extender el motor solo tras decisiones**: calendarios y motivos efectivos por anotación, pregunta especial ligada a ocurrencia adecuada, respuesta y revisión legal por casos límite, gestión de atrasados, y separación estricta entre programado, mostrado, entregado, respondido y completado. Canales de entrega (correo/push/local/offline) requieren diseño y seguridad explícitos; no habilitar redes ni automatismos silenciosamente.
4. **C3 — Batería y rollout seguro:** cálculos fecha civil en `Europe/Madrid`, 29/02 y meses cortos, duplicados/reintentos, CAS/idempotencia, permisos por tenant/owner/asignado, tests SQLite+Postgres17 efímero y Flutter ES/CA/analyze/test/build en SDK del Dockerfile, O5 backup cifrado válido y restauración. Si hacen falta migraciones, aplicar procedimiento O4 con copia restaurada, comprobación explícita, script versionado, no `down -v`. Solo activar entrega real tras validación jurídica, permisos, fiabilidad/offline y decisión del usuario.

**Bloqueos no resueltos de v1:** RGPD/MFA/cifrado y retención, adjuntos privados, cuentas y equipos, import/export Excel y permisos de resultados, app Android/iOS nativa offline, consentimiento/notificaciones, precios y publicación. No presentar B como v1 comercial terminado.

## Procedimiento inicial del siguiente chat

1. Abrir en GitHub este archivo, `docs/NEXT_CHAT_HANDOFF_SHORT.md`, `docs/CONTINUITY_RUNBOOK.md`, whitepaper original transcrito y contrato O9b.
2. Inspeccionar en rama actual los modelos, rutas, tests y las cinco piezas C0 citadas para evitar duplicaciones.
3. Proponer un **único diseño cohesionado de macrofase C**, separando reglas cerradas del PDF de decisiones pendientes §18; primero auditoría y tests, luego cambios reales con validación y aprobación de despliegue.
4. No solicitar de nuevo datos, credenciales, claves de backup ni configuraciones ya guardadas. Solo usar DEMO/sintético en DEV. Nunca imprimir secretos/logs privados completos en chat.

**Starter sugerido para nuevo chat:** «Continuamos VENCIRA desde `docs/HANDOFF_MACROFASE_C_2026-10-25.md` en GitHub. La macrofase B y el último rediseño premium están aceptados. Empezamos macrofase C: audita primero el código real de control Sí/No y avisos, compáralo con el whitepaper, identifica exclusivamente las decisiones §18 aún abiertas, y prepara un desarrollo único, documentado y con gates; no cambies servidores ni datos reales hasta validación». 


## C1 — Primera decisión aprobada (25/10/2026)

El promotor respondió «Ok, mantenemos actualizados durante los trabajos, seguimos» a la propuesta de motivos. Se registra **aprobación conversacional** de los motivos predeterminados editables: **60 días** «Revisar vencimiento y contactar con el cliente»; **45 días** «Enviar notificación de no renovación»; **35 días** «Comprobar comunicación de no renovación y responder a la pregunta de control». Ello no supone envío real. La pregunta aparece en el último aviso elegible estrictamente anterior al límite del mes civil, que puede no ser el de 35 días. La configuración por cuenta/anotación sigue el §7 y no se alteran borradores existentes sin acción expresa. Esta actualización documental no ejecuta cambios funcionales, gates ni migraciones.

**C1 abierto:** avisos pendientes HOY, alta tardía, ausencia de aviso anterior al corte, Vida, autorización/evidencia de «Notificado por mí», canales y reintentos. Las propuestas §18 no equivalen a decisiones. Antes de C2 cotejar código existente y preparar pruebas; no repetir fases A/B.


## C1 — Altas tardías aprobadas (25/10/2026)

Aprobación expresa del promotor: no crear retrospectivamente avisos como si hubieran aparecido; mantener programación futura válida; si ya pasó el último aviso de control, mostrar advertencia destacada al guardar y acceso a la pregunta de no renovación; si el corte civil ya pasó, advertencia roja y revisión manual, sin afirmar plazo legal vigente; permitir guardar para no perder datos y registrar necesidad de revisión. La aprobación cubre **altas tardías**, pero **NO decide todavía** qué hacer cuando el usuario configura todos los avisos después de la fecha límite (impedir guardar frente a crear control explícito); ese caso queda separado. No hay cambios de código, pruebas ni despliegue por esta decisión.
