# VENCIRA — I8-P Android físico: HTTPS + MFA + Keystore + revocación

**Corte:** 08/11/2026. **Rama de integración:** exclusivamente `main`. **Estado:** código y runner integrados en GitHub; **no ejecutados ni certificados** aún.

## Qué agrupa esta fase

I8-P une las garantías obtenidas por separado: I8-M (**Flutter IOClient HTTPS + Django/PG17 temporal PASS**), I8-N (**Keystore y marcador persistentes tras reinicio Android PASS**) e I8-O (**errores inyectados en Keystore Android 5/5 PASS**). La integración nueva se ejecuta por primera vez en Android físico y conecta al laboratorio Docker interno a través de un túnel SSH ya disponible.

**No conecta con DEV ni con PostgreSQL persistente. No importa `main.dart` ni habilita los endpoints móviles en `backend/config/urls.py`.** Construye la aplicación Android debug exclusiva `es.vencira.vencira.i8plab`, con un formulario de ensayo y ninguna pantalla con datos reales.

Componentes:
- `clients/flutter/lib/main_i8p_android_https_lab.dart`: desde Android se conecta exclusivamente a `127.0.0.1:18743`; el socket se convierte a TLS con `SecureSocket.secure(host:'dev.vencira.es')`, una CA pública de laboratorio embebida al compilar y `SecurityContext(withTrustedRoots:false)`; no se permite una excepción de certificado. Comprueba además el rechazo de un SNI/hostname incorrecto antes de enviar contraseñas.
- El cliente construye `NativeHttpAuthPort`, `NativeRefreshCredentialVault`, `NativeRefreshRecoveryJournal`, `NativeMobileRecoveryEntry` y `NativeSessionFence` reales sobre `FlutterNativeSecretStore` en namespace Android independiente `vencira_i8p_mobile_tls_lab_v1`.
- Solo se utilizan `i8p-recovery`, contraseña `synthetic-i8p-password` y el secreto RFC 6238 **público** de prueba. No hay datos ni claves reales. Se simula un refresh huérfano, se exige contraseña+MFA por HTTPS, se confirma el refresh nuevo con lectura desde Keystore, se revoca remotamente, se exige 401 para el access token ya revocado y se elimina el refresh de forma verificada.
- `scripts/main_i8p_ssh_tls_loopback_relay.py`: relay de bytes TLS cifrados, escucha **solo** `127.0.0.1:18743` del VPS y conecta a la IPv4 privada del contenedor Django 443, sin puertos Docker publicados ni inspección del contenido.
- `scripts/main_i8p_android_ssh_https_pg17_lab.sh`: preflight de salud y etiquetas de los tres contenedores DEV, build Django temporal, red `--internal`, PostgreSQL 17 `tmpfs`, migración **solo temporal**, usuarios/sesiones sintéticas, CA autofirmada por ejecución (el archivo con **clave privada nunca se envía al móvil**), API Django test-only, relay localhost, compilación Flutter debug aislada, espera interactiva para prueba del teléfono y comprobación final SQL de revocación de ambas sesiones. `trap` elimina los contenedores, la imagen, la red, el relay y los certificados del VPS. Detecta cambio de IDs/imágenes de DEV al salir.
- `clients/flutter/android/app/build.gradle.kts`: solo `VENCIRA_I8P_LAB_BUILD=1` habilita el sufijo de paquete `.i8plab` en debug; es mutuamente excluyente con otros laboratorios y no permite release/profile.

La CA pública se inserta en **la APK debug construida para esa ejecución**: si el laboratorio se reinicia o se vuelve a generar el certificado, la APK anterior no servirá. No utilizar CAs reales de producción. La app no envía credenciales si el certificado o el hostname no se verifican.

## Paso único del operador: arrancar laboratorio en Termius VPS

Mantenerlo en una sesión **tmux** del VPS, sin cerrar ni pulsar INTRO hasta terminar la prueba móvil:

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD

bash -n scripts/main_i8p_android_ssh_https_pg17_lab.sh
python3 -m py_compile scripts/main_i8p_ssh_tls_loopback_relay.py

set -o pipefail
bash scripts/main_i8p_android_ssh_https_pg17_lab.sh 2>&1 | tee ~/vencira-i8p-android-lab.log
echo "I8P_SHELL_RESULT=${PIPESTATUS[0]}"
```

El gate no está certificado. Comprobar primero:

```text
I8P_EPHEMERAL_PG17_READY=PASS
I8P_EPHEMERAL_SCHEMA=PASS
I8P_PG17_SYNTHETIC_ACCOUNT=PASS
I8P_TLS_SERVER_INTERNAL_READY=PASS
I8P_SSH_RELAY_LOOPBACK_ONLY=PASS
I8P_ANDROID_APK_DEBUG_BUILD=PASS
I8P_ANDROID_PACKAGE=es.vencira.vencira.i8plab
```

Si falla cualquiera, no transferir la APK ni afirmar PASS. `flutter analyze` y `flutter build apk` están dentro de este único ejecutor.

## Conectar Android con el SSH ya configurado

Con la sesión VPS **tmux abierta y esperando INTRO**:

1. Copiar `~/vencira-i8p-phone/VENCIRA-I8P-Android-HTTPS-debug.apk` al móvil usando el mismo Termux/SFTP/SCP ya empleado en I8-N/I8-O. Ejemplo orientativo: `scp vencira@SERVIDOR_VPS:~/vencira-i8p-phone/VENCIRA-I8P-Android-HTTPS-debug.apk ~/storage/downloads/`; sustituir el host según la conexión SSH real del usuario, sin inventar dirección.
2. En Termux, **abrir otra sesión** SSH con reenvío local mientras se ejecuta la prueba: `ssh -N -L 127.0.0.1:18743:127.0.0.1:18743 vencira@SERVIDOR_VPS`. La redirección existente puede reaprovecharse **si enlaza exactamente el puerto 18743 del móvil con el 18743 de localhost del VPS**. Un túnel SSH con otro puerto no es equivalente. Ningún puerto público abierto.
3. Instalar la APK debug exclusiva `es.vencira.vencira.i8plab`. No desinstalar I8-N/I8-O ni la aplicación VENCIRA normal. Abrir **VENCIRA · Android I8-P**, pulsar «Ejecutar ensayo completo» y guardar captura del resultado. El flujo se ejecuta con credenciales sintéticas, sin formulario de usuario.
4. **Solo después** de observar el resultado Android, volver a la sesión tmux del VPS y pulsar INTRO. El script comprueba el estado transaccional final en PostgreSQL17 temporal: debe emitir `I8P_PG17_OLD_AND_NEW_SESSION_REVOKED=PASS`, `I8P_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS`, `I8P_DEV_CONTAINERS_UNCHANGED=OK`, `I8P_LAB_RESULT=0`. Termux SSH podrá cerrarse entonces; el script desmontará el laboratorio.

La pantalla Android debe mostrar:

```text
I8P_ANDROID_TLS_HOSTNAME=PASS
I8P_ANDROID_RECOVERY_MFA_KEYSTORE=PASS
I8P_ANDROID_REMOTE_REVOKE=PASS
I8P_ANDROID_ACCESS_AFTER_REVOKE_401=PASS
I8P_ANDROID_LAB_CLEANUP=PASS
```

**No dar I8-P por superado sin las evidencias de Android y PostgreSQL.** Si la pantalla muestra `I8P_ANDROID_GATE=FAIL`, no pulsar INTRO para producir un falso PASS: conservar el laboratorio mientras se diagnostica, sin registrar secretos ni rutas operativas. El usuario puede cancelar con Ctrl+C; se eliminará el laboratorio.

## Restricciones y próximos pasos

- `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `I8P_RELEASE_AUTHORIZED=NO`.
- Sin despliegue, sin migraciones persistentes y sin abrir rutas de la candidata en DEV.
- La autenticación/CA es válida **exclusivamente para este laboratorio**: no demuestra custodia de claves operativas ni despliegue seguro.
- La revocación remota y almacenamiento Android se validan de forma conjunta; los fallos intencionados de escritura/borrado de I8-O no están inyectados sobre la **misma conexión HTTPS I8-P**. Ese ensayo integrado de fallo de red/Keystore queda como siguiente gate separado, sin reinterpretar PASS anteriores.
