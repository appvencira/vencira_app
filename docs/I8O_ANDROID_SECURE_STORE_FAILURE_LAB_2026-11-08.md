# VENCIRA — I8-O Android: inyección de fallos del almacén seguro

**Estado al 08/11/2026:** implementado directamente en `main`, **pendiente de compilación y prueba física**.

## Objetivo y alcance preciso

I8-N acreditó, mediante capturas y confirmación de reinicio físico del operador, la persistencia del refresh sintético y del marcador entre reinicios Android, el cierre del fence y la limpieza del laboratorio.

I8-O aporta otro laboratorio **dentro de la misma APK debug independiente** `es.vencira.vencira.i8nlab`. La nueva acción **«I8-O · Comprobar fallos seguros»** usa el plugin real `flutter_secure_storage` (Android Keystore) bajo `storageNamespace=vencira_i8o_failure_lab_v1`. La credencial y el marcador son exclusivamente sintéticos y residen en un **namespace distinto** de I8-N. El wrapper `_FaultStore` simula fallos sobre el plugin mediante excepciones o confirmaciones de borrado falsas; el almacenamiento Android real sigue verificándose por lectura.

Se comprueban tres situaciones de riesgo, cada una sin red:
1. **Marcador no escribible:** el inicio de una operación potencialmente ambigua falla antes de realizar solicitudes HTTP, el marcador no se considera persistido y el fence no está activo. `I8O_ANDROID_MARKER_WRITE_DENIED=PASS`.
2. **Escritura de refresh fallida:** con marcador previamente persistido y refresh antiguo en Keystore, la sustitución por una credencial nueva falla. El refresh antiguo permanece intacto, el marcador obliga a reautenticación y el fence sigue cerrado. `I8O_ANDROID_REFRESH_WRITE_DENIED=PASS`.
3. **Borrado de marcador omitido:** la escritura del refresh nuevo se verifica, pero el wrapper simula una eliminación que informa éxito sin borrar. El re-read del marcador detecta el fallo; al construir un controlador nuevo, `NativeMobileStartupGate` exige `fullReauthentication` y ningún ticket activo. `I8O_ANDROID_MARKER_DELETE_DENIED=PASS`.

En todo caso se intenta limpiar únicamente las **dos claves conocidas del namespace I8-O**, con verificación del resultado: `I8O_ANDROID_FAILURE_LAB_CLEANUP=PASS`. No se toca la app principal ni el namespace I8-N, no se inicia sesión, no se emite/revoca sesión remota y no se prueban fallos reales del sistema Android: **los fallos de escritura/borrado se inyectan deliberadamente**.

La APK contiene el marcador de código `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Construir nueva APK usando Termius en VPS

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
set -o pipefail
bash scripts/main_i8n_android_keystore_lab_apk_build.sh 2>&1 | tee ~/vencira-i8o-android-build.log
echo "I8O_APK_BUILD_SHELL_RESULT=${PIPESTATUS[0]}"
```

Exigir `No issues found!`, `I8N_APK_DEBUG_BUILD=PASS`, `I8O_APK_BUILD_SHELL_RESULT=0`. El script incluye análisis estático de la entrada Flutter y el nuevo archivo I8-O. **Ningún PASS hasta ejecutar.** El artefacto se escribe en `~/vencira-i8n-phone/VENCIRA-I8N-Keystore-debug.apk`.

## Transferencia e instalación en Android sin ADB

Ya existe un túnel/acceso SSH entre el móvil y el VPS (operador confirmado). Usar Termux/SFTP/SCP para recuperar la APK actualizada; ejemplo opcional desde Termux, adaptando el host a la conexión ya configurada:

```bash
scp vencira@SERVIDOR_VPS:~/vencira-i8n-phone/VENCIRA-I8N-Keystore-debug.apk ~/storage/downloads/
```

Instalar como **actualización del MISMO paquete debug independiente** `es.vencira.vencira.i8nlab`, sin desinstalar ni borrar datos de otras apps, y sin tocar el paquete normal `es.vencira.vencira`. Conservar el método y certificado de firma debug del build anterior; si Android informa que la actualización tiene firma distinta, **no desinstalar ni forzar la sustitución** sin analizar antes la causa. El estado I8-N ya está validado y no necesita repetirse.

Abrir la aplicación y pulsar **«I8-O · Comprobar fallos seguros»**. Esperar a que el botón termine. Compartir una captura con las cinco líneas:

```text
I8O_ANDROID_MARKER_WRITE_DENIED=PASS
I8O_ANDROID_REFRESH_WRITE_DENIED=PASS
I8O_ANDROID_MARKER_DELETE_DENIED=PASS
I8O_ANDROID_FAILURE_FENCE=PASS
I8O_ANDROID_FAILURE_LAB_CLEANUP=PASS
```

Si aparece `I8O_ANDROID_FAILURE_LAB=FAIL`, no dar por superada la prueba ni repetir de forma indiscriminada: revisar el código y registrar el fallo sin exponer excepciones con datos del plugin.

## Límites y próximo gate

La prueba I8-M Flutter HTTPS + Django + PG17 temporal fue **PASS** en contenedores aislados; I8-N Android Keystore y persistencia tras reinicio físico fue **PASS**. I8-O prueba el manejo local de errores con el plugin real de almacenamiento, pero **no conecta Android a Django** ni sustituye un ensayo móvil integral de TLS, MFA, almacenamiento, revocación y corte de red. La siguiente integración deberá usar un lab HTTPS aislado mediante un túnel **sin conexión a la base DEV**, con CA/hostname verificados y sin elevar autorizaciones.

**No publicar nuevos endpoints de laboratorio ni habilitar aplicaciones de test en DEV.**
