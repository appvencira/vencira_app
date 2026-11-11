# VENCIRA — D1-Z: prueba real de navegador y recuperación de contenedor web en laboratorio

Fecha: 11/11/2026. Destino exclusivo: `main`. **IMPLEMENTADO, NO EJECUTADO. No atribuir PASS.**

## Motivo

D1-W certificó la entrega de artefactos Flutter Web por Nginx y Caddy a nivel HTTP, pero no el arranque en un navegador. D1-X/Y certificaron estructura de Caddy cargada y disponibilidad de imágenes actuales, no rollback de una versión anterior. D1-Z incorpora un navegador Chromium automatizado y una recuperación de servicio web en la misma infraestructura sintética, sin tocar DEV.

## Componentes

- `scripts/main_d1z_browser_web_recovery_isolated.sh`: evolución de D1-W. Construye Flutter Web desde el repositorio, Gunicorn/Django candidato y PostgreSQL 17 en una red `--internal`, Nginx y Caddy 2.11.7 con certificado sintético `d1z-proxy`. Realiza `pg_dump` y `pg_restore` de un esquema sintético y valida los controles HTTP existentes. Sin puertos host publicados, sin acceso a volumen de DEV, sin migraciones persistentes. Elimina red, contenedores, imágenes temporales y artefactos al salir, verificando identidad de los tres contenedores DEV.
- `scripts/main_d1z_flutter_caddy_probe.py`: GET de HTML/JS y rutas API, CSRF, cookies Secure, CA desconocida rechazada, derivados del D1-W PASS.
- `scripts/Dockerfile.d1z-playwright`: ejecuta `npm install playwright@1.56.1` sobre la imagen oficial `mcr.microsoft.com/playwright:v1.56.1-noble`. La imagen se construye en la red de build Docker, después se ejecuta en la red del laboratorio `--internal`. No recibe contraseña de BD ni variables de Django.
- `scripts/main_d1z_chromium_smoke.js`: abre `https://d1z-proxy/` en Chromium de verdad, acepta únicamente el certificado sintético del laboratorio (`ignoreHTTPSErrors`, **no** aplicable a DEV), espera a que se inserte `flutter-view`, comprueba `fetch("/api/health/")` del navegador sobre HTTPS y falla ante errores JavaScript observados. No automatiza credenciales de usuarios ni demuestra un flujo completo de login, calendario, ficha o notificaciones.
- Tras el primer PASS del navegador, elimina y recrea **solo Nginx del laboratorio** con los **mismos artefactos web**, espera respuesta HTTP 200 y vuelve a ejecutar Chromium. Esto prueba que el servicio es recuperable desde esos artefactos, pero **no** que una imagen antigua pueda restaurarse tras una migración de BD o revertirse la configuración Caddy operativa.

El primer navegador puede detectar errores reales de la app o de recursos externos bloqueados por el aislamiento. Mantener FAIL y diagnóstico por fase hasta identificar causa, sin silenciar pruebas críticas.

## Gate agrupado Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d1z_browser_web_recovery_isolated.sh
bash scripts/main_d1z_browser_web_recovery_isolated.sh
echo "D1Z_SHELL_RESULT=$?"
```

Criterios: `D1Z_FLUTTER_RELEASE_BUILD=PASS`, `D1Z_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1Z_CHROMIUM_FLUTTER_VIEW=PASS`, `D1Z_CHROMIUM_SAME_ORIGIN_API=PASS`, `D1Z_CHROMIUM_JS_ERRORS=NONE`, `D1Z_CHROMIUM_SMOKE=PASS`, `D1Z_CHROMIUM_RENDER_GATE=PASS`, `D1Z_WEB_RECOVERY_RESTART=PASS`, `D1Z_CHROMIUM_AFTER_WEB_RESTART=PASS`, `D1Z_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`, `D1Z_DEV_CONTAINERS_UNCHANGED=OK`, `D1Z_EPHEMERAL_CLEANUP=DONE` y `D1Z_RESULT=0`. El script depende de poder obtener imágenes Flutter, Nginx, Caddy y Playwright cuando no están ya disponibles.

## Excepciones y riesgos pendientes

**Incluso con PASS**, la prueba es un *smoke test visual real* en Chromium, pero no inspección manual de las pantallas ni pruebas de login/calendario/ficha, ni ejecución con un certificado CA validado operacional. El segundo arranque de Nginx recupera la misma versión de Flutter, no revierte a una imagen web anterior.

El rollback de DEV sigue pendiente: conservar y validar imágenes/versiones anteriores, manifiestos Caddy y Compose previos, prueba de recuperación íntegra sobre una copia real O5 después de cualquier actualización candidata, política RPO/RTO y control de escrituras. Los gates D1-N y D1-X proporcionan evidencias parciales de restauración, **no** justifican un rollback sobre volumen DEV. Para aumentar cobertura de navegador podrían añadirse recorridos e2e autenticados con usuarios sintéticos en laboratorio, sin pedir credenciales DEV.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_LIVE_RESTORE_EXECUTED=NO
```


## Primer resultado del operador y mejora diagnóstica (11/11/2026)

La primera ejecución obtuvo `D1Z_PG17_TMPFS=PASS`, `D1Z_SYNTHETIC_MIGRATIONS=PASS`, `D1Z_FLUTTER_RELEASE_BUILD=PASS`, `D1Z_CADDY_LAB_CONFIG_VALID=PASS`, `D1Z_NO_HOST_PORTS=PASS`, `D1Z_CADDY_TLS_HTTP_CONTRACT=PASS`, `D1Z_CSRF_SECURE_COOKIE=PASS`, `D1Z_CSRF_POST_DENIED=PASS`, `D1Z_UNTRUSTED_CA_DENIED=PASS`, `D1Z_CADDY_HTTPS_PROBE=PASS` y `D1Z_CHROMIUM_IMAGE_BUILD=PASS`. El navegador comunicó `D1Z_CHROMIUM_FAILURE_STAGE=RENDER_OR_BROWSER` y `D1Z_CHROMIUM_RENDER_GATE=FAIL`. El gate devolvió `D1Z_RESULT=8`, con `D1Z_DEV_CONTAINERS_UNCHANGED=OK` y `D1Z_EPHEMERAL_CLEANUP=DONE`. **D1-Z global NO supera el gate**.

El fallo puede corresponder a renderización, arranque Chromium, recursos externos inaccesibles u otro error: el mensaje original **no discrimina** y no hay prueba suficiente para atribuirlo a Flutter o a los certificados. Se cambió `scripts/main_d1z_chromium_smoke.js` en commit `74a32b76` para registrar etapas discretas (`LAUNCH`, `DOCUMENT`, `FLUTTER_VIEW_TIMEOUT`, `SAME_ORIGIN_API`, `JS_ERRORS`) y contadores de errores JS, peticiones fallidas internas y externas, sin imprimir direcciones, cookies, mensajes de consola, tokens ni cuerpos HTTP. El shell ahora ejecuta `node --check` en un contenedor sin red antes del smoke, commit `5df3987b`.

Se requiere **una nueva ejecución D1-Z** sobre `main`. Solo publicar PASS si se obtienen `D1Z_CHROMIUM_SMOKE=PASS`, `D1Z_CHROMIUM_AFTER_WEB_RESTART=PASS`, `D1Z_EPHEMERAL_CLEANUP=DONE` y `D1Z_RESULT=0`. Si persiste el fallo, usar los nuevos marcadores como diagnóstico, no desactivar los controles ni reducir el alcance de la prueba para hacerla pasar. Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Segundo intento — fallo confirmado de arranque de Flutter, corrección de dependencia CDN (11/11/2026)

El operador confirmó PG17/build Flutter/Nginx/Caddy/TLS y su contrato HTTP en PASS. El navegador llegó a `D1Z_CHROMIUM_LAUNCH=PASS` y `D1Z_CHROMIUM_DOCUMENT=PASS`, pero el bootstrap no generó un `flutter-view`:

```text
D1Z_CHROMIUM_BOOTSTRAP_TAG=YES
D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=NO
D1Z_CHROMIUM_CANVAS_PRESENT=NO
D1Z_CHROMIUM_SCRIPT_TAGS_PRESENT=YES
D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT
D1Z_CHROMIUM_JS_ERRORS_COUNT=6
D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=0
D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=3
D1Z_CHROMIUM_RENDER_GATE=FAIL
D1Z_DEV_CONTAINERS_UNCHANGED=OK
D1Z_EPHEMERAL_CLEANUP=DONE
D1Z_RESULT=8
```

Los tres fallos de recursos externos en una red `--internal` son compatibles con una dependencia del motor CanvasKit obtenida del CDN por defecto de Flutter; **no conocemos sus URLs y no afirmamos causalidad definitiva**. En la revisión del código `clients/flutter/web/index.html` se comprobó que la aplicación inserta el `flutter_bootstrap.js` generado. La documentación oficial Flutter Web permite personalizar el bootstrap e indicar `canvasKitBaseUrl`, y el build ya exporta `canvaskit/`.

**Corrección candidata de código real publicada en `main`:**
- `clients/flutter/web/flutter_bootstrap.js` (commit `289f3014`): bootstrap estándar con tokens `{{flutter_js}}` y `{{flutter_build_config}}`, configurando `_flutter.loader.load({config:{canvasKitBaseUrl:"/canvaskit/"}})`. El motor se servirá desde el mismo origen en vez de solicitarlo a un CDN externo.
- `scripts/main_d1z_browser_web_recovery_isolated.sh` (commit `028e668b`): exige `canvaskit/canvaskit.js`, `canvaskit/canvaskit.wasm` y comprobación de la configuración generada antes de publicar `D1Z_LOCAL_CANVASKIT_BUNDLED=PASS` y `D1Z_BOOTSTRAP_LOCAL_CANVASKIT_CONFIG=PASS`.

Este cambio afecta a Flutter Web en futuras compilaciones, pero **no hay deploy** ni modificación de los recursos web servidos ahora por DEV. Cualquier validación D1-W previa corresponde al artefacto anterior; D1-Z probará el nuevo build. Si Chromium vuelve a fallar, conservar FAIL y diagnosticar sin atribuir PASS. El aviso Flutter de `Wasm dry run succeeded` es informativo y no es la causa demostrada de este fallo.

En todo momento `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D1Z_RELEASE_AUTHORIZED=NO`. Sigue sin certificarse el rollback operativo ni la navegación completa de la aplicación.


## Tercer intento — mejora parcial sin arranque completo (11/11/2026)

El operador volvió a ejecutar el build con CanvasKit local y confirmó `D1Z_LOCAL_CANVASKIT_BUNDLED=PASS` y `D1Z_BOOTSTRAP_LOCAL_CANVASKIT_CONFIG=PASS`. Chromium inició y abrió el HTML; `D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=NO`, `D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT`. Los errores JS pasaron de 6 a 2 y las peticiones externas fallidas de 3 a 1, pero **no existe evidencia suficiente de que CanvasKit sea la única causa ni de qué recurso sigue fallando**. No hay peticiones internas fallidas. La cadena HTTPS/Flutter build continúa PASS; `D1Z_EPHEMERAL_CLEANUP=DONE`, `D1Z_DEV_CONTAINERS_UNCHANGED=OK`, `D1Z_RESULT=8`.

Para obtener información discriminatoria sin exponer URLs, cuerpos de respuesta, trazas completas ni secretos, el test Chromium registra en caso de fallo los contadores `D1Z_CHROMIUM_FAILED_REQUEST_TYPE_*` (tipo de recurso), `D1Z_CHROMIUM_FAILED_HOST_CLASS_*` (clases acotadas de servicios externos conocidos) y `D1Z_CHROMIUM_ERROR_CLASS_*` (categorías de mensajes de errores JS). Implementado en `scripts/main_d1z_chromium_smoke.js`, commit `d98be0fd`. Los nombres de clases están definidos estáticamente y otros hosts se agrupan bajo `OTHER_EXTERNAL`. **Es diagnóstica, no corrección ni PASS.**

Repetir D1-Z únicamente cuando el operador quiera seguir con la comprobación; no modificar Caddy operativo ni permitir tráfico externo general a la red aislada para ocultar el error. Si la petición es una fuente remota se valorará sustituirla por un recurso local con procedencia clara. Si sigue fallando el render sin relación con recursos externos, revisar compatibilidad de Flutter/Chromium y errores de inicialización.


## Cuarto intento — recurso externo identificado, causa de render aún sin demostrar (11/11/2026)

La ejecución confirmó `D1Z_LOCAL_CANVASKIT_BUNDLED=PASS`, `D1Z_BOOTSTRAP_LOCAL_CANVASKIT_CONFIG=PASS`, `D1Z_CHROMIUM_LAUNCH=PASS`, `D1Z_CHROMIUM_DOCUMENT=PASS`; `D1Z_CHROMIUM_FLUTTER_VIEW_PRESENT=NO` y `D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT`. Persisten `D1Z_CHROMIUM_JS_ERRORS_COUNT=2`, `D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=1`, `D1Z_CHROMIUM_FAILED_REQUEST_TYPE_FETCH=1`, `D1Z_CHROMIUM_FAILED_HOST_CLASS_GOOGLE_FONTS=1`, `D1Z_CHROMIUM_ERROR_CLASS_OTHER=2`. No se registraron fallos de solicitudes internas; DEV intacto, limpieza DONE y **`D1Z_RESULT=8`**.

El recurso externo no disponible procede de `fonts.googleapis.com` (no se capturaron URL completas). Los dos errores JS siguen clasificados como OTHER, por lo que **Google Fonts no es una causa demostrada del bloqueo del motor Flutter**. La aplicación no contiene una dependencia declarada de Google Fonts en `clients/flutter/pubspec.yaml`.

Cambios de diagnóstico publicados en `main`:
- Commit `000fe419`: tipos de excepciones JS (`D1Z_CHROMIUM_EXCEPTION_TYPE_*`), clasificación adicional de errores y estado HTTP categorizado del bootstrap/main.dart.js, sin imprimir mensajes, rutas completas ni cookies.
- Commit `5f61089d`: prueba de control adicional **solo después del FAIL del navegador ordinario**; intercepta exclusivamente solicitudes a `fonts.googleapis.com` y responde una hoja CSS vacía en una nueva página del navegador del laboratorio. Publica `D1Z_CHROMIUM_FONT_DEPENDENCY_DIAGNOSTIC=VIEW_PRESENT_WITH_FONT_STUB` o `VIEW_ABSENT_OR_DIAGNOSTIC_FAILED`. **No constituye PASS del navegador sin alteraciones y nunca modifica la aplicación ni el proxy.** El diagnóstico puede discriminar causalidad; un resultado negativo no identifica por sí solo los dos errores JS restantes.

El gate continuará FAIL hasta que la app real genere `flutter-view` y pase los demás controles sin respuestas sustituidas. No relajar aislamiento de Docker, no cambiar configuración Caddy operativa, no realizar deploy. Siguen `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Quinto intento — Google Fonts no explica por sí solo la falta de Flutter view (11/11/2026)

El operador comunicó:
```text
D1Z_CHROMIUM_FONT_DEPENDENCY_DIAGNOSTIC=VIEW_ABSENT_OR_DIAGNOSTIC_FAILED
D1Z_CHROMIUM_FAILURE_STAGE=FLUTTER_VIEW_TIMEOUT
D1Z_CHROMIUM_JS_ERRORS_COUNT=2
D1Z_CHROMIUM_FAILED_INTERNAL_REQUESTS=0
D1Z_CHROMIUM_FAILED_EXTERNAL_REQUESTS=1
D1Z_CHROMIUM_DOCUMENT_HTTP_STATUS=200
D1Z_CHROMIUM_SCRIPT_HTTP_STATUS=200
D1Z_CHROMIUM_FAILED_REQUEST_TYPE_FETCH=1
D1Z_CHROMIUM_FAILED_HOST_CLASS_GOOGLE_FONTS=1
D1Z_CHROMIUM_ERROR_CLASS_LOAD_FAILURE=1
D1Z_CHROMIUM_ERROR_CLASS_OTHER=1
D1Z_CHROMIUM_EXCEPTION_TYPE_ERROR=1
D1Z_CHROMIUM_RENDER_GATE=FAIL
D1Z_DEV_CONTAINERS_UNCHANGED=OK
D1Z_EPHEMERAL_CLEANUP=DONE
D1Z_RESULT=8
```
El ensayo con CSS vacío es **inconcluso**, porque combina vista ausente y error del propio diagnóstico en un marcador; nunca fue una prueba de aceptación. La ausencia de un `flutter-view` con respuestas HTTP 200 de HTML/scripts apunta a una excepción durante el arranque o el render, pero **todavía no la identifica**. La solicitud Google Fonts restante puede ser secundaria al renderizado de fuentes de reserva de Flutter.

Se publicó en `main` una síntesis de la primera línea de `pageerror` con eliminación de URLs, valores largos opacos y cadenas entrecomilladas (sin stack completo, cuerpos de respuesta ni tokens), en `scripts/main_d1z_chromium_smoke.js` (commits `585464a2`, `ec709087`). Los marcadores `D1Z_CHROMIUM_SAFE_EXCEPTION_1` y, si corresponde, `_2`, permitirán distinguir excepción Flutter del error de fuente. El runner existente ya ejecuta `node --check` antes de abrir Chromium.

**D1-Z mantiene resultado FAIL** y solo la siguiente ejecución puede validar esta instrumentación. No se ha autorizado despliegue ni migraciones persistentes, y la causa exacta sigue pendiente.


## Sexto intento — fallo de sintaxis en instrumentación (11/11/2026)

La ejecución más reciente validó compilación Flutter, configuración CanvasKit local, PostgreSQL 17 efímero, Nginx, Caddy/TLS y contratos HTTP (PASS), pero **no llegó a arrancar Chromium**. El paso `node --check /opt/d1z/smoke.js` detectó `SyntaxError: Invalid regular expression flags` en la línea que pretendía ocultar URLs en `safeExceptionSummary`, por barras sobreescapadas. El gate cerró limpiamente con `D1Z_CHROMIUM_SMOKE_SYNTAX=FAIL`, `D1Z_RESULT=8`, `D1Z_DEV_CONTAINERS_UNCHANGED=OK` y `D1Z_EPHEMERAL_CLEANUP=DONE`.

Se corrigieron las expresiones regulares de la función en `scripts/main_d1z_chromium_smoke.js`, commit `d4d08478`. Se comprobó con Node 22 instalado en entorno local la sintaxis de las expresiones de redacción de URLs, rutas, cadenas y datos largos. **El archivo completo aún debe superar `node --check` en Termius y el navegador debe volver a ejecutarse; no afirmar que D1-Z haya pasado.** El diagnóstico del arranque Flutter permanece pendiente desde el quinto intento; el sexto solo informa de una incidencia de instrumentación.

La advertencia sobre `--wasm` sigue siendo informativa. No se autorizó despliegue, restore o migración de DEV. `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Séptimo intento — excepción de configuración regional identificada (11/11/2026)

El operador confirmó `D1Z_CHROMIUM_SMOKE_SYNTAX=PASS`, `D1Z_CHROMIUM_LAUNCH=PASS`, `D1Z_CHROMIUM_DOCUMENT=PASS`, `D1Z_CHROMIUM_DOCUMENT_HTTP_STATUS=200`, `D1Z_CHROMIUM_SCRIPT_HTTP_STATUS=200`; sigue sin `flutter-view`. Nueva evidencia determinante: `D1Z_CHROMIUM_SAFE_EXCEPTION_1=Invalid argument(s): Incorrect locale information provided`. Hay además una solicitud de Google Fonts fallida, `LOAD_FAILURE=1`, `OTHER=1`; el control CSS vacío fue inconcluso. El gate termina con `D1Z_CHROMIUM_RENDER_GATE=FAIL`, `D1Z_RESULT=8`, DEV intacto, cleanup DONE.

Esta excepción es compatible con una configuración regional inválida en alguna llamada a las APIs internacionales del navegador; no demuestra aún si el valor inválido nace en Chromium, Dart/Flutter o una dependencia. Al revisar el código, `clients/flutter/lib/main.dart` configura idioma `es` por defecto, `ca` como alternativo, y `dashboard_screen.dart` pasa el `languageCode` de Flutter a `DateFormat`. No se detectó ahí un código regional no estándar que justifique alterar producto.

**Corrección de entorno de prueba candidata** publicada en `scripts/main_d1z_chromium_smoke.js` commit `128d72bb`: Chromium se lanza con `--lang=es-ES` y cada contexto Playwright usa `locale: "es-ES"`; antes del `goto` verifica `navigator.language` y `Intl.DateTimeFormat(language).resolvedOptions().locale`. Nuevos marcadores `D1Z_CHROMIUM_SPANISH_LOCALE=PASS` y `D1Z_CHROMIUM_INTL_DATE_LOCALE=PASS`. Es una configuración reproducible del navegador del laboratorio, no un cambio en el idioma de VENCIRA, en Caddy o en DEV.

**D1-Z continúa FAIL hasta recibir una nueva ejecución.** Si ambos marcadores regionales pasan y persiste la excepción, hay que buscar el valor concreto en Flutter/paquetes y no atribuirlo simplemente al sistema del contenedor. La solicitud Google Fonts puede ser secundaria. No ejecutar deploy ni migraciones persistentes; `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
