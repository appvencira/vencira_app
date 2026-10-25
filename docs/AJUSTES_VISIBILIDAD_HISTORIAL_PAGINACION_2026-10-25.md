# VENCIRA · Visibilidad del historial y paginación consistente
Fecha: 25/10/2026. Estado: implementado en GitHub, **PENDIENTE de gate y despliegue**.

## Observación del usuario
Capturas Android, tema oscuro: no encontraba ningún botón de historial desde Agenda diaria ni Archivo y cerrados. Los botones de paginación "Anterior", "Página 1", "Siguiente" aparecían centrados en Archivo pero alineados a un lado en otras pantallas.

## Causa
- Historial de cambios general de la ficha se muestra solo en web >=800 px.
- Historial de actuaciones de avisos estaba oculto en el panel de recordatorios dentro de una sección expandible y en el menú de tres puntos de bandeja; no había acceso visible y directo desde la ficha de una póliza, especialmente si estaba cerrada.
- Diversas pantallas implementaban barras de paginación de forma distinta (Wrap alineado al inicio, Row spaceBetween, etc.).

## Implementación
- `clients/flutter/lib/ui/renewal_detail_screen.dart`: botón claramente visible `Historial de avisos` bajo la cabecera de la anotación para **cualquier estado**, también `closed` o archivado; key `detail-operational-history`. No altera ni reemplaza historial general de cambios para escritorio.
- `clients/flutter/lib/ui/operational_history_index_screen.dart`: índice de avisos persistidos en esa anotación, sin mutación; filas con motivo, día, estado (incluidas completadas y canceladas); abre `operational_history_screen.dart` del aviso correspondiente. Si no hay avisos, texto de estado vacío. La API `GET operational-reminders` existente solo expone la anotación autorizada.
- Traducciones ES/CA: `inboxHistoryIndexTitle`, `inboxHistoryIndexDescription`, `inboxHistoryIndexEmpty`.
- `clients/flutter/lib/ui/vencira_pagination_bar.dart`: componente único, control centrado de tres columnas simétricas, textos adaptativos y botones de tamaño táctil >=44 puntos; evita que una etiqueta desplace la otra.
- Migrados los paginadores de Inicio, Agenda diaria, Archivo y cerrados, Bandeja de avisos y el historial general de la ficha. Botones desactivados durante peticiones para evitar dobles cambios de página.
- `clients/flutter/test/history_entry_pagination_test.dart`: navegación por historial de aviso completado/cancelado desde anotación cerrada a 320/375 px, estado vacío, paginador centrado y clicable a 320/375/768 px, sin overflows.

## Invariantes
- UI Flutter únicamente. **NO nuevas rutas API, NO migraciones, NO cambios de base de datos, NO entrega de notificaciones**.
- Los registros cerrados se consultan por la misma autorización de miembro/adscripción. No mostrar datos si caduca autorización.
- `operational-reminders` devuelve eventos internos persistidos; distinto del historial técnico de cambios de una anotación.
- El control de paginación conserva `_page` y los callbacks originales.

## Validación y despliegue protegido
1. Ubuntu `/home/vencira/vencira-localcheck`: `git pull --ff-only origin integration/local-e2e-prep`.
2. `bash scripts/validate_macro_b_readonly.sh`. Exigir `MACRO_B_GATE_RESULTADO=0`, `FLUTTER_WEB_DOCKERFILE_PIN=OK`, pruebas Flutter y PostgreSQL17/SQLite temporales OK.
3. `bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh`.
4. Solo con gate verde: `sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV bash scripts/deploy_macro_b_premium_ui_web_guarded.sh`. Script web-only protege imagen anterior, pin `VALIDATED=88c03530485a21bd38f13b3a4780ca549323d7b2`, comprueba que ya está instalado el backend de historial (HTTP 401/403 anónimo), PG17 intacto 0018, no recrea API/DB, mantiene Caddy/OAuth/O5.
5. Android: abrir Inicio -> Archivo -> una anotación cerrada -> botón visible `Historial de avisos`; elegir aviso completo/cancelado; revisar empty state. Comprobar paginación centrada en Inicio, Agenda, Archivo y Bandeja a 320/375px, claro/oscuro.

Si `API_HISTORIAL_PRESENTE_Y_PROTEGIDA` falla, NO repetir despliegue web ni inventar rutas: comprobar si se desplegó previamente el endpoint de historial de la macrofase B. Evitar publicar Flutter que enlace con una API ausente.
