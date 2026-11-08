# VENCIRA — I8-N Android Keystore: persistencia y fence tras reinicio

**Corte:** 2026-11-08. **Rama:** `main`. **Estado:** código de prueba preparado, NO ejecutado todavía en Android físico. **Sin despliegue ni migración persistente**.

## Alcance

La prueba `clients/flutter/integration_test/native_i8n_android_restart_secure_store_test.dart` integra **`FlutterNativeSecretStore` (plugin `flutter_secure_storage`)** con los componentes reales de VENCIRA `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal` y `NativeMobileStartupGate`. Usa exclusivamente un refresh **sintético** y un marcador no secreto. No usa contraseñas, cuentas ni un backend y **no envía solicitudes HTTP**.

- Almacén Android **separado**: `storageNamespace=vencira_i8n_restart_lab_v1`, distinto del namespace de la app normal.
- Paquete debug Android exclusivo: `es.vencira.vencira.i8nlab`, activado solo por `VENCIRA_I8N_LAB_BUILD=1` en Gradle; queda prohibido en release/profile y es mutuamente excluyente con G8/G12/G13/G15.
- Tres ejecuciones independientes, con compilación `--dart-define=VENCIRA_I8N_ANDROID_LAB=true` y `--dart-define=VENCIRA_I8N_PHASE=...`:
  1. `seed`: borra solo los dos nombres conocidos en el namespace de laboratorio, escribe un refresh sintético, verifica lectura, arma el marcador persistente y confirma ausencia de sesión activa.
  2. **Tras la salida del primer proceso**, `verify`: instancia de nuevo las clases, lee lo persistido, comprueba `fullReauthentication` y el fence cerrado. No acepta un refresh previo como nueva sesión ni solicita red.
  3. `cleanup`: elimina y verifica el borrado de ambas claves, comprueba `cleanLogin` no autenticado con fence cerrado.

**Importante:** una reejecución de `flutter test` puede **reinstalar o limpiar** datos según el runner y el entorno. La persistencia real *no debe darse por acreditada* sin observar `verify=PASS` en otro proceso **y verificar que el paquete no fue desinstalado ni sus datos borrados** entre seed y verify. Este gate tampoco prueba `kill -9` durante escrituras, secretos reales, certificados TLS, ni recuperación de una sesión operativa.

## Validación estática segura desde VPS (sin Android conectado)

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
sudo docker run --rm \
  -v "$PWD/clients/flutter:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.44.0 \
  sh -c '
    cp -a /source /tmp/vencira-flutter &&
    cd /tmp/vencira-flutter &&
    flutter pub get &&
    flutter analyze integration_test/native_i8n_android_restart_secure_store_test.dart
  '
echo "I8N_ANDROID_STATIC_RESULT=$?"
```

## Ejecución real en un host con Flutter 3.44, Android SDK y dispositivo ADB

**No lanzar estos comandos en el VPS si no dispone de conexión ADB al teléfono.** Usar un host de desarrollo donde `flutter devices` muestre el dispositivo Android, preferiblemente por USB. Tener instalada solo la APK de laboratorio o asegurarse de que no se toca el paquete normal. El Gradle wrapper requiere los SDK de Android habituales.

```bash
cd clients/flutter
flutter devices
export VENCIRA_I8N_LAB_BUILD=1
flutter test integration_test/native_i8n_android_restart_secure_store_test.dart \
  -d ID_DEL_DISPOSITIVO \
  --dart-define=VENCIRA_I8N_ANDROID_LAB=true \
  --dart-define=VENCIRA_I8N_PHASE=seed
# Verificar: I8N_ANDROID_KEYSTORE_SEED=PASS

# Confirmar que terminó el primer proceso Y que el paquete
# es.vencira.vencira.i8nlab NO ha sido desinstalado / limpiado.
flutter test integration_test/native_i8n_android_restart_secure_store_test.dart \
  -d ID_DEL_DISPOSITIVO \
  --dart-define=VENCIRA_I8N_ANDROID_LAB=true \
  --dart-define=VENCIRA_I8N_PHASE=verify
# Verificar: I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS

flutter test integration_test/native_i8n_android_restart_secure_store_test.dart \
  -d ID_DEL_DISPOSITIVO \
  --dart-define=VENCIRA_I8N_ANDROID_LAB=true \
  --dart-define=VENCIRA_I8N_PHASE=cleanup
# Verificar: I8N_ANDROID_KEYSTORE_CLEANUP=PASS
```

Si el test runner limpia datos o reinstala con eliminación previa, **detener el proceso** y adaptar la ejecución de instrumentación para conservar los datos de la APK; no marcar PASS. No ejecutar `adb shell pm clear` sobre paquetes existentes ni desinstalar la aplicación principal.

## Estado y siguiente gate

- `MAIN_I8M_FLUTTER_TLS_RECOVERY_GATE=PASS`: autenticación/revocación HTTPS en laboratorio aislado, con almacenamiento simulado.
- `I8N_ANDROID_STATIC_RESULT`: pendiente de informe del operador.
- `I8N_ANDROID_KEYSTORE_SEED`, `I8N_ANDROID_RESTART_RECOVERY_FENCED`, `I8N_ANDROID_KEYSTORE_CLEANUP`: **NO EJECUTADOS**.
- **No incluye recuperación HTTPS de Android físico**: el futuro gate combinará el test Keystore con el cliente HTTPS, manteniendo las garantías de red/identidad y las restricciones de despliegue.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
