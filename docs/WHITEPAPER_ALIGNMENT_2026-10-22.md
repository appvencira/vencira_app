# VENCIRA — Control de conformidad con el whitepaper (18/10/2026)

**Fuente de producto:** `White_paper_agenda_vencimientos.pdf`, «Agenda de vencimientos externos para mediadores de seguros», @Bibroker Mediadores, S.L.U., 23 páginas, 18 de octubre de 2026. El nombre comercial **VENCIRA** fue aprobado después; la sección 17 del documento aún presenta nombres candidatos.

## Requisitos vinculantes que guían esta fase

| Whitepaper | Consecuencia |
|---|---|
| §1 y §2: cada «anotación» es una póliza externa; no es un CRM | Ficha individual por anotación y referencia sintética; no crear una entidad de cliente común |
| §3, §11: historial **solo web de ordenador**, propio para usuarios y completo para administrador | Vista Flutter muestra botón de historial únicamente en `kIsWeb` con ancho de escritorio (>=800 px); servidor comprueba `workspace` y asignación en **cada GET** |
| §6: Entrada Clientes/Candidatos; nombre, póliza, modalidad, aseguradora, vencimiento, notas, archivos, avisos, asignación | **Todavía no implementados en esta fase**: el esquema existente es parcial (referencia, vencimiento, preaviso opcional y estado provisional); la UI avisa explícitamente |
| §9: cuatro desenlaces («Conseguido», «No aceptó», «Aún sin decidir», «Descartar») | No equivalen a `pending`/`contacted`/`closed`; **no inferir cierres ni introducir transiciones simuladas** |
| §11: historial automático con creación, avisos saltados, control, mañana/otro día/recuérdamelo, cambios de vencimiento, cierre y reasignación | La API actual registra **creación y actualización** (incluyendo cambio de fecha/estado/asignación cuando existen). No inventa avisos enviados o gestiones inexistentes |
| §11: nadie puede modificar ni borrar el historial | El endpoint de lectura admite **solo GET**, sin PATCH/POST/DELETE; todavía falta garantizar inmutabilidad estricta en base de datos (revocación de privilegios/triggers) antes de alegar conformidad absoluta |
| §8: fecha límite **legal** calculada (un mes antes) no figura en la agenda; es un tope | El campo existente `notice_deadline_on` es un preaviso opcional/contractual introducido por usuario, **no el cálculo legal automático**. No confundirlos. La proyección anterior requiere revisión de producto para alinear conceptos |
| §12: RGPD, cifrado, borrado y bloqueo | No introducir nombres reales, DNI, fotos ni archivos en la instalación pública de desarrollo; pendientes cifrado en reposo, retención, borrado y validación jurídica |
| §13: ES/CA | Nuevos textos en ARB, sin literales visibles de dominio en Flutter |

## Implementación incremental comprobable

1. `GET /api/v1/workspaces/{workspace}/renewals/{renewal}/` ya existía; usado ahora para cargar la ficha actualizada de una anotación específica, sin confiar en datos precargados de la agenda.
2. `GET /api/v1/workspaces/{workspace}/renewals/{renewal}/history/?page=N` nuevo. Reutiliza `RenewalAuditEvent` existente, consulta limitada y paginada, cuenta y marcas temporales, usuario que actuó y campos cambiados; nunca incluye el valor de `customer_reference`. `Cache-Control: no-store`; permisos aplicados antes de leer eventos; 404 para ajenos.
3. Flutter: tarjetas en agenda diaria y lista del panel abren `Ficha de anotación`; muestra los campos existentes y el editor actual, y actualiza la vista al regresar. El historial de escritorio tiene paginación y manejo de fallo; no aparece en móvil/tablet nativo ni en web estrecha.
4. Sin migraciones ni alteraciones de tablas, cookies, políticas ni Caddy. Se preserva `vencira_preview`.

## Diferencias bloqueantes para la ficha V1 definitiva

**Prioridad 1 — Modelo:** convertir `Renewal` de prototipo a «Anotación» con `Entrada`, `Nombre/Razón social`, `Nick`, `Teléfono`, `Email`, `Modalidad`, `Nº de póliza`, `Aseguradora`, `Notas`, documentos y asignación. Planificar migración no destructiva, desde los datos sintéticos de prueba actuales, sin asumir que `customer_reference` sea nombre real.

**Prioridad 2 — Ciclo:** tipos de cierre del §9, fecha de reintento al año siguiente, «Aún sin decidir» con nueva fecha, «Conseguido» y «Descartar» archivados, y retención. No confundir estos desenlaces con estado `contacted`.

**Prioridad 3 — Avisos:** reglamento de 60/45/35 días, motivos, pregunta de control del §8, fechas límites legales calculadas de fecha a fecha, repeticiones, registro de **ejecución** de avisos, y auditoría. **No fingir entrega** por existir un `ReminderCandidate`.

**Prioridad 4 — Seguridad legal:** imponer historial append-only **también en la base de datos**, cifrado en reposo, políticas de backup/retención/bloqueo y normativa RGPD. El whitepaper reconoce casos pendientes en §18 que requieren decisión del promotor: no resolverlos tácitamente.

## Pruebas

- Django: historial autorizado solo para propietario y asignado; aislamiento de organizaciones; API exclusivamente GET; no almacenamiento de referencia sensible; filas anteriores sin eventos no se interpretan como auditadas.
- Flutter: apertura desde tarjeta, API validada por UUID/mismo origen y ausencia de botón de historial en interfaz móvil/nativa.
- HTTP E2E: crear/anotar/editar referencia ficticia; obtener ficha e historial `created`+`updated`; verificar no filtrar la referencia en el historial ni permitir acceso tras logout.

**Despliegue**: no actualizar `dev.vencira.es` hasta validar las pruebas de CI del commit exacto. En VPS reconstruir solo `api web_preview` del proyecto `vencira_localcheck`, sin reiniciar DB ni cambiar Caddy; el entorno previo permanece sin cambios.

*Este documento explicita las diferencias de prototipo. No constituye declaración de cumplimiento legal completo.*
