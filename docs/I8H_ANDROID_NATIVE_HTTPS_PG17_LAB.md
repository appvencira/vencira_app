# I8-H — Android físico contra servicio nativo HTTPS candidato / PostgreSQL 17

**Estado 07/11/2026: código preparado en GitHub; NO EJECUTADO; NO PASS.**

## Objetivo y aislamiento

Prueba física del cliente Flutter real: `NativeHttpAuthPort`, `NativeFirstIssuanceEntry`, `NativeSessionCoordinator`, `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal`, `NativeApiTransport` y `FlutterNativeSecretStore`. El servicio utiliza exclusivamente `backend/native_mobile_service/test_i8d_urls` a través de WSGI HTTPS test-only; PostgreSQL 17 tmpfs, red Docker `--internal`, TLS certificado temporal con SAN `dev.vencira.es`, claves MFA sintéticas y ninguna migración/deploy persistente.

La APK DEBUG `es.vencira.vencira.i8hlab` no comparte identificador ni almacenamiento con la app principal o con I8-G/G13. El código exige `VENCIRA_I8H_LAB_BUILD=true` de compilación y el build Gradle `VENCIRA_I8H_LAB_BUILD=1`. No existe entrada a `main.dart`. No se incorpora una clave privada a la APK. El certificado público de un día se inyecta solo en el binario DEBUG y **no se usa fuera del laboratorio**.

## Macroejecución única en VPS (Termius)

```bash
cd ~/vencira-m3-localcheck
git fetch origin refs/heads/feature/m3-android-local-notifications:refs/remotes/origin/feature/m3-android-local-notifications
git merge-base --is-ancestor HEAD origin/feature/m3-android-local-notifications
git merge --ff-only origin/feature/m3-android-local-notifications
bash -n scripts/native_i8h_android_https_pg17_lab.sh
bash scripts/native_i8h_android_https_pg17_lab.sh
echo "NATIVE_I8H_TERMIUS_RESULT=$?"
```

El script comprueba contenedores DEV, compila backend, crea PG17 disposable, verifica G5 keys y paridad de migraciones, crea dos usuarios MFA ficticios, servidor HTTPS, relay exclusivamente `127.0.0.1:18743` de G13 y prueba el `401` anónimo validando certificado y hostname. Ejecuta `flutter analyze` y compila la APK DEBUG separada. Conserva el laboratorio vivo con un prompt; **no se debe pulsar ENTER hasta terminar en el teléfono**. `NATIVE_I8H_PHONE_RESULT=PENDING` es correcto: el VPS no puede certificar lo que aparece en la pantalla Android.

La APK se deja, si compila, en `~/vencira-m3-localcheck/clients/flutter/build/i8h-phone/VENCIRA-I8H-LAB-debug.apk` y un `.sha256` acompañante. Transfiérela por SCP/SFTP autenticado; comprueba SHA256 y el identificador del paquete. Ningún puerto público ni descarga HTTP.

## Teléfono Android físico (dos terminales)

1. Mantén el proceso del laboratorio del VPS abierto.
2. En Termux/SSH del teléfono inicia la redirección **desde el teléfono hacia el VPS**:
   `ssh -N -L 127.0.0.1:18743:127.0.0.1:18743 <usuario_ssh>@<host_vps>`.
   No usar SSH desde una interfaz distinta de loopback ni abrir puertos públicos.
3. Instala manualmente la APK DEBUG específica I8-H. Debe ser una app separada `es.vencira.vencira.i8hlab`.
4. Pulsa una sola vez **Ejecutar prueba integral I8-H**. Verifica en pantalla los ocho marcadores `NATIVE_I8H_ANDROID_...=PASS` y `NATIVE_I8H_ANDROID_REAL_HTTPS_RESULT=0`.
5. Mantén el túnel conectado hasta que confirme `NATIVE_I8H_ANDROID_REMOTE_LOGOUT=PASS`. Solo entonces pulsa ENTER en el VPS, comprueba limpieza de PG17/red/certificado. Desinstala el paquete DEBUG cuando termine.

Si falla antes de confirmar revocación, **no repitas el login** ni pulses una limpieza local que borre un refresh no revocado: la nueva emisión queda cercada por `NativeRefreshRecoveryJournal`. Detén el laboratorio VPS para destruir el servidor y BD sintéticos; entonces puedes desinstalar la APK. Para repetir, crea nuevo laboratorio con otro certificado/base efímera y reinstala el paquete de prueba desde cero. No transferir nombres/tokens/códigos de MFA a logs o capturas.

## Marcadores y alcance

Del VPS: `NATIVE_I8H_G5_SETTINGS_READY=OK`, `NATIVE_I8H_PG17_READY=YES`, `NATIVE_I8H_SERVER_READY=YES`, `NATIVE_I8H_HOST_HTTPS_401=PASS`, `NATIVE_I8H_FLUTTER_ANALYZE=OK`, `NATIVE_I8H_DEBUG_APK_BUILD=PASS`, `NATIVE_I8H_LIVE_CONTAINERS_UNCHANGED=OK` y `NATIVE_I8H_LOCAL_RESULT=0`.

De Android: `NATIVE_I8H_ANDROID_CA_VERIFIED=PASS`, `NATIVE_I8H_ANDROID_UNTRUSTED_CA_DENIED=PASS`, `NATIVE_I8H_ANDROID_PASSWORD_NO_TOKENS=PASS`, `NATIVE_I8H_ANDROID_MFA_PG17_ISSUED=PASS`, `NATIVE_I8H_ANDROID_KEYSTORE_REFRESH=PASS`, `NATIVE_I8H_ANDROID_BEARER_ME=PASS`, `NATIVE_I8H_ANDROID_REMOTE_LOGOUT=PASS`, `NATIVE_I8H_ANDROID_REAL_HTTPS_RESULT=0`.

Los marcadores Android son **solo resultados reportados por la APK**; revisión formal requiere pantalla/log de ejecución y coordinación con el cierre de VPS. El flujo positivo **NO** cubre recuperación después de caída, cuentas sin MFA, rotación desde el propio Android, seguridad criptográfica hardware atestada, continuidad frente a reinicio o endpoint público autorizado. Los escenarios G13 originales son complementarios, no certificados del emisor nativo I8-H.

Mantener obligatoriamente `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
