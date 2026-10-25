# Macrofase B — Bandeja operativa y avisos sin atender (propuesta, 25/10/2026)

## Estado de partida
- Macrobloque A: usuario declara funcionalmente validada la UI de avisos internos en DEV; esquema PostgreSQL 0018. Avisos externos NO implementados.
- O11 agenda HOY y franja semanal ya existentes; NO duplicar navegación ni reescribir vistas aceptadas.
- Whitepaper §18 mantiene ABIERTA la decisión sobre aviso no atendido: el comportamiento descrito aquí es propuesta conservadora, NO norma aprobada.

## Alcance propuesto
1. Bandeja de **hoy**: ocurrencias internas por fecha y organización, con identidad de registro, estado y acceso a ficha.
2. **Atrasados**: ocurrencias planned/pending/snoozed con scheduled_for anterior a fecha local y no completadas; mantener visible fecha original y distinguir aplazamientos.
3. Acciones ya implementadas: completar, mañana, otra fecha; reutilizar CAS, idempotencia y límites del control; no enviar notificaciones.
4. Resumen de contadores por día/semana/organización y búsqueda sin mezclar tenants.
5. Historial de eventos con actor/hora, sujeto a autorización y sin exponer datos de terceros.
6. ES/CA, responsive móvil/escritorio y estado vacío/error diferenciado.

## Puertas
- Aclarar o aceptar decisión §18 sobre avisos no atendidos antes de cerrar semántica de producto; predeterminado prudente: NO marcar completado/cancelado automáticamente.
- Ningún GET debe crear eventos; ninguna notificación declarada entregada.
- Tests Django SQLite + PG17 efímero: límites de días civiles/zona horaria, overdue, CAS, isolation, idempotency, paginación/contadores.
- Flutter analyze/test/build, ES/CA, anchuras 320/375/768/1440, visual Android.
- Si migraciones nuevas: gate O5 respaldo restaurable y clon, despliegue explícito.
- No operar sobre datos reales ni anunciar aptitud de producción.

## Continuidad
Siguiente acción técnica: auditar endpoints actuales de agenda y modelos OperationalReminder antes de implementar bandeja; reutilizar los componentes y servicios existentes.

## 25/10/2026 — Primera entrega implementada en GitHub; SIN pruebas locales ni despliegue
- Endpoint GET `/api/v1/workspaces/<ws>/operational-inbox/?day=YYYY-MM-DD&scope=due|today|overdue|upcoming&page=1` en `backend/reminders/operational_inbox.py` y ruta `urls.py`. Scope obligatorio de membresía y asignación `_visible_renewals`, excluye cerradas/archivadas, estados activos solamente, conteos por ocurrencia, límite 30/página con máximo 100; `Cache-Control: no-store`, no mutaciones ni mensajes enviados.
- `backend/reminders/test_operational_inbox.py`: tests previstos de corte por día, permisos multi-tenant, dueño/miembro, archivados, paginación y no side effects.
- `clients/flutter/lib/api/vencira_api.dart`: DTO validado y petición HTTP autenticada a bandeja. `clients/flutter/lib/ui/operational_inbox_screen.dart`: pantalla móvil/escritorio con filtros, contadores, navegación a anotación y acciones existentes `complete/tomorrow/another_day`; acceso desde Dashboard; traducciones ES/CA y tests de parser.
- `scripts/validate_macro_b_readonly.sh`: gate integral aislado Django SQLite + PG17 efímero y Flutter (analyze/test/build); **AÚN NO EJECUTADO** en Ubuntu. DEV NO ha cambiado (se mantiene migración 0018).
- La decisión §18 sobre aviso no atendido sigue pendiente: la bandeja conserva las ocurrencias atrasadas y no altera estados automáticamente. Falta revisión de visual, histórico por evento en bandeja, límites funcionales y pruebas E2E con sesión autenticada. No confundir código en GitHub con producto desplegado.

## 25/10/2026 — Macrofase B: gate OK; despliegue API+Web protegido PREPARADO, NO ejecutado

- El usuario ejecutó `scripts/validate_macro_b_readonly.sh` en Ubuntu; `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `O7_O8_PREFLIGHT_SIN_DESPLIEGUE=OK`, `RESULTADO_GLOBAL=0`, `MACRO_B_GATE_INTEGRAL=OK`, `MACRO_B_GATE_RESULTADO=0`. Log `/tmp/vencira-o7-o8-preflight.arUdsBEY.log`. Previo fallo de `widget_test.dart` resuelto en commit `f893329c`.
- Implementado `scripts/deploy_macro_b_api_web_guarded.sh` (commit `8004df13`): comprueba fuentes iguales al gate `f893329cb3372cea491e3c06fa1b2c1fda3d3c65`, O5 leído sin alterar, esquema vivo 0018, imágenes antiguas etiquetadas y recibo privado, build de API+Flutter, `migrate --check` (NO MIGRA), despliegue secuencial de api/web, health, validación de ruta inbox anónima denegada, identidad DB y conteo migraciones constantes.
- **NO DESPLEGADO**. Operador: pull, `bash -n scripts/deploy_macro_b_api_web_guarded.sh`; luego `sudo env MACRO_B_DEV_CONFIRM=DEPLOY_API_WEB_NO_MIGRATIONS bash scripts/deploy_macro_b_api_web_guarded.sh`. No repetir a ciegas si falla, revisar FASE_FALLIDA y logs saneados. Scripts anteriores de macro A NO válidos para B.
- Restan E2E autenticado (bandeja hoy/atrasados/próximos, acciones, permisos usuario) e historial visible, decisión explícita del usuario sobre política de atrasados.

## 25/10/2026 — Rediseño premium solicitado tras revisión Android (GitHub, NO desplegado)
- El usuario comprobó bandeja B en Android: endpoint y datos funcionan, pero proliferación de botones en inicio y tarjetas. Solicitó mejora visual consistente y revisada frente a Flutter/Material 3. Screenshots muestran accesos Agenda/Añadir, Archivo/Bandeja, contadores y cuatro acciones repetidas por tarjeta.
- Implementación UI: `clients/flutter/lib/ui/operational_inbox_screen.dart` cambió tres chips de contadores por resumen en tres columnas, cuatro ChoiceChips por un `SegmentedButton` horizontal desplazable, tarjetas `Card.outlined` enteramente pulsables (abre ficha) y un icono de tres puntos que abre `showModalBottomSheet` con estilo de Preferencias. Acciones preexistentes: detalle, completar, mañana, elegir fecha; conserva API, CAS, permisos, ES/CA y no interpreta avisos como enviados.
- Inicio `dashboard_screen.dart`: Archivo y Avisos agrupados en fila de acciones secundarias compactas, conservando las keys de test; etiqueta corta ES/CA `inboxShortcut`.
- Tests nuevos `clients/flutter/test/operational_inbox_premium_test.dart` para 320/375/768 px, ausencia de botonera repetida, sheet y aplazamiento. **No ejecutados aún en Ubuntu.**
- Script de despliegue solo web `scripts/deploy_macro_b_premium_ui_web_guarded.sh`, exige fuente Flutter igual al commit `5294399dfde338f63f58887e119aaa3f9c537f5b`, confirma API B previa protegida y conserva web anterior, sin modificar API/DB ni migrar.
- **PRÓXIMO PASO:** git pull; `bash scripts/validate_macro_b_readonly.sh` (gate aislado Django SQLite/PG17 y Flutter); corregir cualquier fallo. SOLO SI termina `MACRO_B_GATE_RESULTADO=0` ejecutar `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Aceptación final móvil pendiente; macro B no cerrada.
