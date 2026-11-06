# I5 — Chromium real sobre Flutter y compilación Android aislada

Fecha: 2026-11-06

## Alcance

La PR parte del `main` ya consolidado tras I4. Introduce `scripts/i5_chromium_flutter_smoke.py` y `.github/workflows/i5-browser-android.yml`.

**Chromium real:** la tarea CI levanta PostgreSQL17 desechable, aplica el esquema únicamente en la instancia CI, siembra identidades y fichas ficticias, compila Flutter Web y levanta el proxy HTTPS y Django de I4. El script I5 controla Chromium headless mediante Playwright, completa el formulario Django con el teclado del navegador, visita Flutter Web en tamaños 1440×900 y 390×844, exige cargas API reales correctas y ausencia de excepciones JavaScript, verifica aislamiento por tenant, capacidades de adjuntos bloqueadas y revocación por logout. Captura dos imágenes de los datos *sintéticos*, almacenadas como artifacts de Actions durante tres días.

El navegador del CI admite el certificado autofirmado del proxy mediante `ignore_https_errors=True`, exclusivamente para este laboratorio aislado. **No es prueba de cadena de confianza TLS**; I4 sí verifica de forma independiente CA y hostname con cliente Python.

**Android:** el segundo trabajo genera `app-debug.apk` con Flutter sobre Ubuntu/Android SDK. Comprueba que el entrypoint real Android sigue mostrando `AndroidWebAccessScreen`, que los laboratorios G8/G12/G13/G15 no están activados y que la firma de distribución sigue siendo obligatoria para cualquier release. La APK se compila pero **no se instala ni se ejecuta en teléfono**, no se firma para distribución ni se publica.

## Reglas y pendientes

- `I5_BROWSER_RESULT=PENDING` e `I5_ANDROID_RESULT=PENDING` hasta que los jobs del HEAD concreto terminen `success`.
- Capturar una imagen no demuestra diseño premium por sí solo: revisión visual de capturas pendiente.
- No se usa Playwright contra `dev.vencira.es` ni se envían datos reales de cliente.
- No prueba login nativo operativo ni convierte laboratorios en funcionalidad disponible.
- No se ejecutan migraciones en VPS ni despliegues, y no se abre el login nativo productivo.

`NO_DEPLOY_NO_LIVE_MIGRATION=1`
`MFA_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
