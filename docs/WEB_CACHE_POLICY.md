# VENCIRA — actualización de Flutter Web en desarrollo

**Contexto (22/10/2026):** después del despliegue de la agenda con preaviso, Chrome Android mostraba la versión anterior al actualizar la pestaña habitual, pero en incógnito mostraba la nueva. Borrar los datos del sitio permitió actualizarla. Esto indica estado antiguo del navegador; no se confirmó mediante DevTools si el origen exacto era el almacenamiento HTTP o un service worker previo.

## Política propuesta

1. Flutter web se compila con `--pwa-strategy=none`: no se registra un service worker nuevo.
2. La página inicial, los recursos de JavaScript y las rutas API/login deben enviarse con `Cache-Control: no-store` desde Nginx. Esto prioriza frescura sobre ahorro de tráfico en **entorno de desarrollo**.
3. El documento `clients/flutter/web/index.html` consulta registros SW únicamente de **origen propio**, y desregistra solo los que apuntan al antiguo `/flutter_service_worker.js`. Elimina exclusivamente las claves Cache Storage históricas `flutter-app-cache`, `flutter-temp-cache`, `flutter-app-manifest`. No toca cookies, localStorage ni otros SW o cachés.
4. Si el documento todavía está controlado por ese SW, recarga **una sola vez por sesión** con un marcador `sessionStorage` para evitar bucles.
5. El script `flutter_bootstrap.js` se solicita con parámetro distinto por navegación (`?v=<timestamp>`), evitando reutilización de su copia HTTP antigua.
6. Un archivo `*.js` inexistente devuelve 404 (no el `index.html` de Flutter), para impedir pantallas blancas poco diagnosticables.
7. Las rutas `/api/` y `/accounts/` siguen con `no-store` y autenticación normal. Esta corrección no borra sesiones ni modifica Caddy ni Django.

## Pruebas y comprobación

`scripts/smoke_same_origin.py` verifica los encabezados `Cache-Control` de `/`, `/flutter_bootstrap.js` y `/main.dart.js`; tipo MIME JavaScript; 404 de JS inexistente; y presencia de rutina de limpieza en la página. GitHub Actions `integration-local.yml` construye Flutter en Docker, valida Nginx y ejecuta smoke autenticado.

No se puede verificar la eliminación real de SW obsoleto únicamente mediante HTTP: requiere un navegador con instalación heredada. En la prueba manual: actualizar `dev.vencira.es` en Chrome Android, comprobar nueva interfaz sin borrar datos y verificar que la sesión permanece iniciada si sigue vigente. Si el sitio se abrió originalmente desde una copia anterior controlada por SW, puede requerir una recarga adicional para recibir el HTML nuevo por primera vez.

## Despliegue

La modificación afecta al **frontend Flutter + Nginx**; no requiere reiniciar PostgreSQL, migrar datos ni cambiar Caddy. En `/home/vencira/vencira-localcheck`, después de CI verde, actualizar con la clave SSH existente y reconstruir solamente `web_preview` en el proyecto Compose `vencira_localcheck`. Conservar `vencira_preview` y todas las bases de datos. Verificar la cabecera desde `127.0.0.1:28732`.

## Límites

No ofrece recarga automática de una pestaña abierta durante horas. La versión nueva se obtiene en la **siguiente navegación/recarga**, sin necesidad de borrar las cookies del sitio. Las aplicaciones móviles nativas y las estrategias de caché para producción se diseñarán por separado.
