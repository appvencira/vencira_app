# VENCIRA — I8-Q: matriz consolidada de fallos de recuperación nativa

**08/11/2026. Rama exclusiva: `main`. Estado: integrada, PENDIENTE DE EJECUCIÓN.**

## Punto de partida real

El operador ha acreditado: I8-M (Flutter HTTPS y Django/PG17 sintético), I8-N (Keystore persistente en dispositivo Android tras reinicio), I8-O (errores inyectados de escritura/borrado en dispositivo Android), e I8-P (Android HTTPS, recuperación MFA, Keystore real y revocación de dos sesiones en PG17 temporal) todos **PASS**. El cierre I8-P produjo `I8P_LAB_RESULT=0`, `I8P_DEV_CONTAINERS_UNCHANGED=OK`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Bloque I8-Q integrado

`clients/flutter/test/native_i8q_recovery_fault_matrix_test.dart` incorpora tres regresiones deterministas sobre `NativeHttpAuthPort`, `NativeRecoveryLoginGateway`, `NativeMobileRecoveryEntry`, `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal` y `NativeSessionFence`, sin modificar código operativo:

1. **Respuesta de contraseña perdida:** un único intento `/recover/password/` falla por timeout sintético; no se activa bearer, sigue el refresh anterior y el siguiente arranque obliga a recuperación completa. Marca: `I8Q_PASSWORD_TIMEOUT_FENCED=PASS`.
2. **Resultado de TOTP ambiguo:** contraseña devuelve desafío, pero tras enviar MFA la respuesta desaparece. El cliente no reintenta el POST de TOTP, no presume el token emitido ni activa sesión; tras reconstruir el controlador, se exige reautenticación. Marca: `I8Q_AMBIGUOUS_MFA_NO_RETRY=PASS`.
3. **Escritura protegida fallida y revocación incierta:** el backend sintético devuelve tokens nuevos, pero el almacén simula error al guardar el refresh; el cliente envía exactamente ese refresh a `/token/revoke/`, cuya respuesta se pierde. Se mantiene fence cerrado y checkpoint duradero para recuperación posterior, sin promover credenciales. Marca: `I8Q_STORAGE_AND_REVOKE_UNKNOWN_FENCED=PASS`.

Estas tres pruebas usan `MockClient` y almacén sintético para inyectar fallos reproducibles. **No simulan una pérdida de red física del teléfono ni sustituyen el gate I8-P, que sí utilizó HTTPS/Android reales.** Su propósito es cubrir las ambigüedades de transacción y asegurar que una regresión de código no reabra sesiones inseguras.

Se añadió `scripts/main_i8q_android_recovery_fault_matrix_local.sh`: ejecuta `flutter pub get`, `flutter analyze` del test I8-Q y las cuatro suites `native_i8q_recovery_fault_matrix_test.dart`, `native_i8l_http_recovery_integration_test.dart`, `native_http_auth_port_test.dart`, `native_api_endpoint_test.dart` en Docker Flutter 3.44, con checkout del host en solo lectura; verifica la salud/identidad de los tres contenedores DEV antes y después, no accede a DB ni realiza deploy.

## Validación única en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
bash -n scripts/main_i8q_android_recovery_fault_matrix_local.sh
set -o pipefail
bash scripts/main_i8q_android_recovery_fault_matrix_local.sh 2>&1 | tee ~/vencira-i8q-fault-matrix.log
echo "I8Q_SHELL_RESULT=${PIPESTATUS[0]}"
```

Exigir todos los marcadores de prueba, `All tests passed!`, `I8Q_FLUTTER_FAULT_MATRIX_GATE=PASS`, `I8Q_DEV_CONTAINERS_UNCHANGED=OK` e `I8Q_LOCAL_RESULT=0`. **No declarar PASS por crear archivos en GitHub**.

## Puerta siguiente

Después de cerrar la matriz, diseñar una prueba Android física bajo HTTPS temporal con fallos de transporte controlados, sin asumir que basta cortar el túnel manualmente: cada escenario debe fijar en qué momento se perdió la respuesta y comprobar el estado de servidor y del Keystore. Cualquier fallo remoto cuya confirmación sea ambigua exige recuperación completa, no repetición del refresh antiguo.

**Sin despliegue ni migraciones de DEV. MFA permanece desautorizado.**
