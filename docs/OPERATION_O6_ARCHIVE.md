# VENCIRA — O6: pantalla independiente Archivo (DEV)

Estado (24/10/2026): código incorporado a GitHub, **pendiente de validar Flutter y desplegar** en el entorno `vencira_localcheck`. No confundir commit con despliegue.

## Necesidad según whitepaper

El whitepaper del 18/10/2026 distingue el archivo de pólizas externas de los vencimientos activos y, en §9, los desenlaces «Conseguido» y «Descartar» que archivan una anotación. O3 ya ofrece archivo/recuperación por resultado, pero el acceso a los cierres estaba oculto bajo `Estado → Cerrado` del listado general. La pantalla O6 proporciona acceso específico desde el panel, sin crear una entidad cliente/CRM y sin borrar registros.

## Implementación

- `clients/flutter/lib/ui/renewal_archive_screen.dart`: nueva vista de un único `VenciraWorkspace`, con GET paginado a la API existente `fetchFilteredRenewals(workspace.id, page:N, status:'closed')`. Usa los controles de autorización del servidor. El servidor incluye tanto anotaciones O3 (`archive_outcome=won|discarded`) como cierres legados sin resultado; estos últimos se señalan explícitamente como «Cierre anterior · Sin desenlace registrado»; **nunca inferir un resultado**.
- Lista paginada con referencia sintética, vencimiento, resultado comercial o marca legacy, carga/error/sesión caducada y refresco. Abre `VenciraRenewalDetailScreen`, donde O3 ya permite `Recuperar`; al volver recarga la página porque el registro puede haber dejado de estar cerrado. No hay nuevas escrituras ni API, solo navegación y consultas existentes.
- `clients/flutter/lib/ui/dashboard_screen.dart`: acceso `Archivo` separado de los filtros de búsqueda, asociado exclusivamente al workspace seleccionado, sin guardar datos ni abrir el archivo de otra organización.
- `clients/flutter/lib/l10n/app_es.arb` y `app_ca.arb`: traducciones completas de esta vista.
- `clients/flutter/test/archive_test.dart`: pruebas de estado cerrado, identidad de workspace, página siguiente, leyenda de cierre legado, móvil 375 px en ES/CA, navegación desde el panel y denegación de sesión.

## Fuera de alcance / riesgos

- No introduce tabla, campos, migración, regla de retención, eliminación automática, adjuntos ni email.
- No declara protección RGPD suficiente, histórico append-only en base de datos ni producción.
- Los cerrados legados siguen sin clasificación real hasta decisión expresa.
- Solo referencias ficticias en DEV; no introducir datos personales reales.
- Para liberar O6, se exige compilación Flutter, análisis, `flutter test` **completo**, salida HTTP y salud `vencira_localcheck`, comprobación móvil manual y ausencia de regresiones. **No ejecutar migraciones, `docker compose down -v`, ni alterar Caddy o proyecto `vencira_preview`.**

## Procedimiento seguro de validación y despliegue

El script preexistente `scripts/validate_ui_v3_1.sh` realiza revisión de trabajo limpio y proyecto Docker, `flutter pub get`, `flutter analyze`, tests `premium_components`, `design_v3` y **suite Flutter completa** (que incluye `archive_test.dart`), `flutter build web --release` y **solo si todo lo anterior pasa** reconstruye/recrea `web_preview` en `vencira_localcheck`, sin API ni DB. Luego verifica salud y HTTP. Aunque conserva nombre histórico V3.1, su validación es integral sobre HEAD.

**NO EJECUTADO todavía**. El comando de una sola fase, tras sincronizar commit de O6:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/validate_ui_v3_1.sh || exit 1
  bash scripts/validate_ui_v3_1.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Confirmar `FLUTTER_V3_1_Y_TESTS=OK`, `DESPLIEGUE_WEB_V3_1_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`. Después abrir `https://dev.vencira.es/` desde Android/PC con usuario DEMO, pulsar `Archivo`, comprobar elementos `DEMO` cerrados, abrir uno `Conseguido`/ `Descartado`, recuperar y confirmar desaparición del archivo y vuelta a lista activa. Registrar capturas sin PII ni credenciales. Si falla, NO repetir despliegue y corregir en GitHub primero.

## 24/10/2026 — O6 compilada, probada y desplegada en entorno DEV

El usuario ejecutó el validador `scripts/validate_ui_v3_1.sh` desde la rama `integration/local-e2e-prep`, versión `924f8f959fb7206d98535ff6fff47c823d0904d7`. Resultado real comunicado: Git limpio salvo `clients/flutter/pubspec.lock` generado, identidad Docker correcta, `COMPOSE_CONFIG=OK`, `FLUTTER_PUB_GET_ANALYZE_TEST_BUILD=OK`, `FLUTTER_V3_1_Y_TESTS=OK`, `WEB_BUILD=OK`, `WEB_DEPLOY=OK`, `WEB_HEALTH=healthy`, endpoints de la web, salud API, readiness y login todos HTTP 200, `HEALTH_api/db/web_preview=healthy`, `DEV_VENCIRA_HTTPS_HTTP=200`, `DESPLIEGUE_WEB_V3_1_LOCALCHECK=OK`, `SIN_MIGRACIONES_NI_CAMBIOS_API_DB=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Registro en Ubuntu: `/tmp/vencira-ui-v3-1.Rerg7fJg.log`.

El primer análisis había fallado con errores de sintaxis en el test O6, líneas 61 y 78; solucionados en el mismo commit validado. **O6 desplegada y pruebas automatizadas aprobadas; aceptación manual de Archivo desde Android/PC pendiente**. Verificar acceso al Archivo de una organización, dos desenlaces y cierre legado, apertura de ficha y recuperación sin salir de workspace; solo datos DEMO. No repetir el despliegue salvo regresión. No se alteraron DB, Caddy, credenciales Google ni Restic.
