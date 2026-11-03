# G8 — Validación de almacenamiento protegido con móvil Android físico

Estado: **CANDIDATO IMPLEMENTADO / NO VALIDADO EN DISPOSITIVO NI COMPILACIÓN CONFIRMADA** (03/11/2026).

## Justificación y límites

El operador ha decidido utilizar **su teléfono de pruebas Android instalando una APK**, en vez de usar emulador. El emulador G8 anterior conserva su propio ejecutor, pero **no es el procedimiento seleccionado para G8-PHONE**.

G7-D2/E/F/G/H cerró PASS integral por HTTPS en entorno Docker Django/Flutter con almacenes de secretos simulados, no con Android Keystore. La nueva APK no debe suplantar VENCIRA, operar con usuario/servidor real ni desbloquear la autenticación operativa.

## APK de prueba independiente

- APK Android **debug** y entrada independiente `clients/flutter/lib/g8_lab_main.dart`; no sustituye `clients/flutter/lib/main.dart`.
- Identificador Android **`es.vencira.vencira.g8lab`**, distinto del operativo **`es.vencira.vencira`**. Gradle añade `.g8lab` únicamente cuando el compilador recibe `VENCIRA_G8_LAB_BUILD=1` y se usa variante debug. La app Dart requiere además `--dart-define=VENCIRA_G8_LAB_BUILD=true` y rechaza release.
- Nombre del icono: **VENCIRA G8 Pruebas**. El manifest conserva `android:allowBackup="false"`.
- `FlutterNativeSecretStore` real con `FlutterSecureStorage`, `AndroidOptions(storageNamespace: "vencira_g8_phone_only_v1", resetOnError:false, migrateOnAlgorithmChange:false)`. El nombre de espacio es distinto tanto del emulador G8 como del almacén móvil futuro `vencira_mobile_refresh_v1`. La separación primaria es el identificador de paquete Android.
- Credenciales de prueba **fijas y públicas**, nunca refresh, Bearer, contraseñas ni códigos MFA reales. El secreto se mantiene solamente dentro del plugin de almacenamiento cifrado, no en SharedPreferences. La preferencia contiene únicamente el PID anterior para comprobar cambio de proceso.
- **Sin HTTP**, sin URL operativa conectada y sin migraciones. El literal `https://dev.vencira.es` se utiliza solo para construir el nombre lógico local de la clave de laboratorio; no se realiza conexión.
- **Limitación del APK:** incluye el permiso INTERNET heredado del manifest Android general, aunque el programa de laboratorio no utiliza ninguna API de red. No puede afirmarse que esté aislado a nivel del sistema operativo; la prueba es funcional, no una atestación de hardware ni una auditoría completa del APK.

## Compilación y descarga desde GitHub

Workflow exclusivo: `.github/workflows/g8-phone-apk.yml`.

Comandos alternativos si se dispone localmente de Flutter + Android SDK:

```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
bash scripts/g8_phone_apk_build.sh
```

El script analiza únicamente los artefactos G8, compila con `flutter build apk --debug --target=lib/g8_lab_main.dart --dart-define=VENCIRA_G8_LAB_BUILD=true`, fija el `VENCIRA_G8_LAB_BUILD=1` del paso Gradle, e inspecciona la identidad real con Android `aapt`. **Aborta** si el paquete no es exactamente `es.vencira.vencira.g8lab`. Entrega:

- `clients/flutter/build/g8-phone/VENCIRA-G8-LAB-debug.apk`
- `clients/flutter/build/g8-phone/VENCIRA-G8-LAB-debug.apk.sha256`

La CI publica ambos como artefacto `VENCIRA-G8-PHONE-DEBUG-ONLY` de GitHub Actions durante 7 días **solo si** el análisis, compilación e inspección de paquete finalizan con éxito. El workflow y los commits por sí solos **no demuestran que el APK se haya construido**. La APK de debug no utiliza ninguna firma de distribución y no se debe publicar como versión de VENCIRA.

## Ejecución en móvil de pruebas

1. Descargar el ZIP del artefacto de GitHub Actions **solo tras workflow verde**, extraer la APK, comprobar hash SHA256 si es posible y pasarla al móvil de pruebas. No instalar un archivo descargado de sitios ajenos.
2. Instalar `VENCIRA-G8-LAB-debug.apk` (quizá sea necesario permitir temporalmente instalar aplicaciones desde la aplicación Archivos). **No desinstalar VENCIRA** si ya estuviese instalada: el paquete G8 es diferente.
3. Abrir **VENCIRA G8 Pruebas**, tocar **Preparar prueba**. Resultado esperado `G8_PHONE_INITIAL_VAULT_VERIFIED=OK`, `G8_PHONE_RECOVERY_MARKER_ARMED=OK`, `G8_PHONE_RESTART_REQUIRED=1`.
4. Ir a **Ajustes del móvil > Aplicaciones > VENCIRA G8 Pruebas > Forzar detención**, y abrir otra vez la aplicación. Deslizar fuera de Recientes **no garantiza** que Android haya terminado el proceso.
5. Tocar **Verificar tras reinicio**. Se comprueba PID distinto, dato cifrado y marcador tras nuevo proceso, separación lógica dev/prod, reemplazo confirmado, marcador corrupto rechazado y limpieza verificada. Se muestra `G8_PHONE_PHYSICAL_STORAGE_RESULT=0` **solo si todo pasa**. Si aparece error, compartir únicamente su código y versión de Android, sin datos de aplicaciones.
6. Al terminar, **Borrar datos de laboratorio** (se borra solamente el namespace sintético); es posible desinstalar **VENCIRA G8 Pruebas** después.

## Gates y evidencias

- Código y controles fuente: `scripts/n1_static_security_gate.py` (nuevo `g8_physical_phone_debug_apk_isolated`).
- CI de compilación G8 Phone: **PENDING** hasta constatar un workflow verde y un APK generado.
- G8 Phone en Android real: **PENDING** hasta recibir `G8_PHONE_PHYSICAL_STORAGE_RESULT=0` del dispositivo.
- G8 emulador: candidato separado, no sustituye prueba física.
- `G7_D2_GATE_RESULT=0` y `G7_MACRO_RESULT=0`: PASS recibido, cierre de laboratorio HTTPS.
- `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Límites a resolver después

Un PASS de G8 confirmará funcionamiento de `flutter_secure_storage` y de nuestro protocolo de marcador/recuperación con un nuevo proceso en **ese teléfono**, pero no prueba atestación de hardware (StrongBox, TEE), seguridad contra root, reinstalación, backup/restore, integridad de sistema ni credenciales reales. La integración operativa de MFA y sesiones queda explícitamente desconectada de `main.dart`.

## Incidencia compilación G8 en GitHub Actions (03/11/2026)

El operador comunica que la compilación de la APK G8 por GitHub Actions **falló**. La API GitHub conectada ha permitido revisar el workflow `.github/workflows/g8-phone-apk.yml` y el script `scripts/g8_phone_apk_build.sh`, pero no proporciona **las ejecuciones push** ni sus logs por SHA: las consultas de estados y ejecuciones PR devolvieron listas vacías. El acceso público de navegación a la URL de Actions tampoco dio contenido del run. **La causa exacta del fallo no está determinada**: no atribuir a Gradle, Flutter, Android SDK, permisos o `aapt` sin el log de la ejecución.

Para mejorar visibilidad se añadió evento `pull_request` (además de `push` y `workflow_dispatch`) al workflow G8 Phone, con filtros por rutas G8. Permite registrar pruebas PR donde el conector soporte resultados. No se ha demostrado aún un PASS de esa nueva configuración. Se puede reproducir la compilación local con Docker ya utilizado para G7, sin necesidad de Flutter ni Android SDK instalados en el host:

```bash
cd ~/vencira-m3-localcheck
git status --short
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
set -o pipefail
sudo docker run --rm -v "$PWD:/src" -w /src ghcr.io/cirruslabs/flutter:stable bash scripts/g8_phone_apk_build.sh 2>&1 | tee /tmp/vencira-g8-phone-build.log
echo "G8_DOCKER_BUILD_RESULT=${PIPESTATUS[0]}"
```

El propio script rechaza compilar o publicar APK si `flutter analyze`, compilación debug y verificación del `applicationId` por `aapt` no terminan correctamente. Para diagnosticar una ejecución fallida, observar **el primer error real** del log local o compartir el enlace del workflow/run que terminó en rojo y las líneas del paso fallido (eliminar cualquier secreto que pudiera aparecer). **No instalar ninguna APK hasta conseguir `G8_PHONE_APK_ID_VERIFY=OK` y `G8_PHONE_APK_BUILD=OK`.** G7 completo sigue validado; G8 Phone build y prueba física siguen PENDING.

## G8 Phone local Docker build: 14 Dart analyzer issues, corrected source (03/11/2026)

El operador ejecutó la compilación local en la imagen `ghcr.io/cirruslabs/flutter:stable`. `flutter pub get` completó; `flutter analyze` detuvo el build con **14 incidencias** en `clients/flutter/lib/g8_lab_main.dart`: advertencias por `_failure`, `_markers` y `_clear` aparentemente no usados, **un error de retorno** en `_clear` línea 104 (`Future<void>` incompatible con `List<String>`) y una **coma/paréntesis sobrante** después de la tarjeta de resultado (anterior línea 209) que generó los restantes errores de parser (`Expected to find ']'`, `')'`, `';'`, texto inesperado). `G8_DOCKER_BUILD_RESULT=1` es correcto al fallar el análisis; no se produjo APK validada. No tiene relación con espacio de disco del VPS ni con la fase G7.

Corrección publicada: `_clear` se declara `Future<List<String>>` para respetar el contrato de `_run(Future<List<String>> Function())`, y se elimina únicamente el cierre extra de `Card` entre `_resultOk` e `if (_failure != null)`, conservando los cierres correctos. El fuente resultante conserva referencias a `_failure`, `_markers` y `_clear`; comprobación local de delimitadores balanceados sobre el fichero remoto OK, **pero no se dispone aún de reejecución `flutter analyze` ni de compilación APK**. Mantener `G8_PHONE_APK_BUILD=PENDING` y no recomendar instalación hasta confirmar `G8_PHONE_APK_ID_VERIFY=OK`, `G8_PHONE_APK_BUILD=OK`, exit 0. Repetir el runner único `bash scripts/g8_phone_apk_build.sh` o su envoltorio Docker anterior tras `git fetch` + fast-forward. PR sigue DRAFT, sin deploy ni migración.
