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
