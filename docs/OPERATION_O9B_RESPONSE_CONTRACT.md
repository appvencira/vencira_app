# VENCIRA — O9b: contrato fiel al whitepaper para pregunta de control y repetición

**Fecha:** 25/10/2026. **Estado:** contrato funcional documentado tras recibir el PDF ORIGINAL de 23 páginas. No hay código de respuestas O9b desplegado, ni migración `0016`, ni notificaciones activas. O9a sigue operativa en DEV; PostgreSQL persistente está en `reminders.0015_renewal_reminder_drafts`.

**Fuente primaria verificable en GitHub:** [transcripción íntegra de las 23 páginas](source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md), procedente de `White_paper_agenda_vencimientos.pdf`, @Bibroker Mediadores, S.L.U., 18/10/2026, SHA-256 `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66`. El PDF original es la fuente visual de maquetas y tablas; la transcripción facilita búsqueda. Apartados decisivos: **§7 pp.9–10, §8 pp.10–11, §10 p.13, §11 p.14, §16 p.20, §18 p.22**.

## 1. Contrato FUNCIONAL YA APROBADO — no requiere nuevas decisiones del promotor

**Pregunta EXACTA (§8 p.11):** «¿Se ha notificado a la aseguradora su no renovación?».

Ubicación: **último aviso cuya fecha sea estrictamente ANTERIOR** a la fecha límite legal. Valores predeterminados: aviso de 35 días; si se mueve/borra, trasladar la pregunta al último elegible que permanezca. Fecha límite: **mismo día del mes anterior al vencimiento**, o último día del mes anterior si no existe el equivalente (§8 pp.10–11). La fecha límite sirve de tope, no se introduce como evento de agenda; en una pantalla de detalle de diagnóstico puede mostrarse como referencia informativa, sin confundirla con cumplimiento real.

| Respuesta | Alternativa / texto EXACTO del documento | Comportamiento prescrito |
| --- | --- | --- |
| **Sí** | **Avisada por el cliente** | Registrar opción en historial, fecha, hora y usuario. La anotación continúa en agenda hasta un cierre independiente. |
| **Sí** | **La aseguradora no renueva** | Igual: auditar y mantener anotación, sin cierre automático. |
| **Sí** | **Notificado por mí** | Igual: auditar y mantener anotación; §16 p.20 advierte que si el mediador envía la oposición debe contar con firma o autorización del cliente. |
| **No** | **Avísame dentro de [selector de días]** | Crear nuevo aviso con motivo «Comunicar no renovación de [nombre del cliente]» para la fecha elegida. §10 p.13: ese aviso **vuelve a mostrar la pregunta de control** y puede repetirse, siempre respetando el límite. |

**Tope para «No»:** el selector no permite elegir una fecha **posterior a la fecha límite**. Si la fecha límite es hoy o ya pasó, la UI la señala en rojo (§8 p.11). También debe recomendar **no apurar el último día**, por posible retraso de burofax/correo certificado y necesidad de prueba de entrega. El whitepaper no establece una cantidad máxima de repeticiones ni un conjunto cerrado de incrementos para esta pregunta (aparte del selector de días); por tanto no fijar ninguno sin una decisión expresa.

**No confundir con las acciones ordinarias de aviso (§7 p.10):** «Completada», «Mañana» y «Otro día…» son botones de cada aviso y NO equivalen a responder «Sí»/«No» a la pregunta especial.

**Historial (§11 p.14):** inalterable por usuarios, cada evento con fecha, hora y usuario. Registrar las respuestas y opciones elegidas, los avisos que hayan saltado realmente, los «Mañana», «Otro día», «recuérdamelo», cambios de vencimiento y cierres. No falsificar aviso emitido por la mera existencia de una fecha calculada.

## 2. Lo que SÍ permanece pendiente en el documento original (§18 p.22)

1. **Anotación creada tarde:** la propuesta aún no aprobada es no crear avisos pasados y presentar la pregunta al guardar si el plazo está cerca/ha pasado, con alerta roja.
2. **Sin avisos antes de la fecha límite:** la propuesta (no aprobada) es impedir guardar o crear automáticamente uno de control. La versión actual O8c permite un borrador `20,15` sin aviso elegible y O9a lo diagnostica sin modificarlo.
3. **Aviso repetido «Comunicar no renovación de [nombre]»:** la propuesta de volver a mostrar la pregunta figuraba en §18 y también se especifica en §10 p.13. **La repetición de la pregunta está documentada en §10**; el manejo de excepciones y la política concreta de entrega/reintento siguen sujetos a validación.
4. **Pólizas Vida:** advertencia al elegir esa modalidad es propuesta pendiente (§18); §16 p.18 advierte que el artículo 22 podría no aplicar de igual forma. Sin suponer reglas legales uniformes.
5. **Motivo por defecto de cada aviso 60/45/35:** sigue pendiente. §7 p.9 sí fija lista mínima editable de motivos: «Enviar notificación de no renovación», «Pedir videoperitaje» y «Pedir documentación al cliente».
6. **Avisos no atendidos:** propuesta pendiente de mantenerlos visibles como «Pendientes» en la parte superior de HOY (§18). No atribuirle un estado de entrega o respuesta.

Otros aspectos aún pendientes (§18): opciones de Excel/Resumen por miembro, listas editables, MFA, borrado con bloqueo, pagos, límites de adjuntos, conflictos offline y proveedores de notificación.

## 3. Modelo técnico PROPUESTO para implementar O9b (NO implementado)

Crear una tabla de respuestas separada del borrador (nueva migración **aditiva** candidata `0016`) que almacene anotación, actor, momento, elección `yes/no`, opción `yes` entre tres códigos estables (`notified_by_client`, `insurer_not_renewing`, `notified_by_mediator`) o fecha de repetición para `no`, versión CAS y evento de historial inmutable. Los códigos son **propuesta técnica de persistencia**; las etiquetas visibles anteriores son las del PDF. Responder Sí **no** cierra, archiva ni marca Conseguido. Responder No **no** prueba entrega ni notifica por sí solo: la ejecución efectiva corresponde al motor O10. Cada nuevo aviso debe conservar identidad propia y vínculos a la respuesta que lo creó.

Reglas mínimas de implementación sin reinterpretar el whitepaper:
- Fecha civil `Europe/Madrid`; mes civil, **no 30 días**. Rechazar fecha futura más allá del tope. No agendar retroactivamente.
- Escrituras autenticadas, CSRF, workspace/owner/asignado, control de concurrencia y auditoría. Cerrar/archivar impide responder; no permitir cross-tenant. Seguir criterio establecido en O4/O8c.
- Una respuesta sin fecha de control real emitida debe diferenciarse de un registro manual prospectivo; diseño de evidencia entregada pendiente O10. O9a no cambia de estado por sí sola.
- Mensajes ES/CA conforme a traducciones, no alterar la semántica textual al traducir.
- Pruebas: cuatro opciones exactas, historial actor/hora, «Sí» no cierra, «No» crea **únicamente** plan de aviso y vuelve a preguntar cuando sea ejecutado, selector en límite y más allá, febrero bisiesto, 20/15 sin aviso elegible, altas tardías/Vida, seguridad, repetición y deduplicación.

## 4. Plan controlado siguiente

1. **O9b-1:** implementar validador puro de opciones y selección de día (sin DB ni avisos), tests de fechas/casos límite. Usar el PDF primario como contrato.
2. **O9b-2:** preparar migración `0016` y auditoría, test SQLite+PG17 efímero, y ensayo O4 de restauración O5 antes de tocar PostgreSQL persistente.
3. **O9b-3:** UI de respuesta Sí/No ES/CA y pruebas responsive, inicialmente sin entregas; aceptar manualmente. Después abordar O10 por separado, distinguiendo aviso programado, efectivamente disparado, entregado y respondido.

**Estado al cierre:** O9a desplegada, O9b documentada según fuente ORIGINAL; no migraciones nuevas y no envío de notificaciones.
