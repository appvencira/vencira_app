# VENCIRA — Plan acelerado de ejecución V1 por macrobloques
**Fecha:** 25/10/2026 · **Rama:** `integration/local-e2e-prep` · **Fuente normativa funcional:** `docs/source/WHITEPAPER_ORIGINAL_2026-10-18_TRANSCRIPCION.md` (whitepaper original, 23 pp., 18/10/2026).  
**Estado del documento:** planificación, **NO certificación de funcionalidades no probadas**. No cambia código, DB ni despliega servicios.

## 0. Base comprobada y método nuevo

**Confirmado en DEV con resultados Ubuntu y capturas 25/10/2026:** backend Django + PG17, migración `reminders.0016_renewal_control_responses`, Flutter Web ES/CA, calendario y anotación básica, borrador de avisos por anotación y evaluación de control, respuesta manual Sí/No e historial, respaldos Restic/Drive O5 restaurados en PG17 temporal, 172 pruebas Django por motor y `flutter analyze/test/build` superados en preflight, despliegue web O9b-3 saludable, usuario probó manualmente Sí y No. **NO existe evidencia de que mensajes reales se estén enviando, de que el No programe una tarea efectiva, de offline nativo, de archivos, Excel, MFA o pagos completos.** No elevar cobertura parcial a completitud.

**Cambio de ritmo: macrobloques verticales completos** (modelo de datos + reglas + API + Flutter + ES/CA + tests + guía) en el repositorio, cada uno con 1 preflight integral y 1 despliegue protegido; gates intermedios locales/CI, sin pedir al promotor ejecutar comandos tras cada fichero. Hitos atómicos para control de riesgo, no microfases de producto. Cualquier migración persistente: snapshot O5 reciente cifrado, recuperación real de snapshot en PG17 aislado, prueba de migración sobre clon, plan SQL/migrate, gate explícito, conservación de imágenes, migración única, checks de schema y health post. Rollback DB nunca automático. Para web-only, sin migraciones ni reinicios de API/DB. No tocar Caddy, OAuth, Restic, timers ni otras apps sin una necesidad demostrada y gate propio.

## A — Motor completo de ciclo de avisos, agenda y control (P0; PRIMER MACROBLOQUE)

**Fuente:** whitepaper §§5, 7, 8, 9, 10, 11 (pp. 5–14), §18. Integra en **una entrega funcional**, no seis sprints aislados:
1. Avisos por anotación configurables y motivos editables (por cuenta/administrador donde proceda); valores iniciales 60/45/35 días antes de vencimiento; hora local por usuario por defecto 09:00 y sonido por usuario. Separar configuración borrador de avisos habilitados; no considerar el O8c `draft` como entrega.
2. Planificador civil persistente con zona horaria `Europe/Madrid`, fecha de vencimiento y preaviso de un mes de fecha a fecha, mes corto (31/03 -> 28/02 o 29/02); último aviso **estrictamente anterior** al límite legal contiene la pregunta; mover/retirar avisos recalcula; modalidad Vida exige revisión humana: nunca aplicar regla de art.22 automáticamente como certeza; otros plazos de póliza se respetan si están informados.
3. Máquina de estados de cada aviso: `scheduled/pending/snoozed/completed/cancelled` (nombres técnicos propuestos), reprogramar **Mañana** y **Otro día**, en fechas civiles, conservando motivo y trazabilidad, sin duplicados ni pérdida por reinicios; avisos pasados, creación tardía, cambio de vencimiento, cierre, restauración y renovación anual invalidan/renuevan ocurrencias futuras de forma coherente.
4. Respuesta **Sí** con las tres opciones del whitepaper y registro inmutable actor/hora; respuesta **No** crea efectivamente aviso «Comunicar no renovación de [nombre]», vuelve a formular la pregunta hasta fecha límite, sin poder escoger después del corte; bloquear selector y mostrar aviso si ya está vencido. El registro manual O9b existente no prueba todavía estas acciones, por lo que requieren contrato/versionado y migración de manera explícita.
5. Misma vista de agenda/semana/mes con vencimientos, avisos reales pendientes, reprogramados, solicitudes de control y cierres; diferenciación visual de «planificado», «emitido», «entregado», «atendido» y «fallido», sin afirmar envío sin recibo verificable. Historia técnica solo web escritorio según §11; respuesta manual propia puede permanecer visible en la ficha en móvil como control operativo, sin denominarla «historial completo» sin aprobación.
6. Seguridad y QA: aislamiento cuenta/usuario, CAS revision/idempotencia, fechas DST, febrero, simultaneidad, replay, borrado/cierre, vencimientos atrasados, zonificación, auditoría e integridad. Pruebas API + Flutter + migración PG17 clon.

**Canales reales se habilitan en macrobloque B**, detrás de bandera apagada por defecto; A permite pruebas de programación y ejecución simulada en sandbox sin avisar a terceros.

**Aceptación A:** un `No` de prueba genera evento futuro visible, una nueva pregunta en fecha admitida, jamás posterior al límite; los estados y reprogramación no producen dos envíos; Vida se deriva a revisión; fechas y hechos registran autor y momento sin sobreescritura.

## B — Notificaciones de verdad + resiliencia móvil/offline (P0)

**Fuente:** §§4, 7, 8, 13 (pp. 4–5, 9–11, 16) y §18.
1. Aísla notificaciones como proyecciones del motor A: outbox/entregas idempotentes + estados `planned/attempted/accepted/delivered/failed` con semántica real por proveedor; reintentos acotados, alarmas operativas, rate limits, historial auditable sin almacenar secretos. Canales aprobados: push nativo iOS/Android (también con app cerrada), web mientras está abierta + contador, resumen email diario **opt-in desactivado inicialmente**. Cada usuario elige 09:00 predeterminada y sonido; sin envíos externos hasta pruebas de sandbox y aprobación explícita.
2. Flutter móvil nativo iOS/Android desde mismo código con almacenamiento local cifrado y colas offline. Agenda, fotos, anotaciones, respuesta a avisos y alarmas **en dispositivo** sin cobertura, luego reconciliación con eventos idempotentes y conflict handling explícito, sin `last write wins` silencioso. Revocación de usuario y cambio de cuenta requiere invalidación de caché local; protección del dispositivo (bloqueo/biometría) y expiración de sesiones.
3. Push token/lifecycle/rotación, permisos de notificación, husos y horarios de verano, limpieza al cierre/reasignar/eliminar; pruebas con dispositivos reales offline/app cerrada. No confundir web Android (PWA) con app nativa y alarmas locales garantizadas.

**Aceptación B:** recordatorios locales funcionan sin red, se sincronizan sin duplicados cuando vuelve; pruebas reales iOS/Android, web y email opt-in evidencian envío/recepción según sus propias definiciones.

## C — Ficha íntegra, archivos, contactos, Excel y trabajo diario (P1)

**Fuente:** §§5, 6, 9, 11 (pp. 6–9, 12, 14).
- Aseguradora/modalidad y listas (motivos incl.) precargables/editables según rol; búsqueda por nombre/nick/póliza; sugerencias de datos de otras anotaciones con confirmación; conversión candidato→cliente tras `Conseguido`; notas y archivo; cuatro desenlaces completos (ganado, anual siguiente y avisos restaurados, sin decidir, descartar).
- Adjuntos imágenes/PDF con nombres cortos, escaneo cámara/galería móvil y drag/drop escritorio. Validación real de tipo, cuota aún por determinar, antivirus/sandbox, URL firmada temporal, cifrado, aislamiento tenant, eliminación auditada; datos sensibles ficticios durante DEV.
- Contactos nativos solo si usuario selecciona/exporta uno, **jamás lectura masiva**.
- Excel **solo escritorio**: plantilla de importación, preview de errores antes de escribir, alta masiva transaccional con avisos por defecto; exportación con filtros y permisos. Resumen de resultados por periodo y asignado, sin mezclar resultados de otro usuario.
- Diseño responsive con agenda tipo papel (hoy, franja semana, gestos, mes, colores, contador, búsqueda y filtros). Historias web escritorio según §11, no forzar una ficha CRM.

**Aceptación C:** importación de ejemplos falsos con filas malas da diagnóstico sin altas parciales inesperadas; permisos y archivos aislados; exportación coincide con filtros; cierres actualizan agenda y resultados.

## D — Cuentas Equipo, seguridad, conservación y operaciones (P0/P1 transversal)

**Fuente:** §§3, 12, 13, 16 (pp. 3–4, 15–20).
- Individual→Equipo sin pérdida, administrador trabaja con agenda propia y ve la de su equipo, crea/revoca usuarios y reasigna anotaciones; usuarios ven solo las suyas; permisos centralizados API, pruebas adversarias cross-tenant, revocación inmediata y limpieza offline pendiente.
- MFA (admin obligatoria; Individual pendiente de decisión), rate limiting, control sesiones, biometría local, bloqueo por inactividad; políticas cookies/CSRF/cifrado y secretos; proveedores/datos/regiones UE y contratos de subencargo.
- Archivo con caducidad configurable (2 años por defecto), preavisos de purga 3 y 1 meses, eliminación manual, mecanismo de bloqueo/retención legal por validar con asesor; **nunca destruir datos ni activar purga antes de resolver flujo legal, QA, snapshot/restore y autorización**.
- Auditoría inmutable actor/tenant/acción y políticas de minimización/RGPD; DR/restic metadata + ensayo recuperación, observabilidad de los jobs y estado proveedores; diagnóstico visible sin exponer PII.
- Idiomas ES/CA en frontend, email y push.

**Aceptación D:** test de autorización multi-tenant/revocación; restauración probada; pruebas de datos en reposo/transporte y residencia; política de eliminación acordada antes de activar borrados físicos.

## E — Suscripción, empaquetado y lanzamiento (P1, decisiones comerciales)

**Fuente:** §§3, 4, 14, 17, 18 (pp. 3–5, 16–17, 21–22).
- Entitlements Individual/Equipo, trial/suscripción y webhooks transaccionales preparados para proveedor seleccionable, estados `trial/active/past_due/suspended` solo propuesta técnica, precios y proveedor **sin inventar**.
- Packaging iOS/Android, pruebas en tiendas, política de facturación Apple/Google **pendiente de verificación antes de implementarla**, publicación gradual, QA seguridad/multidispositivo, legal/privacidad, copia restaurable y plan incidente.
- Marca **VENCIRA** ya elegida fuera del whitepaper (que deja nombre abierto); verificar registros OEPM/EUIPO clases 9/42 y disponibilidad en tiendas antes de publicación comercial.
- NO V1: carta de no renovación con firma/envío certificado ni OCR/lectura automatizada (§15). Dejar interfaces extensibles, no hacerlas ahora.

**Aceptación E:** release candidato completado en Android/iOS/web, entitlements probados y cobros solo cuando promotor cierre decisiones, política y contrato validados.

## Dependencias, prioridades y decisiones sin inventar

`A → B` para notificaciones y offline; `A → C` para agenda/importaciones reales; `D` en paralelo continuo y obligatorio antes de tráfico real; `C+D → E` para producto comercial. Se pueden desarrollar submódulos en paralelo sin desplegar una mitad incompatible.

### Decisiones originales abiertas (§18) a conservar como abiertas

**Promotor, 14 puntos:** (1) obligatorios; (2) motivos iniciales; (3) avisos no atendidos; (4) creación tardía; (5) repetición tras No; (6) ausencia de aviso precorte; (7) Vida; (8) usuarios Equipo y resultados; (9) usuarios Equipo y Excel; (10) usuarios Equipo y catálogos; (11) MFA Individual; (12) bloqueo jurídico antes de borrar; (13) nombre; (14) suscripción, precios y sociedad. El nombre ya se resolvió extrawhitepaper: **VENCIRA**. Implementar solo propuestas **reversibles, etiquetadas como provisionales y seguras** en cuestiones sin aprobación; no activar decisiones de negocio/destrucción/legal implícitamente.

**Desarrollador, 6 puntos:** (1) stack multiplataforma (Flutter+Django+PG17 elegido), (2) resolución de conflictos offline, (3) límites/cuotas adjuntos, (4) backups/residencia UE, (5) reglas de suscripción tiendas, (6) proveedores push/email/alojamiento + DPAs. Documentar decisiones ADR, no inferir que están todas cerradas por contar con base técnica.

### GATES reducidos sin reducir seguridad

| Gate | Tras qué | Qué acredita | Despliegue |
| --- | --- | --- | --- |
| G-A | A completo | 2 motores de test + Flutter, simulación futura, clone restore y migración | API + WEB con respaldo O5 y prueba PG17 |
| G-B | B completo | push/email sandbox, offline real iOS/Android, no duplicados ni fugas | canales apagados primero, opt-in separado |
| G-C | C completo | import/export ACL, archivos, cuota, UI responsive | API+WEB, móvil compatible |
| G-D | D completo | rol/revocación, MFA, borrado solo simulado hasta resolución jurídica | explícito, auditoría y restauración |
| G-E | E completo | compras/tiendas/privacidad/producción | publicación gradual / gate comercial |

**Inmediato:** ejecutar desarrollo del macrobloque A como conjunto (migraciones, motor de agenda, reglas Sí/No y reprogramación, endpoint, UI, pruebas y documentación) en repositorio; no solicitar al usuario una verificación por cada commit. Solo pedir consola en gate agregado; mantener copia O5 restaurable y DEV 0016 intacta hasta ese momento.
