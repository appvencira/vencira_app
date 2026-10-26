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


## C1 — Sin aviso elegible anterior al límite (aprobado 25/10/2026)

El promotor aprueba **permitir guardar la anotación** aunque no exista ningún aviso configurado estrictamente anterior al límite civil de un mes, pero con **advertencia roja visible y revisión manual obligatoria**. Si todavía existe margen anterior al límite, la interfaz **ofrecerá crear expresamente un aviso de control**, sin crearlo automáticamente y sin superar jamás el tope civil. Si el plazo ya ha transcurrido, no ofrecer agendar retroactivamente ni afirmar que la oposición esté en plazo; advertir y solicitar revisión humana. Registrar la incidencia sin fingir envío/entrega, conservar derechos y permisos de anotación. Esta es decisión funcional C1, **aún no implementada ni validada**: reutilizar cálculo `preview_reminder_plan` y ocurrencias A/B, probar meses cortos, 29/02, límite hoy, cero avisos elegibles, roles y reintentos. Sin migración ni despliegue con esta actualización.


## C1 — Modalidad Vida (aprobada por promotor, 25/10/2026)

Al seleccionar **Vida** mostrar advertencia específica: pueden existir reglas particulares de oposición; no calificar automáticamente el corte general de un mes como plazo legal confirmado para esta modalidad. Mantener avisos configurables y guardado permitido; exigir revisión humana de las condiciones de la póliza, con estado informativo explícito. Permitir el registro manual de respuestas Sí/No conforme al contrato del whitepaper, sin presentarlas como prueba de notificación, autorización o entrega. La implementación C2 deberá revisar el bloqueo conservador actual de `control_response_api.py` y `control_repeat_schedule.py` para ofrecer registro auditado sin automatizar ni certificar un plazo, sujeto a pruebas y revisión jurídica. Decisión documentada; **sin cambios de código ni despliegue** en este registro.


## C1 — «Notificado por mí»: declaración auditada (aprobada 25/10/2026)

El promotor aprueba que, al seleccionar «Sí → Notificado por mí», la interfaz exija **confirmación expresa** del mediador de que dispone de autorización del cliente y de que ha realizado la comunicación. Registrar actor, fecha/hora y alternativa seleccionada, manteniendo la anotación abierta. Es una **declaración del usuario**, no prueba de autorización documental, envío, recepción ni cumplimiento legal. No inventar adjuntos ni certificados; la conservación privada de justificantes queda para la fase de seguridad de archivos, permisos y retención. Debe reutilizarse el modelo/API de respuestas manuales O9b, con pruebas de confirmación, CAS, idempotencia y aislamiento. Esta decisión todavía no está implementada ni probada; no activar entrega ni tocar esquema/DEV con esta actualización.

**C1 restante en la macrofase:** selección, consentimiento, fallos, idempotencia y reintentos de canales reales email/push/local/offline. La entrega requiere diseño y validación independiente; mantener `delivery_status=not_implemented` hasta que exista evidencia fiable.


## C1 — Canales aprobados; cambio expreso de email predeterminado (25/10/2026)

El promotor aprobó móvil (avisos locales incluso sin conexión y app cerrada), navegador con app abierta y permiso, y correo resumen diario; **corrigió expresamente el valor inicial del correo a ACTIVADO por defecto**, modificación posterior y consciente del §7 del whitepaper, que decía desactivado. Adoptar **Resend** como proveedor candidato de VENCIRA, por experiencia con MASBITCOIN (API HTTP con `email_id` y webhooks Svix firmados para delivered/delayed/bounced/complained; originalmente SMTP). Implementación separada con dominio/remitente, credenciales y supresiones propias de VENCIRA; jamás reutilizar claves ni destinatarios de MASBITCOIN. Los permisos legales para comunicaciones, preferencia editable, baja/desactivación sencilla, minimización de datos, contratos de encargo, DNS y validación RGPD/LSSI deben revisarse **antes de activar envíos**. La decisión de default no acredita que sea lícito enviar sin base adecuada: el motor mantendrá entrega deshabilitada hasta gate técnico/jurídico. Reintentos limitados, deduplicación, estados programado/intentado/aceptado/entregado y privacidad lockscreen conforme a propuesta aprobada. Pendiente diseño técnico, implementación, tests y despliegue; sin cambios operativos con esta nota.


## C2 — Correo corporativo y transaccional: arquitectura confirmada (25/10/2026)

El promotor confirma que **vencira.es está contratado en OVHcloud** e incluye una cuenta **Zimbra Starter de 5 GB**. Decisión: usar Zimbra como buzón corporativo para recepción/respuesta y **Resend** exclusivamente para el envío automatizado de resúmenes diarios/notificaciones desde VENCIRA, reutilizando patrones de integración (no credenciales) de MASBITCOIN. Direcciones `contacto@vencira.es` y `avisos@vencira.es` son **ejemplos**, no buzones existentes ni remitentes verificados. Antes de producir envíos: verificar cuenta concreta en OVHcloud, dominio remitente en Resend, SPF/DKIM/DMARC y compatibilidad DNS/MX, subdominio recomendado para aislar reputación transaccional, callbacks/webhooks firmados y supresión de rebotes, límites y consentimiento/base legal. Nunca compartir credenciales, claves ni listas de destinatarios entre proyectos. Correo resumen diario activado inicialmente según decisión del promotor, sujeto a validación de comunicaciones y preferencias. En este hito **solo documentación**: sin accesos a OVH, alteraciones DNS, claves, envíos, migración ni despliegue.


## C2 — API solo lectura integrada, pendiente gate Ubuntu (25/10/2026)

Commit `059fac89a1235f5538c9d09ae55302b9a11c81fe`: `control_assessment_api.py` integra la política pura C2 en la ruta GET autenticada ya existente, devolviendo `c2_policy` (guardar, revisión manual, severidad/código, corte informativo no Vida, posible ofrecimiento explícito y último día válido, offsets futuros, `delivery_status=not_implemented`). Se preserva el contrato anterior y se aplica visibilidad del workspace. Commit `1e2541ba4e603b488e9345afb250b18c3756d732`: regresiones del GET normal y borrador sin aviso previo en `test_control_assessment.py`. **No supone programación ni notificación**; integración Flutter, persistencia de revisión y política HOY pendientes. **Sin pruebas ejecutadas todavía**: en Ubuntu correr `bash scripts/validate_o7_o8_preflight.sh` tras sincronizar rama, sin desplegar. No tocar PostgreSQL persistente, backups ni Caddy. Si falla, corregir antes de continuar.


## C2 — Gate integral aceptado y refinamiento visual pendiente de gate (25/10/2026)

El operador aportó marcadores completos del script `validate_o7_o8_preflight.sh`: salud PRE/POST OK, configuración Docker OK, i18n ES/CA OK, build backend aislado OK, comprobación seca de migraciones OK, suite Django SQLite OK, PostgreSQL17 efímero OK, suite Django PG17 OK, Flutter analyze/test/build OK, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`; log privado `/tmp/vencira-o7-o8-preflight.ibm3OwLT.log`. El gate acredita el código **anterior** al siguiente cambio UI, no valida futuros commits.

Refinamiento visual posterior en commit `1756a54f2e9378db6e2ea51ec48da97839bc1fb2` de `control_assessment_card.dart`: avisos de control caducado/ausente más visibles con icono de advertencia del tema; en Vida se oculta la fecha límite general para no presentarla como plazo legal confirmado. **Pendiente nuevo gate completo y aceptación Flutter** antes de desplegar. El contrato `c2_policy` ya está publicado en código de API read-only, pero aún no se consume en el cliente tipado. Sin envío, migración ni deploy nuevos.


## C2 — Segundo gate OK; Flutter tipado posterior (25/10/2026)

El operador aportó recibo integral `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `LOCALCHECK_HEALTH_PRE/POST=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `I18N_ES_CA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, con `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1` (log local `/tmp/vencira-o7-o8-preflight.pa7pRnLe.log`). Gate válido para versión anterior al cambio siguiente.

Nuevo commit `cc86f88e6d4adfea320a5c60dadd633bf7635411` añade `VenciraC2Policy` y parser en `clients/flutter/lib/api/vencira_api.dart` para leer el contrato GET `c2_policy`, sin enviar ni persistir; campo opcional para compatibilidad. **Pendiente validación integral después de este commit**. También está pendiente la presentación UX definitiva de los avisos C2 y la confirmación de notificado por mí. No desplegar hasta gate real.


## C2 — Tercer gate OK; tarjeta revisión manual posterior (25/10/2026)

El operador confirma para el gate del modelo Flutter tipado: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; log `/tmp/vencira-o7-o8-preflight.r8jDE17f.log`; sin cambios en persistencia, OAuth, Restic o Caddy. Esto valida el commit anterior a la siguiente modificación.

Nuevo commit UI `967f5fa456b233f5608fdde581909cd4c2ec03de`: tarjeta `VenciraControlAssessmentCard` muestra un aviso destacado cuando `c2Policy.manualReviewRequired`, usando textos ES/CA existentes, Material theme y sin acciones simuladas. No se han creado ni enviado avisos. **Requiere gate nuevo antes de deploy**; queda pendiente UI de oferta explícita y proceso de aceptación/revisión, así como aviso de modalidades y canales. No modificar datos reales.


## C2 — Límite estricto de repetición de control (25/10/2026)

Cuarto gate aportado por operador antes del cambio: salud PRE/POST, Compose, i18n ES/CA, backend build, migraciones secas, suites Django SQLite y PostgreSQL17 efímero, Flutter analyze/test/build, todo `OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.dOMFRUfF.log`; sin despliegue ni cambio en DB persistente, OAuth/Restic/Caddy. Se corrigió la inconsistencia de C2: la fecha de repetición del control debe ser **estrictamente anterior** al corte civil. Cambios: `control_repeat_schedule.py` commit `1a795d01adc8ca3c264a8b04942e862e224170f4`, `operational_schedule.py` commit `4ec0ca7128c8902487da3204ee62d3152380a940`, `control_responses.py` commit `c82894eec5e59bdfbf2c052310dba3a679467ec4`; tests frontera `test_operational_schedule.py` `556552689efda7ad780c1d8125f511a027cfcaba` y `test_control_responses.py` `d02ebe98643b0754b595dc4e9dbd99a81a14fde3`. **Los nuevos commits NO tienen gate ejecutado aún**; revisar suite completa antes de otra integración o deploy. No se ha construido todavía la UI de confirmación ni la acción de crear expresamente un control.


## C2 — Fallo del gate y reparación de test API (26/10/2026)

Gate real informado: `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`; suite Django SQLite encontró 235 tests, 1 fallo en `test_no_on_cutoff_is_plan_only_and_conflicts`: el test histórico esperaba HTTP 201 para repetir en 2027-02-28 (día de corte de vencimiento 2027-03-31), mientras la regla C2 aprobada exige día anterior. Se mantuvo el rechazo HTTP 400 y se corrigió exclusivamente la expectativa de regresión en `backend/reminders/test_control_response_api.py`, commit `e99d932a187064613f9d177f7a63cfa9e7047568`: rechazo en día de corte, no persistencia, éxito el 27/02, reintento idempotente y ausencia de entrega. **Gate anterior FALLIDO y nuevo commit pendiente de validar**. No hubo despliegue ni migración persistente; OAuth/Restic/Caddy intactos según recibo. Log local `/tmp/vencira-o7-o8-preflight.1hWeh3yQ.log`.


## C2 — Segundo fallo gate: reloj simulado incoherente (26/10/2026)

Gate informado `RESULTADO_GLOBAL=1`, fallo 1/235 SQLite en `test_no_on_cutoff_rejected_then_prior_day_accepted`: primer POST 201 y repetición igual 409. Diagnóstico: el test parcha fecha civil a 2027-02-25, pero `answered_at` (auto_now_add) queda con el reloj real del host 2026; la comparación idempotente reconstructiva utiliza día de `answered_at`, por eso el reintento artificial falla. Se corrigió el **test** añadiendo mock coherente de `django.utils.timezone.now` a 2027-02-25T12:00 UTC además del mock localdate: commit `505cdfa5bf6897c60a895392cb276202bf039cc0`. Sin cambio de lógica en producción ni migración. **Gate nuevo todavía pendiente**, no desplegar. Registro de fallo `/tmp/vencira-o7-o8-preflight.V6k3p5Z9.log` y ninguna alteración de DB persistente / OAuth / Restic / Caddy.


## C2 — Gate recuperado (26/10/2026)

Operador comunica validación integral de la corrección del reloj simulado (`505cdfa5bf6897c60a895392cb276202bf039cc0`): `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.c6g2NgJO.log`. No despliegue, migración DB persistente ni cambios OAuth/Restic/Caddy. **Este gate valida el código anterior a nuevos cambios C2**. Próxima tarea: acción expresa e idempotente de control con visibilidad de equipo, confirmación, auditoría y sin transporte real.


## C2 — Creación explícita de control interno (26/10/2026; pendiente gate)

Nuevo `backend/reminders/explicit_control_api.py` commit `d2767c9187f51695d175f4e008a033a00ca4c74b` y ruta `POST /api/v1/workspaces/<workspace_id>/renewals/<renewal_id>/explicit-control/` vía `urls.py` commit `4e8f14acd0cd3dcbbf120546c16d08178a7e832c`. Exige auth y alcance del workspace, payload JSON `{confirmed:true, scheduled_for:YYYY-MM-DD, idempotency_key:UUID}`, bloqueo transaccional de anotación, fecha futura o actual anterior al corte civil, política C2 `offer_explicit_control`, excluye Vida y corte vencido. Genera únicamente `OperationalReminder` interno y `OperationalReminderEvent` con actor; reintentos misma clave → misma ocurrencia, fecha distinta → 409, doble creación mismo día → 409. No envía notificaciones ni acredita entrega. Tests en `backend/reminders/test_explicit_control_api.py` commit `82f14d4963f26853ed2c542d5cd2a0793f221257` cubren confirmación, duplicado, idempotencia, fechas frontera, equipo y Vida. Gate anterior `RESULTADO_GLOBAL=0` log `/tmp/vencira-o7-o8-preflight.c6g2NgJO.log` solo valida código previo. **Esta operación nueva no ha superado aún gate Django SQLite/PG17 y Flutter**; no desplegar ni ejecutar migraciones persistentes. Falta conectar Flutter con confirmación UX y mostrar resultado.


## C2 — Gate de aviso explícito OK e integración Flutter pendiente (26/10/2026)

El operador comunicó gate `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.GorM69zX.log`; no despliegue, migración DB persistente ni alteraciones OAuth/Restic/Caddy. Gate valida API explícita, no los nuevos commits.

Nuevos commits Flutter: API `dabe64737eab9fb62b7bf42b1cfa3f5bd6f7d02e` añade `createExplicitControl` al contrato e implementación same-origin, CSRF, control de estados y respuesta sin delivery; UI `1a34ca4b257953b7bbad69ec642e12b6aef986ff` muestra crear control solo si la política lo ofrece, selector de fechas en intervalo permitido, diálogo confirmación ES/CA, confirmación de aviso interno sin entrega y recarga. **PENDIENTE gate real completo de estos commits, pruebas UI específicas y aceptación móvil**. No habilitar canales ni desplegar todavía.


## C2 — Gate integración Flutter OK y test móvil posterior (26/10/2026)

El operador reportó gate integral `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, suites Django SQLite/PG17, Flutter analyze/test/build e i18n ES/CA OK, salud pre/post OK; log `/tmp/vencira-o7-o8-preflight.Fn8LRLdg.log`. Sin despliegue ni migración persistente ni cambios OAuth/Restic/Caddy. Gate cubre API+Flutter hasta `1a34ca4b257953b7bbad69ec642e12b6aef986ff`.

Nuevo commit **posterior al gate** `6fbb41e8d822739ff7e9f59bcd1b907df21994ce` añade test widget `control_assessment_test.dart` (320px ES/CA) para verificar que el selector de fecha de control explícito se abre y que cancelarlo no realiza escritura. **Gate nuevo pendiente antes de desplegar**. No confundir pasar test general con validación visual en dispositivo real. Pendientes pruebas de diálogo confirmado y reintentos UI, revisión premium móvil, entrega Resend deshabilitada.


## C2 — Gate Flutter fallido por navegación del test; corrección 26/10/2026

El operador informa `RESULTADO_GLOBAL=1` en `FLUTTER_ANALYZE_TEST_BUILD`: 2 tests ES/CA de cancelación fallaron porque `tester.pageBack()` exige `CupertinoNavigationBarBackButton`, ausente en el selector Material; no se observa escritura o fallo de servidor. Log `/tmp/vencira-o7-o8-preflight.xi9jfhku.log`. El test `clients/flutter/test/control_assessment_test.dart` se corrigió para cerrar la ruta Material mediante `Navigator.of(tester.element(find.byType(DatePickerDialog))).pop()` sin depender del idioma, commit final `d57b8b3d45a607a751d388eba3b58d86ec660d98` (supersede tentativa anterior `658955e44b29d5d3fe694b57f7b63c58e5e5947b`). **Pendiente nuevo gate real**. No despliegue, migración de DB persistente ni alteración OAuth/Restic/Caddy según salida.


## C2 — Gate de cancelación aprobado y test de confirmación positiva (26/10/2026)

El operador confirma `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, con pre/post salud, Compose, i18n ES/CA, build backend, migraciones secas, suites completas Django SQLite y PostgreSQL17 temporal, Flutter analyze/test/build OK. Log `/tmp/vencira-o7-o8-preflight.lbfaSxgo.log`; `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`. Este gate valida el código **antes** del test nuevo.

Commit `509c34d333dcd01e9f91c689f8db08fdbece6847` añade test widget Flutter (320px, ES/CA) de flujo positivo de aviso expreso: selección de fecha, confirmación secundaria, cancelar sin llamada, confirmar con una sola llamada a fake API. **Pendiente gate nuevo**; sin cambios de backend/BD ni envío. Después revisar riesgo de duplicación de intentos reales y visualización móvil antes de permitir despliegue.


## C2 — Timeout en test de confirmación Flutter (26/10/2026)

El gate comunicado falló (`RESULTADO_GLOBAL=1`) en dos tests widget ES/CA de `control_assessment_test.dart` por `pumpAndSettle timed out` en línea 170, tras confirmar la creación; no consta fallo de Django ni evidencia de entrega. Log `/tmp/vencira-o7-o8-preflight.HoAWE8qd.log`. Se reemplazó **solo** la espera global del test de confirmación positiva por `pump()` y avance acotado de 250 ms, manteniendo la aserción de exactamente una llamada fake API; commit `fc9eb5f2fafa6b44634b0b043c1b05589189bc84`. Hipótesis: frame continuado por indicador de progreso. **Gate nuevo pendiente; no afirmar éxito**, ni desplegar o tocar base persistente, Resend, OAuth/Restic/Caddy.


## C2 — Gate de confirmación positiva aprobado (26/10/2026)

El operador confirma gate completo tras commit `fc9eb5f2fafa6b44634b0b043c1b05589189bc84`: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Log local `/tmp/vencira-o7-o8-preflight.CbSYTpyn.log`. No despliegue ni cambio en DB persistente, OAuth/Restic/Caddy. Queda validado el test ES/CA de confirmación de aviso interno, sin entrega real; pendiente aceptación visual móvil y revisión de reintentos ante respuestas ambiguas antes de desplegar.


## C2 — Reintentos ante respuesta ambigua (26/10/2026)

Gate anterior confirmado por operador: SQLite, PG17 efímero, Flutter, ES/CA, checks y salud pre/post `OK`; `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, log `/tmp/vencira-o7-o8-preflight.CbSYTpyn.log`; sin desplegar ni alterar DB persistente, OAuth/Restic/Caddy. Nuevo commit Flutter `dfd35ee942247b82cc0705ae2c10509e414d8550`: al enviar una creación explícita se conserva fecha + UUID de idempotencia en la tarjeta; ante error de transporte o respuesta incierta se muestra reintentar **la misma** petición (mismo UUID/fecha), se inhabilita nueva creación en esa instancia hasta resolver y no se afirma éxito. Tras respuesta aceptada se borra el token y recarga la evaluación. Se descarta al cambiar de anotación. Nuevo test widget `b10bc255e6df373a915eb23866ad3c483c0f9c02` simula fallo de primera respuesta y comprueba el UUID idéntico al repetir. **Ambos commits requieren gate completo**, además de revisión de permisos/fallo red y UX móvil antes de despliegue. Nota: persistencia del UUID solo en memoria durante la vista; después de recarga del navegador, reconciliar mediante historial/servidor antes de crear de nuevo. Resend sigue deshabilitado.


## C2 — Gate 26/10/2026: Flutter analyzer warnings y corrección

Operador reporta gate `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=FLUTTER_ANALYZE_TEST_BUILD`. Django SQLite: 239 tests OK; Django PG17 temporal: 239 tests OK; Compose, migraciones secas, i18n ES/CA, backend y salud PRE OK. Flutter `analyze` abortó por dos warnings `unused_field` en `control_assessment_card.dart`: `_createError` y `_createConflict` ya no se leen tras refactor de reintentos. Commit corrector `9e3298a25f6c6610479dc928e91cefd39bf95b05` elimina campos/asignaciones obsoletas manteniendo clave UUID y fecha para reintento. **Pendiente nuevo gate**; no desplegar. Log `/tmp/vencira-o7-o8-preflight.GJ2C0SSo.log`, sin migración DB persistente ni cambios OAuth/Restic/Caddy.


## C2 — Gate de reintentos validado (26/10/2026)

Operador confirma `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, con Compose, i18n ES/CA, build backend, comprobación de migraciones secas, suite Django SQLite, PostgreSQL 17 temporal, Flutter analyze/test/build, salud pre/post OK. Log `/tmp/vencira-o7-o8-preflight.uU9vPtFl.log`; `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1`, `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`. El archivo Flutter de flags obsoletos fue corregido y commit/push desde Ubuntu (`COMMIT_RESULT=0`, `PUSH_RESULT=0`) porque el intento previo de actualización remota no quedó reflejado; consultar `git log` para SHA real si se necesita. **Estado: gate superado, sin despliegue.** Sigue pendiente reconciliación tras recarga total del navegador, inspección UX en dispositivo real y autorización para cualquier despliegue DEV. Resend deshabilitado.
