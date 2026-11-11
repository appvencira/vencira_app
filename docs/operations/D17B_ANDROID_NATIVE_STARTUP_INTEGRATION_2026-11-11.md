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
