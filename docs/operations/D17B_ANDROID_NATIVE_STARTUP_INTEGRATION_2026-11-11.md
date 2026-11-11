# VENCIRA D17-B — Integración segura del estado nativo Android en main

Fecha: 11/11/2026. Rama `main`. **Código publicado; prueba Flutter pendiente del VPS.**

## Motivación

D16 produjo APK debug real desde `lib/main.dart`; D17 visual muestra que Android lanzaba directamente `AndroidWebAccessScreen`, con redirección a Chrome. Los LAB I8-P/G13 sí ejercitan HTTPS/Keystore/MFA con rutas sintéticas, pero no son autorización para conectar al servidor real ni para emisión/recuperación de credenciales a usuarios.

Se revisaron los componentes existentes:
- `NativeMobileStartupGate`: revoca ticket sincronamente, después inspecciona marker y vault; clasifica `cleanLogin`, `fullReauthentication` o fallo cerrado.
- `NativeRefreshCredentialVault` y `NativeRefreshRecoveryJournal`: almacenamiento `FlutterSecureStorage` con namespace por entorno; falta integración del issuer real en main.
- `NativeFirstIssuanceEntry`, `NativeRecoveryLoginGateway`, `NativeHttpAuthPort`: puertos/contratos con capacidades ensayadas en LAB, **no emisión operacional autorizada**.
- `NativeLoginScreen`: UI de credenciales **no enrutada desde main**, y no debe enrutarse hasta verificar contrato completo con backend vigente.

## Cambio realizado

- `clients/flutter/lib/ui/native_android_startup_boundary.dart`: nuevo boundary real de Android. Antes de mostrar la puerta web inspecciona vault/journal del entorno `dev.vencira.es` y decide:
  - `cleanLogin`: mantiene acceso web, no crea sesión nativa.
  - `fullReauthentication`: mensaje de que hay credenciales antiguas o recuperación pendiente; no permite login ni replay.
  - Error de lectura/almacenamiento: advertencia de bloqueo nativo; no permite credenciales.
  - En inspección pendiente no renderiza ningún acceso, evitando navegación prematura desde la vista nueva.
- `main.dart`: conserva `DeviceNoticeStartupGate` para cancelar alarmas; pasa de `AndroidWebAccessScreen` directo a `NativeAndroidStartupBoundary` en Android real. La pantalla de LAB inyectada solo se presenta en debug y no cambia.
- `android_web_access_screen.dart`: `statusMessage` opcional para mostrar el estado nativo bloqueado. Sigue abriendo HTTPS en navegador externo.
- `test/native_android_startup_boundary_test.dart`: pruebas con inyección del resultado del preflight, para clean/recovery/storage-error/inspección aún no resuelta. Comprueban que nunca aparece `native-login-submit`.
- `scripts/main_d17b_android_startup_boundary_gate.sh`: valida `flutter analyze`, esos tests y regresiones I8-Q/I8-L en contenedor Flutter efímero, sin instalar APK ni modificar contenedores DEV.

## Ejecución VPS

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d17b_android_startup_boundary_gate.sh
echo "D17B_SYNTAX=$?"
sudo -v
bash scripts/main_d17b_android_startup_boundary_gate.sh
echo "D17B_SHELL_RESULT=$?"
git status --short
```

Resultado necesario: `D17B_MAIN_CLEAN=PASS`, `D17B_DEV_IDENTITY=PASS`, `D17B_FLUTTER_GATE=PASS`, `D17B_NATIVE_STARTUP_INTEGRATED=YES`, `D17B_AUTH_PRODUCTION_ENABLED=NO`, `D17B_DEV_CONTAINERS_UNCHANGED=OK`, `D17B_RESULT=0`, `D17B_SHELL_RESULT=0`.

## Estado de release

La integración no habilita ninguna llamada password/MFA, no emite refresh, no rota claves, no autentica usuarios ni ofrece acceso a espacios privados de forma nativa. La URL de entorno nativo es `https://dev.vencira.es`, no una configuración dinámica de producción. No afirmar APK de distribución listo. Faltan issuer Django autorizado, revisión de rutas HTTPS en entorno final, secure store/vault en dispositivo real, recovery/account-wide revocation y pruebas de logout bajo fallos, firma release y distribución Android.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

## Primera validación — D17-B FAIL por overflow de UI (11/11/2026)

Salida del VPS: `flutter analyze` **0 issues**; I8-Q timeout de password, MFA ambiguo y fallo combinado de almacén/revocación **PASS**; las pruebas I8-L presentes continuaron ejecutándose sin fallos visibles. La única prueba fallida fue `orphan refresh requires recovery and never exposes login` con `RenderFlex overflowed by 28 pixels on the bottom` al mostrar el aviso de recuperación. Marcadores `D17B_FLUTTER_GATE=FAIL`, `D17B_DEV_CONTAINERS_UNCHANGED=OK`, `D17B_RESULT=4`. Esto es defecto de layout, no evidencia de un fallo de autorización nativa.

Correcciones ya publicadas en `main`: `d9098499` hace desplazable `AndroidWebAccessScreen` mediante `SingleChildScrollView` para acomodar mensajes largos y teléfonos pequeños; `847af3c3` incorpora regresión en viewport de 320x480 y comprueba ausencia de excepciones, scroll y que no exista botón de login nativo. No cambian endpoints, credenciales, permisos ni releases.

**Repetir únicamente D17-B** tras `git fetch` y `git merge --ff-only origin/main`; seguir el bloque original de validación de esta documentación. **D17-B continúa pendiente de PASS** hasta recibir `D17B_FLUTTER_GATE=PASS` y `D17B_RESULT=0`. No construir APK nuevo ni instalarlo hasta pasar el gate.

## Validación final D17-B — PASS (11/11/2026)

Salida del VPS: `flutter analyze`: **No issues found**. Los 15 tests del conjunto (5 del boundary Android, 3 I8-Q y 7 I8-L) se ejecutaron correctamente: `All tests passed!`. Pasaron los casos clean login sin acceso nativo, refresh anterior con recuperación obligatoria, error de protected store cerrado, regresión de viewport compacto y espera de inspección, además de timeout/MFA ambiguo/fallo de escritura-revocación y recuperación segura I8-L. El operador informa `D17B_FLUTTER_GATE=PASS`, `D17B_NATIVE_STARTUP_INTEGRATED=YES`, `D17B_AUTH_PRODUCTION_ENABLED=NO`, `D17B_DEV_CONTAINERS_UNCHANGED=OK` y `D17B_RESULT=0`. No consta `D17B_SHELL_RESULT` independiente en el fragmento.

**D17-B PASS** para integración fail-closed de arranque Android y regresión Flutter. No afirma autenticación nativa real operativa, prueba física del nuevo binario, ni firma release. No repetir D17-B salvo cambio del código de boundary. Las siguientes puertas requieren explícitamente un emisor backend apto para producción y pruebas reales HTTPS/Keystore/logout/recovery; no convertir los endpoints LAB en endpoints públicos sin esas garantías.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
