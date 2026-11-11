# D2-A — Chromium visual pixel smoke (desktop/mobile), laboratorio aislado

Fecha: 2026-11-11. **Estado: PREPARADO, SIN EJECUCIÓN DEL OPERADOR.** Continuación de D1-Z PASS. Los cambios se incorporan directamente a `main`, sin crear ramas nuevas.

## Objetivo y alcance

Validar que el build Flutter Web real crea una interfaz rasterizada no vacía en Chromium headless en **1280×800** y **390×844**, siempre con `locale=es-ES`; que conserva API same-origin vía Caddy HTTPS, y que sigue cargando después de reconstruir **solo el Nginx efímero**. En ambos pasos el test exige `flutter-view` y comprueba geometría del componente (al menos el 50 % del ancho y alto del viewport), dimensiones exactas de PNG y más de tres colores distintos muestreados a intervalos de 21 píxeles. Los PNG se decodifican y analizan **solo en memoria del contenedor**: no se guardan capturas, tokens ni datos en disco o en GitHub.

**Precisión:** estos controles prueban que el navegador pinta píxeles y que el lienzo no parece totalmente plano. **No prueban** calidad tipográfica, contraste WCAG, textos correctos, accesibilidad, ausencia de recortes finos, autenticación o navegación de usuario. La red aislada impide cargar Google Fonts externos y conserva `FONT_NETWORK_DEGRADED=YES` y `FONT_FIDELITY_VERIFIED=NO`. Esto no debe considerarse fidelidad visual aprobada.

Se reutilizan comprobaciones de D1-Z como controles de seguridad: PG17 tmpfs, Django candidate, migraciones sintéticas, CSRF y HTTPS Caddy con certificado generado para el laboratorio, rechazo de CA desconocida, endpoint público de salud 200, rutas privadas `/api/v1/me/` y `/api/v1/workspaces/` 403 cuando la sesión es anónima, 0 `pageerror`, 0 errores de consola adicionales a esas denegaciones esperadas y al bloqueo Google Fonts, 0 fallos de solicitudes internas, y esquema PG17 ficticio respaldado/restaurado. Los controles se repiten tras rasterizar para detectar errores tardíos.

## Archivos de código nuevos

- `scripts/main_d2a_browser_visual_isolated.sh`: laboratorio con red Docker `--internal`, sin publicar puertos y sin usar credenciales, volúmenes ni Caddy de DEV; limpieza en `trap EXIT`. Ajustado desde D1-Z para mantener las mismas barreras de no despliegue.
- `scripts/main_d2a_flutter_caddy_probe.py`: contrato TLS/HTTP del proxy efímero.
- `scripts/Dockerfile.d2a-playwright`: Playwright Chromium 1.56.1 con `pngjs@7.0.0` para decodificar screenshots.
- `scripts/main_d2a_chromium_visual_smoke.js`: compara dimensiones, geometría de `flutter-view`, variación de colores de PNG de ambas resoluciones, y comprueba API/JS tras capturas. No publica screenshot ni lo sube al repositorio.

## Comando para el operador

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d2a_browser_visual_isolated.sh
bash scripts/main_d2a_browser_visual_isolated.sh
echo "D2A_SHELL_RESULT=$?"
```

**Marcadores esperados**, aún NO observados:

```text
D2A_DESKTOP_VIEW_GEOMETRY=PASS
D2A_DESKTOP_PNG_PIXELS=PASS
D2A_DESKTOP_COLOR_VARIATION=PASS
D2A_MOBILE_VIEW_GEOMETRY=PASS
D2A_MOBILE_PNG_PIXELS=PASS
D2A_MOBILE_COLOR_VARIATION=PASS
D2A_SCREENSHOTS_RETAINED=NO
D2A_VISUAL_FIDELITY_VERIFIED=NO
D2A_VISUAL_POST_CAPTURE_APP_ERRORS=NONE
D2A_VISUAL_POST_CAPTURE_API=PASS
D2A_CHROMIUM_RENDER_GATE=PASS
D2A_WEB_RECOVERY_RESTART=PASS
D2A_CHROMIUM_AFTER_WEB_RESTART=PASS
D2A_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS
D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_AND_RECOVERY_GATE=PASS
D2A_DEV_CONTAINERS_UNCHANGED=OK
D2A_EPHEMERAL_CLEANUP=DONE
D2A_RESULT=0
```

Un gate FAIL debe investigarse usando su marcador. El test de píxeles puede fallar legítimamente para la pantalla anónima o una dimensión particular; **no reducir umbrales sin revisar**. La primera ejecución de D2-A todavía no está certificada. D1-Z sigue cerrado y no se reabre.

## Límites y autorizaciones

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D2A_RELEASE_AUTHORIZED=NO
D2A_DEPLOY_EXECUTED=NO
D2A_LIVE_MIGRATIONS_EXECUTED=NO
D2A_LIVE_RESTORE_EXECUTED=NO
```

El gate no verifica fuentes reales con conexión, acciones de usuarios autenticados, Caddy de producción, restauración real de la DB persistente ni rollback operativo de imágenes. **Prohibido interpretarlo como release.**


## Primera ejecución del operador — escritorio PASS, fallo móvil sin causa diferenciada (11/11/2026)

El usuario confirmó los preflights de PG17 tmpfs, Django, Flutter release, CanvasKit local, Nginx, Caddy TLS/CSRF y Chromium (`es-ES`) con `D2A_CHROMIUM_FLUTTER_VIEW=PASS`, `D2A_CHROMIUM_SAME_ORIGIN_API=PASS`, `D2A_CHROMIUM_PAGE_ERRORS=0`, `D2A_CHROMIUM_OTHER_CONSOLE_ERRORS=0`, `D2A_CHROMIUM_EXPECTED_ANONYMOUS_403=PASS`, `D2A_CHROMIUM_APP_JS_ERRORS=NONE`. **Escritorio completo PASS**: `D2A_DESKTOP_VIEW_GEOMETRY=PASS`, `D2A_DESKTOP_PNG_PIXELS=PASS`, `D2A_DESKTOP_COLOR_VARIATION=PASS`.

La fase móvil falló con el único marcador `D2A_CHROMIUM_FAILURE_STAGE=VISUAL_MOBILE` y `D2A_CHROMIUM_RENDER_GATE=FAIL`; **`D2A_RESULT=8`**. Se observaron 65 peticiones externas Google Fonts (por el cambio de viewport), ninguna petición interna fallida ni `pageerror`. DEV intacto y cleanup DONE. Esta evidencia no identifica si la fase móvil falló por geometría de `flutter-view`, dimensiones del PNG, cantidad de colores o error de captura. No se han modificado los estilos Flutter ni los umbrales para forzar un PASS.

En `scripts/main_d2a_chromium_visual_smoke.js` commit `9f98856b`, se añadieron marcadores de etapa precisos para `VISUAL_VIEW_GEOMETRY_MOBILE`, `VISUAL_PNG_DIMENSIONS_MOBILE`, `VISUAL_BLANK_OR_FLAT_MOBILE` y equivalentes de escritorio. Además imprime solo `D2A_MOBILE_VIEW_WIDTH_PX`, `D2A_MOBILE_VIEW_HEIGHT_PX`, `D2A_MOBILE_PNG_WIDTH_PX`, `D2A_MOBILE_PNG_HEIGHT_PX` y `D2A_MOBILE_SAMPLED_COLOR_COUNT` según se alcancen las comprobaciones. No se imprimen ni guardan imágenes ni datos privados. Se verificó sintaxis JavaScript mediante parser V8 tras la corrección. **Pendiente otra ejecución D2-A en el laboratorio aislado**, sin desplegar ni migrar DEV.


## Segundo ensayo D2-A — la cuadrícula móvil de 21px detecta solo 3 colores

El operador confirma que Caddy/TLS, Django, Flutter release, CanvasKit local y Chromium son PASS. En escritorio: `VIEW_WIDTH_PX=1280`, `VIEW_HEIGHT_PX=800`, PNG 1280×800, `SAMPLED_COLOR_COUNT=5`, todas las comprobaciones PASS. En móvil: `VIEW_WIDTH_PX=390`, `VIEW_HEIGHT_PX=844`, PNG 390×844, tanto geometría como dimensiones PASS, pero `D2A_MOBILE_SAMPLED_COLOR_COUNT=3`, `D2A_CHROMIUM_FAILURE_STAGE=VISUAL_BLANK_OR_FLAT_MOBILE`, `D2A_RESULT=8`. No hay `pageerror`, errores de aplicación o fallos de transporte internos. Peticiones de Google Fonts externas bloqueadas: 65, red `--internal`. DEV intacto, cleanup DONE.

La captura es de dimensiones correctas pero el muestreo original recorría una rejilla cada **21 píxeles**, lo que puede omitir trazos estrechos, iconos y texto de interfaz móvil; tres colores no demuestra ausencia de estos elementos. No es prueba suficiente para atribuir defecto a Flutter ni para bajar arbitrariamente el límite de cuatro colores.

**Commit `29f366da`**: conservando el umbral `>=4`, se instrumentó un segundo muestreo cada **5 píxeles**, capturando `D2A_*_COARSE_COLOR_COUNT` (21px) y `D2A_*_DENSE_COLOR_COUNT` (5px), y se usa la muestra densa para `SAMPLED_COLOR_COUNT` y el gate. Se comprobó sintaxis con parser V8. No cambia la UI ni los recursos, no guarda screenshots ni expone datos. Si el muestreo denso sigue identificando menos de cuatro colores, D2-A continuará FAIL y será necesario inspeccionar realmente el contenido de la pantalla móvil, no aprobarlo por aproximación. Se requiere reejecución en laboratorio; **D2-A no está aprobado**.


## Cierre del operador — D2-A PASS (11/11/2026)

Resultado observado y validado por el operador: **`D2A_RESULT=0`**, `D2A_CHROMIUM_DESKTOP_MOBILE_VISUAL_AND_RECOVERY_GATE=PASS`.

- Entorno: `D2A_PROBE_SYNTAX=PASS`, `D2A_DEV_IDENTITY=PASS`, `D2A_INTERNAL_NETWORK=PASS`, `D2A_PG17_TMPFS=PASS`, `D2A_CANDIDATE_IMAGE=PASS`, `D2A_SYNTHETIC_MIGRATIONS=PASS`, `D2A_GUNICORN_STARTED=YES`, `D2A_FLUTTER_RELEASE_BUILD=PASS`, `D2A_LOCAL_CANVASKIT_BUNDLED=PASS`.
- HTTPS: `D2A_CADDY_LAB_CONFIG_VALID=PASS`, `D2A_NO_HOST_PORTS=PASS`, `D2A_CADDY_TLS_HTTP_CONTRACT=PASS`, `D2A_CSRF_SECURE_COOKIE=PASS`, `D2A_CSRF_POST_DENIED=PASS`, `D2A_UNTRUSTED_CA_DENIED=PASS`.
- Chromium inicial: `D2A_CHROMIUM_FLUTTER_VIEW=PASS`, `D2A_CHROMIUM_SAME_ORIGIN_API=PASS`, `D2A_CHROMIUM_PAGE_ERRORS=0`, `D2A_CHROMIUM_OTHER_CONSOLE_ERRORS=0`, `D2A_CHROMIUM_EXPECTED_ANONYMOUS_403=PASS`, `D2A_CHROMIUM_APP_JS_ERRORS=NONE`.
- Escritorio: `D2A_DESKTOP_VIEW_WIDTH_PX=1280`, `D2A_DESKTOP_VIEW_HEIGHT_PX=800`, `D2A_DESKTOP_PNG_PIXELS=PASS`, `D2A_DESKTOP_COARSE_COLOR_COUNT=3`, `D2A_DESKTOP_DENSE_COLOR_COUNT=15`, `D2A_DESKTOP_COLOR_VARIATION=PASS`.
- Móvil: `D2A_MOBILE_VIEW_WIDTH_PX=390`, `D2A_MOBILE_VIEW_HEIGHT_PX=844`, `D2A_MOBILE_PNG_PIXELS=PASS`, `D2A_MOBILE_COARSE_COLOR_COUNT=4`, `D2A_MOBILE_DENSE_COLOR_COUNT=14`, `D2A_MOBILE_COLOR_VARIATION=PASS`.
- Después de cada captura: `D2A_VISUAL_POST_CAPTURE_APP_ERRORS=NONE`, `D2A_VISUAL_POST_CAPTURE_API=PASS`; `D2A_SCREENSHOTS_RETAINED=NO`.
- Segundo Chromium tras recrear Nginx efímero: mismos tamaños, geometría y conteos de colores, `D2A_WEB_RECOVERY_RESTART=PASS`, `D2A_CHROMIUM_AFTER_WEB_RESTART=PASS`.
- PostgreSQL sintético: `D2A_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`. Aislamiento final: `D2A_DEV_CONTAINERS_UNCHANGED=OK`, `D2A_EPHEMERAL_CLEANUP=DONE`.
- Fuentes: `D2A_CHROMIUM_FONT_NETWORK_DEGRADED=YES`, `D2A_CHROMIUM_FONT_FIDELITY_VERIFIED=NO`, `D2A_VISUAL_FIDELITY_VERIFIED=NO`, `D2A_CHROMIUM_SMOKE=PASS_WITH_FONT_DEGRADATION`.

**Conclusión precisa:** D2-A PASS para existencia de renderizado no plano en escritorio y móvil, misma API HTTPS y recuperación de laboratorio. No certifica diseño, legibilidad, fuentes correctas, accesibilidad, autenticación interactiva ni funcionalidad detallada de pantallas internas. No se han probado Caddy de producción ni rollback real de imagen/DB: `D2A_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D2A_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D2A_ROLLBACK_EXECUTED=NO`, `D2A_ROLLBACK_VERIFIED=NO`.

**Restricciones verificadas:** `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2A_RELEASE_AUTHORIZED=NO`, `D2A_DEPLOY_EXECUTED=NO`, `D2A_LIVE_MIGRATIONS_EXECUTED=NO`, `D2A_LIVE_RESTORE_EXECUTED=NO`. La advertencia del dry-run Wasm es informativa.

**D2-A cerrado**, no necesita repetirse sin cambios materiales. Para el bloque siguiente, plantear una comprobación independiente de pantallas y acciones de usuario, con datos exclusivamente sintéticos y sin liberar MFA.
