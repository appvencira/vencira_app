# Flutter — primera pantalla de agenda diaria

Estado: **PR apilada de desarrollo** (`feat/flutter-agenda-day` sobre `feat/flutter-preferences-i18n`). No fusionada, no desplegada. Fecha 22/10/2026.

## Propósito y fundamento

Whitepaper §5: agenda tipo papel que arranca en Hoy y muestra qué hay que hacer ese día, fecha completa, franja semanal con el día activo, paso a días adyacentes (gestos en móvil, flechas en escritorio), botón Hoy y consulta mensual. No es un CRM.

Primera iteración: **agenda diaria de solo lectura** sobre la proyección de eventos prevista en PR #7. Conservamos temporalmente el panel de vencimientos existente y añadimos «Abrir agenda», porque todavía no se han integrado los cambios del servidor. El cambio de pantalla principal se hará solo cuando estén integrados contrato, permisos y tareas funcionales.

## Dependencias de ramas y orden

1. **PR #4** (`feat/flutter-preferences-i18n`): `VenciraTheme`, locales ES/CA, ARB y selector Sistema/Claro/Oscuro. La PR actual nace de ella.
2. **PR #6** (`feat/team-assignment-isolation`): acceso autorizado por empleado, migración `assigned_to`, seguridad de datos y contrato de roles.
3. **PR #7** (`feat/agenda-day-readonly` sobre #6): API `GET /api/v1/workspaces/{id}/agenda/?day=YYYY-MM-DD&page=1`.
4. La PR de Flutter actual conecta el cliente con #7, pero **no puede desplegarse contra el backend anterior**: la ruta todavía no existe allí.

## Cambios de código

- `clients/flutter/lib/api/vencira_api.dart`: `fetchAgendaDay(workspaceId, day, page)`, `VenciraAgendaDayPage`, `VenciraAgendaEntry` y `VenciraAgendaEvent`. Identifica `expiry` y `reminder`, y para este último distingue `expiry` frente a `notice_deadline`.
- Las peticiones utilizan una ruta fija **del mismo origen** y valida UUID y página; el día se serializa como fecha civil ISO local `YYYY-MM-DD`, no como timestamp UTC; nunca sigue `next` proporcionado por un origen externo. El cliente rechaza fechas discordantes y tipos de evento inesperados.
- `clients/flutter/lib/ui/day_agenda_screen.dart`: pantalla diaria con semana que comienza en lunes, fecha completa, navegación con flechas, acceso a fecha con selector, botón Hoy, gestos horizontales y atajos de teclado izquierda/derecha. Lista de anotaciones paginada por día, con motivos representados por etiquetas de evento y estado vacío/cargando/error/sesión caducada.
- `clients/flutter/lib/ui/dashboard_screen.dart`: botón transitorio «Abrir agenda»; el listado anterior permanece para preservar compatibilidad y rutas hasta la integración controlada.
- `clients/flutter/lib/l10n/app_es.arb`, `app_ca.arb`: nuevos textos ES/CA. Los nombres de estado API son neutrales al idioma y jamás se traducen en almacenamiento.
- No se han añadido assets de Flaticon sin licencia confirmada; se utilizan iconos Material provisionales.

## Semántica de datos y privacidad

- `total` cuenta **anotaciones**, no número de eventos ni alertas entregadas.
- `reminder` es **aviso previsto**, no notificación enviada o confirmada. La pantalla informa expresamente de ello.
- El workspace del nuevo widget queda fijado al abrirlo. Cada cambio de día anula lógicamente la respuesta anterior mediante contador de generación y borra las referencias visibles durante la carga.
- El aislamiento entre empleados **corresponde a la API** de PR #6; la UI no sustituye permisos del servidor.
- No incluye datos personales, documentos ni intentos de acceso en red fuera del mismo origen.

## Pruebas

- `test/vencira_api_test.dart`: fechas ISO, `page`, comprobación de origen, rechazo de UUID/parámetros incorrectos, fechas de servidor divergentes y eventos imprevistos.
- `test/day_agenda_test.dart`: proyección prevista, paso de marzo a abril y vuelta, cambio por semana, descarte de respuestas obsoletas, apertura desde panel y tamaños 320/375/768 con catalán y tema oscuro.
- `test/widget_test.dart`: FakeVenciraApi adaptado al nuevo método sin modificar los tests de regresión previos.
- CI apilada: `.github/workflows/flutter-i18n.yml` comprueba catálogos, `flutter analyze`, `flutter test`, compilación web. **No marcar validado hasta consultar el resultado del workflow para el commit de esta PR**.

## Alcance pendiente (sin simularlo)

- **Vista mensual con marcas de actividad:** requiere endpoint de agregación por rango/mes desde el servidor, aplicando permisos antes de contar. El selector de fecha no equivale al calendario mensual final.
- **Recuérdamelo**, pregunta de control, comunicación a aseguradora, cierres, archivos privados y notificaciones locales/remotas requieren modelos y reglas adicionales del whitepaper.
- Los colores Cliente/Candidato y datos completos (nombre, nick, aseguradora, modalidad) estarán disponibles cuando se migre el modelo de anotación; hasta entonces se presenta la referencia sintética.
- No incluye offline; funcionamiento nativo móvil pendiente.
- Inspección visual real en navegador y dispositivos, alto contraste y fuente 200 % pendientes.

## Integración y operación

1. CI verde de PR #4, PR #6, PR #7 y de esta PR; revisión de permisos y esquema.
2. Integrar primero #6 y #7 en desarrollo de backend, y #4 y esta PR en cliente mediante orden controlado sin perder cambios.
3. En entorno de pruebas efímero: aplicar migraciones con respaldo, test de autenticación y permisos, después compilar y servir Flutter.
4. Smoke HTTPS, sesión, cambios de workspace/día, ES/CA, temas y responsive con datos inventados.
5. Documentar commit, resultados y rollback; solo después actualizar `dev.vencira.es` bajo procedimiento de despliegue confirmado.

## Validación ejecutada (22/10/2026)

- GitHub Actions: [Flutter ES-CA validation #16](https://github.com/appvencira/vencira_app/actions/runs/39722570293), commit de código y documentación `e797a1b3`: **SUCCESS**.
- Verificador de catálogos ES/CA: correcto.
- `flutter gen-l10n` y dependencias: correctos.
- `flutter analyze`: correcto.
- `flutter test`: correcto. Incluye tests de contrato HTTP y navegación de la nueva agenda, con 320/375/768 y catalán/oscuro.
- `flutter build web --release --pwa-strategy=none`: correcto.

**No equivale a validación de integración backend+frontend**: las ramas siguen apiladas e independientes. No existe evidencia de navegación visual real en navegador ni de un despliegue del nuevo contrato en `dev.vencira.es`.
