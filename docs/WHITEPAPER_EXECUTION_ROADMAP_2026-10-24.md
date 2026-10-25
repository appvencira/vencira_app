# VENCIRA — Plan maestro de ejecución basado en whitepaper v1

> **ESTADO OPERATIVO VIGENTE — 25/10/2026, entrada en MACROFASE C.** Este plan contiene tablas y cortes históricos O7–O16 que **no representan el estado actual**. Prioridad de lectura: [whitepaper original §1–18](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md) (contrato funcional, NO MODIFICAR) → [handoff de macrofase C](HANDOFF_MACROFASE_C_2026-10-25.md) → [auditoría C0](MACROFASE_C_C0_AUDITORIA_2026-10-25.md) → continuidad histórica. Macrofases **A y B aceptadas**: ocurrencias internas, acciones y bandeja, historial, paginación y tarjeta premium de historial, ES/CA. O9b Sí/No manual, programación interna de repetición y controles de concurrencia **ya implementados**; NO volver a desarrollarlos. Última migración persistente documentada según cierre B: `reminders.0018_draft_reasons` (comprobar en vivo antes de una intervención). El último rediseño premium B fue aceptado por confirmación «Done, todo ok», no por nuevo recibo transcrito. **No existe aún entrega de email/push/local/offline** ni se debe describir un aviso planificado como notificación entregada. C0 auditada estáticamente y documentada; sin gate ni despliegue nuevo. C1: decidir SOLO cuestiones §18 pendientes, sin reinterpretar texto obligatorio §§8–10. C2: completar integración del control con ocurrencias y motor futuro mediante arquitectura existente, después de C1. C3: gates SQLite/PG17 efímero/Flutter ES-CA/O4-O5 y rollout explícito. Bloqueos v1: RGPD/MFA, retención, privacidad adjuntos, equipos, import/export, Android/iOS offline y canales con proveedores. **Las afirmaciones históricas inferiores sobre 0015, O9b sin implementar, O7 no desplegado y agenda HOY ausente han sido superadas; conservarlas solo como trazabilidad.**


> **ACTUALIZACIÓN DE FUENTE — 25/10/2026.** El whitepaper original de 23 páginas fue recuperado y transcrito íntegramente en [`docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md`](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md). El PDF binario original aportado por el promotor se identifica por SHA-256 `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66`. **Corrección sustancial O9b:** §8 p.11 SÍ define texto exacto «¿Se ha notificado a la aseguradora su no renovación?», opciones Sí («Avisada por el cliente», «La aseguradora no renueva», «Notificado por mí») y No («Avísame dentro de [selector de días]»). Sí registra actor/fecha/hora y mantiene anotación abierta. No crea aviso «Comunicar no renovación de [nombre del cliente]» a fecha elegida `<=` mes civil de tope, que vuelve a preguntar según §10 p.13. No clasificar estas opciones y su comportamiento como pendientes §18. **SÍ siguen pendientes** excepciones de alta tardía, sin avisos pre-tope, Vida, motivos por defecto, aviso no atendido y otras decisiones enumeradas en §18 p.22. Ver `docs/OPERATION_O9B_RESPONSE_CONTRACT.md`. Esta actualización no cambia los estados de despliegue: O9a DEV funcionando, O9b sin migración ni notificaciones.

**Corte de revisión:** 24/10/2026. **Fuente primaria:** `White_paper_agenda_vencimientos.pdf`, @Bibroker Mediadores, S.L.U., 18/10/2026, 23 páginas. Revisión de §1–18 y estado del repositorio privado en rama `integration/local-e2e-prep`.

## Principio de entrega
Una anotación = una póliza EXTERNA; no construir CRM ni administrar cartera propia. Agenda diaria tipo papel, Cliente/Candidato, vencimiento civil, avisos reprogramables, pregunta legal de control, desenlaces, consulta sincronizada y permisos por cuenta. Primero completar motor y seguridad; después móvil nativo, pagos y publicación. **Solo datos ficticios en DEV** hasta cerrar RGPD, MFA, alojamiento/backup con residencia UE y controles sobre adjuntos. Nada de declarar `ReminderCandidate` como notificación efectivamente enviada.

## Inventario por sección del whitepaper

| Sección | Requisito | Estado revisado (código y evidencias) | Riesgo / dependencia |
| --- | --- | --- | --- |
| §1–2 | Agenda de pólizas externas, sin CRM | Implementado como `Renewal` por anotación; no ficha global | Mantener separación entre póliza y datos de contacto |
| §3 | Individual/Equipo, aislamiento, asignación, alta/baja de usuarios | Workspace, miembros owner/member, filtro por responsable; asignación API owner | Altas/bajas, traspaso de Individual a Equipo y ciclo de reasignación pendientes |
| §4 | Web + Android/iOS, offline, avisos locales sin red, resolución de conflictos | Flutter Web DEV funcionando; sin offline nativo ni auth móvil | Requiere política de conflictos y credenciales nativas seguras |
| §5 | Portada en agenda HOY, franja semanal, swipe, colores, mes, filtros y búsqueda | Agenda día/mes existen y panel de listados; **inicio real sigue siendo panel**, no abre agenda directamente | Prioridad UX; definir aviso vencido/no atendido (§18) |
| §6 | Anotación: Entrada, nombre, nick, póliza, teléfono, email, modalidad, aseguradora, notas, archivos y asignación | Campos principales y catálogos ya implementados, sugerencias de persona, O1; **archivos aún bloqueados** | Acceso a contactos móvil pendiente, límites adjuntos sin decidir |
| §7 | Tres avisos por defecto a 60/45/35 días, motivos, reglas por anotación, hora/sonido 09:00, notificación móvil, web y email opcional | Política/candidato provisional con `enabled=False`, no envíos. O8 agrega funciones puras para fechas por defecto; NO políticas automáticas | Motivos de 60/45/35 sin confirmar (§18), definición de canales y prueba offline |
| §8 | Fecha límite LEGAL un mes civil anterior; pregunta en último aviso anterior al límite; sí/no con motivos y tope de repetición | Campo `notice_deadline_on` actual es **contractual y opcional**, NO legal. O8 pure functions preparadas; falta flujo de pregunta/respuesta y auditoría | No confundir con preaviso mostrado en agenda; excepción seguros Vida |
| §9–10 | Conseguido / No aceptó (+1 año) / Aún sin decidir / Descartar y ciclo completo | O3 y O2 aceptados por usuario en Android; Archivo O6 aceptado. Recuperación de Conseguidas añadida por decisión expresa posterior del promotor | No convertir candidatos globalmente en cliente CRM |
| §11 | Historial web, importar/exportar Excel, contadores por mes/trimestre/año | Historial web parcial y protegido; Excel ausente; **O7 resultados agregados owner-only en preparación** | §18 deja abiertas exportación y resultados para empleados; event audit no inmutable a nivel BD |
| §12 | MFA, bloqueo móvil, cifrado, almacenamiento UE, backups, retención/borrado y bloqueo | O4 migración controlada; O5 backups cifrados diarios 03:00 activos y verificados tras OAuth; RGPD, MFA, cifrado DB, residencia UE y borrado siguen pendientes | Puerta absoluta antes de datos reales o producción |
| §13 | ES/CA en interfaz y notificaciones | Flutter ES/CA probado, locales ARB; notificaciones futuras y textos de backend aún por completar | Pruebas de idioma y accesibilidad |
| §14 | Planes/precios/suscripciones | Deliberadamente pendiente según whitepaper | No inventar importe, medio de cobro o reglas de suscripción |
| §15 | Carta de oposición firmada/certificada y OCR pólizas | Expresamente FUERA DE V1, extensiones de pago | No bloquear MVP por ellas |
| §16 | RGPD/LOPDGDD, Ley de Contrato Seguro, DORA, LSSI y firma digital | Riesgos documentados, no cierre jurídico | Revisar con especialista; fuente reconoce apartados por confirmar |
| §17 | Marca y dominio | Nombre definitivo VENCIRA posterior al whitepaper, dominio `vencira.es` | OEPM/EUIPO y tiendas sin validar |
| §18 | 20 decisiones abiertas (14 promotor, 6 desarrollador) | Algunas resueltas posteriormente (VENCIRA, tecnología, backups, recuperación de Conseguidas), mayoría sin aprobar | Registrar cada decisión, no asumir propuestas como hechos |

## Plan de ejecución por dependencias y frentes paralelos

| Lote | Prioridad | Trabajo y salida verificable | Dependencias | Puerta de validación |
| --- | --- | --- | --- | --- |
| **O7 — Resultados** | Alta / rápida | API agregada owner-only con periodos mes/trimestre/año; pantalla solo Web escritorio ES/CA; prueba tenant, historial y límites. **Código versionado; NO desplegado** | O3, rol owner; acceso miembros §18 pendiente | Django SQLite/PG17 + Flutter test/analyze/build + prueba desktop real |
| **O8a — Cálculos puros** | Crítica / rápida | Un mes civil antes y calendario 60/45/35 con pregunta de control en último aviso anterior al tope; casos 29/02 y horario. **Código versionado; sin programar avisos** | §7–8, no requiere migración | Unit tests, contraste ejemplos whitepaper |
| **O8b — Avisos por anotación** | Crítica | CRUD permisos/edición de días y motivos; tres reglas por defecto (una vez aprobados motivos), edición/quitar/añadir, agenda de previstas, reprogramación/cancelación idempotente. | Definir defaults y creación tardía §18; O8a | Migración aditiva con backup+restore pre-migración, tests aislamiento y horario |
| **O9 — Pregunta de control y respuesta** | Crítica | Pregunta con «Sí» (3 opciones) / «No» y selector nunca después de fecha legal, repetirla según respuesta; auditoría con actor y momento. | O8b y casos Vida/late/no avisos | Tests mes civil, límites, audit y sin falsas entregas |
| **O10 — Bandeja de avisos** | Crítica | Responder «Completada», «Mañana», «Otro día»; avisos atrasados a resolver por promotor; estados reales separado de candidatos; recuento y escritorio sin falsas entregas. | O9, diseño entrega | Estados/eventos probados, reintento, deduplicación y seguridad |
| **O11 — Inicio diario UX** | Alta / en paralelo | Agenda HOY como página inicial, franja semanal, swipe, colores, buscador y botones +/hoy/mes; conservar acceso a configuración, Archivo y panel. | APIs día/mes ya existentes; control backlog pendientes | Flutter ES/CA 320–1440 px, pruebas táctiles y aceptación Android |
| **O12 — Equipos** | Alta / paralelo | Alta/baja miembros, reasignación transaccional y auditoría, permisos owner/member, actualización inmediata; upgrade Individual→Equipo. | MFA owner, UX roles | Negaciones cruzadas tenant y usuario, test de baja sin orfandad |
| **O13 — Resumen / Excel web** | Media / paralelo | Completar resultados **por usuario** (si se aprueba), plantilla de importación, previsualización de errores, import transaccional y export filtrada con permisos. | O7, decisiones de permisos Excel §18 | Export nunca mezcla tenants; sanitización de fórmulas Excel; cuotas, test CSV/XLSX |
| **O14 — Seguridad y archivo** | Bloqueante producción | MFA, cifrado DB/documentos, adjuntos privados con antivirus/límites, políticas RGPD de bloqueo y eliminación, 2 años por defecto, advertencias a 3 y 1 mes, contratos de subencargo, residencia UE, alerta externa de backup, segundo destino/restores. | Revisión jurídica, decisiones adjuntos | Auditoría seguridad independiente, RGPD, restauración y revocación de acceso |
| **O15 — Móvil y offline** | Bloqueante app stores | Flutter Android/iOS, sesiones móviles seguras y biometría, base local cifrada, cola y conflictos, avisos del dispositivo sin cobertura. | O8–O10 estable, política de conflictos §18 | Sin red/duplicados/cambio hora/zona, tests Android/iOS |
| **O16 — Comercialización** | Final | Precios y modalidades, pagos y tiendas, marca/legal, observabilidad, soporte y onboarding | Producto y seguridad aceptados; decisiones promotor §14 | Beta cerrada, privacidad validada, aprobación tiendas |

**Paralelización propuesta:** frente A lógica/casos límite (O8a→O8b→O9→O10); frente B interfaz y productividad (O7/O11/O13); frente C plataforma y permisos (O12/O14/O15), con gates propios. Mantener un único repositorio y pequeños commits con documentación de continuidad. No iniciar tres migraciones sobre PostgreSQL persistente simultáneamente. El cuello de botella real son notificaciones offline/seguridad, no la creación de pantallas.

## Decisiones del whitepaper aún abiertas; no resolver tácitamente

- Promotor: motivos predeterminados de los tres avisos; qué hacer con un aviso sin atender; alta tardía y aviso legal vencido; ausencia de aviso anterior al tope; motivo y repetición del recordatorio «Comunicar no renovación»; advertencia/fecha en Vida; permisos resultados/Excel y catálogo para empleados; MFA Individual; borrado/bloqueo y plazo formal del mediador; suscripción, precios y sociedad titular.
- Desarrollador: conflictos offline; tamaños y cuotas de archivos; residencia real de datos/backup en UE; proveedores de notificación/hosting/email con acuerdos; normas de pagos Apple/Google.
- Cerradas después de fuente: nombre **VENCIRA**; Flutter + Django + PostgreSQL; backups DEV diarios 03:00 Europe/Madrid y propuesta productiva cada 6 h; recuperar **también Conseguidas** por autorización expresa del promotor. Estas decisiones quedan trazadas como adendas, no reescriben el PDF.

## Norma de ejecución acelerada y segura

1. Desarrollar primero código puro, GET de lectura y pruebas sin migraciones ni comunicaciones externas.
2. Un validador único realiza Django completo SQLite + PG17 temporal, Flutter analyze/tests/build. Fallos se corrigen en GitHub; no desplegar a medias.
3. Para migraciones, seguir O4: backup previo restaurado en PG efímero, plan SQL, aplicar explícitamente **solo a `vencira_localcheck`** y verificar; nunca `down -v`.
4. Para notificaciones usar dobles sintéticos y no enviar correo, push ni alertas a terceros en DEV; ningún estado «entregado» inventado.
5. No introducir datos de clientes; no ampliar OAuth ni crear canales sin decisión. Registrar aceptación del usuario por escenario, no declarar `producción` solo por HTTPS saludable.
6. Mantener README y CONTINUITY_RUNBOOK actualizados en cada hito; GitHub PR o commit concreto, tests, resultado de despliegue y pendientes.

**Limitación de este corte:** los cambios O7 y O8a están preparados en código pero todavía no cuentan con ejecución real de tests sobre Ubuntu/CI, ni despliegue o aceptación funcional. O1–O6 aceptados y O5 rutina backup DEV operativa por evidencias del titular, no equivalen a V1 final.

## 25/10/2026 — AUDITORÍA INTEGRAL DEL WHITEPAPER ORIGINAL (NO SOLO O9)

El usuario solicitó revisar **todo el desarrollo actual** frente a los 23 folios del PDF original. Se completó revisión de árbol completo de rama `integration/local-e2e-prep` (275 entradas), modelos/migraciones `0001`–`0015`, APIs, UI Flutter, seguridad y pruebas, contrastados con §§1–18 del PDF fechado 18/10/2026. **Informe estructurado y evidencia por archivo/folio:** `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`. No hubo despliegue, migración ni pruebas dinámicas nuevas en esta auditoría. Último DEV confirmado: O9a + O8c operativas, PostgreSQL `0015`, notificaciones NO activadas.

**Dictamen: dirección y arquitectura ALINEADAS PARCIALMENTE; v1 NO completa.** Discrepancias en funcionalidades YA desarrolladas: (A-01) Flutter exige «Referencia» extra ajena a obligatoriedad §6 y API permite nuevos registros con entrada/nombre vacíos por compatibilidad; (A-02) «No aceptó» mueve +1 año pero `outcomes._rebuild_candidates()` solo usa políticas `enabled=True`, no reinicializa los avisos predeterminados 60/45/35 en la anotación; (A-03) «Conseguido» cambia solo esa anotación a Cliente, sin sugerir Cliente por defecto al crear posteriores anotaciones de la misma persona; (A-04) textos ES/CA aún escritos directamente en Dart, en contra de §13. Otras brechas de producto: `main.dart` abre Dashboard, no página HOY directa §5; O8c guarda solo días/borrrador sin motivos/programación; §7–10 notificaciones, respuestas auditadas/repeticiones aún no desarrolladas; team lifecycle, adjuntos, Excel, resultados por miembro, borrado automático/avisos de retención, apps móviles offline y MFA/RGPD incompletos. Catálogo DGSFP no precargado/verificado. §18 propuestas abiertas **NO son decisiones aprobadas**. No confundir tests verdes O8c/O9a con cumplimiento completo.

**Prioridad propuesta:** primero corregir cuatro desviaciones en funciones existentes con tests y sin activar envíos, luego O9b según 4 opciones exactas §8 p.11 y control civil, después agenda HOY/avisos, y finalmente componentes esenciales de lanzamiento. Mantener solo datos DEMO en DEV. **Documento de auditoría es fuente de verdad** para no perder desajustes al cambiar de chat: `docs/AUDITORIA_ALINEACION_WHITEPAPER_2026-10-25.md`.



## C1 — Primera decisión aprobada (25/10/2026)

El promotor respondió «Ok, mantenemos actualizados durante los trabajos, seguimos» a la propuesta de motivos. Se registra **aprobación conversacional** de los motivos predeterminados editables: **60 días** «Revisar vencimiento y contactar con el cliente»; **45 días** «Enviar notificación de no renovación»; **35 días** «Comprobar comunicación de no renovación y responder a la pregunta de control». Ello no supone envío real. La pregunta aparece en el último aviso elegible estrictamente anterior al límite del mes civil, que puede no ser el de 35 días. La configuración por cuenta/anotación sigue el §7 y no se alteran borradores existentes sin acción expresa. Esta actualización documental no ejecuta cambios funcionales, gates ni migraciones.

**C1 abierto:** avisos pendientes HOY, alta tardía, ausencia de aviso anterior al corte, Vida, autorización/evidencia de «Notificado por mí», canales y reintentos. Las propuestas §18 no equivalen a decisiones. Antes de C2 cotejar código existente y preparar pruebas; no repetir fases A/B.


## C1 — Regla de avisos no atendidos aprobada (25/10/2026)

El promotor respondió explícitamente «Sí, adelante» a la propuesta: en agenda HOY mostrar arriba los avisos internos vencidos no atendidos como **Pendientes**, por fecha original ascendente (más antiguo primero), sin desaparecer al cambiar de día; conservar acciones **Completada, Mañana, Otro día**; no duplicar al abrir HOY ni inferir una notificación entregada. Prioridad y persistencia son **regla de producto aprobada**, no certificación de que el código ya las satisfaga.

**Inspección estática inicial**: `backend/reminders/operational_api.py` conserva estados internos, CAS y `delivery_status=not_implemented`. `backend/reminders/reminder_planning.py` calcula los días transcurridos y marca altas tardías/no control, pero se abstiene correctamente de decidir §18 automáticamente. Falta verificar implementación concreta de filtrado/orden de HOY con tests; no reimplementar motor A/B. C1 siguientes decisiones abiertas: altas tardías y sin avisos anteriores al mes civil límite, modalidad Vida, evidencia y proveedores. No se ha ejecutado gate ni despliegue con esta aprobación.


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


## C2 — Primera entrega de código (25/10/2026)

Implementado en GitHub `backend/reminders/c2_control_policy.py` con pruebas `backend/reminders/test_c2_control_policy.py` (commit de tests `d4d3878b909929021fe1e8a24956da8a58bbb173`). Proyección **pura y sin BD** sobre `preview_reminder_plan`: permitir guardar; evaluar altas tardías, cero aviso pre-corte y corte vencido; ofrecer control explícito solo antes del corte (nunca programarlo por sí misma); Vida exige revisión de términos sin presentar mes civil como límite legal confirmado; conservar únicamente los offsets cuyos avisos no han transcurrido; estados de entrega `not_implemented`. Tests incluyen 29 febrero, meses cortos, límite hoy, tardíos y entradas inválidas. **Pendiente gate real Ubuntu**, integración de endpoints/UI, filtros HOY, evidencias y transportes Resend. No ejecutar migración ni desplegar por este cambio. Usar scripts de pruebas ya existentes, sin repetir B.


## C2 — API solo lectura integrada, pendiente gate Ubuntu (25/10/2026)

Commit `059fac89a1235f5538c9d09ae55302b9a11c81fe`: `control_assessment_api.py` integra la política pura C2 en la ruta GET autenticada ya existente, devolviendo `c2_policy` (guardar, revisión manual, severidad/código, corte informativo no Vida, posible ofrecimiento explícito y último día válido, offsets futuros, `delivery_status=not_implemented`). Se preserva el contrato anterior y se aplica visibilidad del workspace. Commit `1e2541ba4e603b488e9345afb250b18c3756d732`: regresiones del GET normal y borrador sin aviso previo en `test_control_assessment.py`. **No supone programación ni notificación**; integración Flutter, persistencia de revisión y política HOY pendientes. **Sin pruebas ejecutadas todavía**: en Ubuntu correr `bash scripts/validate_o7_o8_preflight.sh` tras sincronizar rama, sin desplegar. No tocar PostgreSQL persistente, backups ni Caddy. Si falla, corregir antes de continuar.


## C2 — Validación comunicada por usuario (25/10/2026)

Tras ejecutar el bloque de preflight, el operador compartió solamente `RESULTADO_EJECUCION=0` y `CONSOLA_ABIERTA`, **sin marcadores individuales** de SQLite, PostgreSQL17, Flutter ni `RESULTADO_GLOBAL`. El código de `scripts/validate_o7_o8_preflight.sh` sí ejecuta estas suites y devuelve error ante fallos, pero sin recibo completo no se inventan marcadores. Tratar como ejecución comunicada con salida 0, pendiente evidencia de gate desglosada antes de autorizar deploy. No se reportó migración/despliegue. Siguiente paso: comprobar marcadores seguros desde el log existente del preflight (no volcar secretos) y conectar UI después del gate confirmado.


## C2 — Gate integral aceptado y refinamiento visual pendiente de gate (25/10/2026)

El operador aportó marcadores completos del script `validate_o7_o8_preflight.sh`: salud PRE/POST OK, configuración Docker OK, i18n ES/CA OK, build backend aislado OK, comprobación seca de migraciones OK, suite Django SQLite OK, PostgreSQL17 efímero OK, suite Django PG17 OK, Flutter analyze/test/build OK, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1`; log privado `/tmp/vencira-o7-o8-preflight.ibm3OwLT.log`. El gate acredita el código **anterior** al siguiente cambio UI, no valida futuros commits.

Refinamiento visual posterior en commit `1756a54f2e9378db6e2ea51ec48da97839bc1fb2` de `control_assessment_card.dart`: avisos de control caducado/ausente más visibles con icono de advertencia del tema; en Vida se oculta la fecha límite general para no presentarla como plazo legal confirmado. **Pendiente nuevo gate completo y aceptación Flutter** antes de desplegar. El contrato `c2_policy` ya está publicado en código de API read-only, pero aún no se consume en el cliente tipado. Sin envío, migración ni deploy nuevos.


## C2 — Segundo gate OK; Flutter tipado posterior (25/10/2026)

El operador aportó recibo integral `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, `LOCALCHECK_HEALTH_PRE/POST=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `I18N_ES_CA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, con `NO_SE_DESPLEGO_NI_MIGRO_DB_PERSISTENTE=1` y `SIN_CAMBIOS_OAUTH_RESTIC_CADDY=1` (log local `/tmp/vencira-o7-o8-preflight.pa7pRnLe.log`). Gate válido para versión anterior al cambio siguiente.

Nuevo commit `cc86f88e6d4adfea320a5c60dadd633bf7635411` añade `VenciraC2Policy` y parser en `clients/flutter/lib/api/vencira_api.dart` para leer el contrato GET `c2_policy`, sin enviar ni persistir; campo opcional para compatibilidad. **Pendiente validación integral después de este commit**. También está pendiente la presentación UX definitiva de los avisos C2 y la confirmación de notificado por mí. No desplegar hasta gate real.


## C2 — Tercer gate OK; tarjeta revisión manual posterior (25/10/2026)

El operador confirma para el gate del modelo Flutter tipado: `LOCALCHECK_HEALTH_PRE/POST=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`; log `/tmp/vencira-o7-o8-preflight.r8jDE17f.log`; sin cambios en persistencia, OAuth, Restic o Caddy. Esto valida el commit anterior a la siguiente modificación.

Nuevo commit UI `967f5fa456b233f5608fdde581909cd4c2ec03de`: tarjeta `VenciraControlAssessmentCard` muestra un aviso destacado cuando `c2Policy.manualReviewRequired`, usando textos ES/CA existentes, Material theme y sin acciones simuladas. No se han creado ni enviado avisos. **Requiere gate nuevo antes de deploy**; queda pendiente UI de oferta explícita y proceso de aceptación/revisión, así como aviso de modalidades y canales. No modificar datos reales.
