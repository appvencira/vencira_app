# VENCIRA D16 — Android candidate de la aplicación real (main.dart)

Fecha: 11/11/2026. Solo rama `main`. Estado: **script publicado, ejecución VPS pendiente**.

## Por qué D16

Tras `D15_RESULT=0`, la pila histórica de API + Nginx + copia O5 recuperada pasa HTTP interno sin cambios en DEV. Antes de poner la web pública y entregar un APK a usuarios, falta demostrar que el **Flutter real** se compila a APK Android nativo desde `lib/main.dart`, no desde `main_i8n_keystore_lab.dart` ni otras entradas sintéticas. Las pruebas I8-M/I8-P anteriores verificaban fronteras HTTPS y Keystore en laboratorios, pero no constituyen un APK firmado para distribución.

## Proceso D16

`scripts/main_d16_android_main_candidate_debug_gate.sh`:

- Operador no root, checkout Git limpio y exactamente `origin/main`; sin crear ramas. No acepta variables de release signing ni flags de laboratorios Android.
- Constata identidad de contenedores DEV antes/después; usa Docker solo para compilar Flutter 3.44.0 en contenedor efímero, con código Flutter montado **solo lectura** y copia de trabajo dentro del contenedor.
- Ejecuta `flutter pub get`, `flutter analyze`, pruebas de recuperación I8-Q/I8-L y contratos HTTP, después `flutter build apk --debug --target lib/main.dart`.
- Guarda un único APK debug, en ruta privada bajo `/home/vencira/vencira-android-candidate/<SHA-main>/`, con checksum SHA-256; valida el ZIP, `AndroidManifest.xml`, `classes.dex` y librería Flutter arm64.
- Rechaza sobreescribir un APK ya generado para ese commit. Ninguna firma release, instalación, publicación, conexión a DB ni cambio Caddy/DNS. **El APK debug no se distribuye como versión final.**

No se habilita MFA, no se cambia producción y no se lanza el I8-P interactivo durante D16. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

### Ejecución una vez en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d16_android_main_candidate_debug_gate.sh
echo "D16_SYNTAX=$?"
sudo -v
bash scripts/main_d16_android_main_candidate_debug_gate.sh
echo "D16_SHELL_RESULT=$?"
git status --short
```

### PASS exigido

```text
D16_MAIN_SYNC=PASS
D16_RELEASE_SIGNING_ENV_PRESENT=NO
D16_LAB_BUILD_ENV_PRESENT=NO
D16_DEV_IDENTITY=PASS
D16_FLUTTER_ANALYZE_TEST_BUILD=PASS
D16_APK_ZIP_INTEGRITY=PASS
D16_APK_SHA256_RECORDED=PASS
D16_APK_MAIN_ENTRYPOINT=YES
D16_APK_DEBUG_ONLY=YES
D16_APK_PHYSICAL_DEVICE_TEST=NOT_RUN
D16_APK_NATIVE_HTTPS_RELEASE_GATE=NOT_VERIFIED
D16_APK_RELEASE_SIGNING_GATE=NOT_VERIFIED
D16_DEV_CONTAINERS_UNCHANGED=OK
D16_RESULT=0
D16_SHELL_RESULT=0
```

El `D16_APK_PATH` mostrado por el script identifica el artefacto generado, no una distribución. No emitir/compartir certificados privados ni keystore. Si el gate falla, conservar solo marcadores, no repetir D12–D15. No publicar el APK hasta probar HTTPS real y firmado release con credenciales externas al repositorio.

## Próximas puertas

D17: prueba nativa del **APK real**, terminal Android y HTTPS/Keystore/recovery, manteniendo separado servidor sintético de entorno vivo. D18: build **firmado release** usando keystore externo, validación de firma, versión y permisos, y plan de rotación/rollback. En paralelo resolver si `vencira.es` debe migrar al VPS o permanecer en otra máquina: DNS apex y Caddy todavía no corresponden a una web pública VENCIRA operativa. La publicación exige autorización explícita posterior y cumplimiento de los gates.

## Ejecución VPS — D16 PASS (11/11/2026)

El operador confirmó: `D16_FLUTTER_ANALYZE_TEST_BUILD=PASS`, `D16_APK_ZIP_INTEGRITY=PASS`, `D16_APK_SHA256_RECORDED=PASS`, `D16_APK_MAIN_ENTRYPOINT=YES`, `D16_APK_DEBUG_ONLY=YES`, `D16_APK_PHYSICAL_DEVICE_TEST=NOT_RUN`, `D16_APK_NATIVE_HTTPS_RELEASE_GATE=NOT_VERIFIED`, `D16_APK_RELEASE_SIGNING_GATE=NOT_VERIFIED`, `D16_DEV_CONTAINERS_UNCHANGED=OK`, `D16_DEPLOY_EXECUTED=NO`, `D16_RELEASE_AUTHORIZED=NO` y `D16_RESULT=0`.

Artefacto generado bajo la ruta privada: `/home/vencira/vencira-android-candidate/b0a8b60ca1a873ce36c481d14827513c0ab054b5/VENCIRA-main-candidate-debug.apk`. Esta ruta es evidencia del resultado comunicado, no una descarga disponible desde GitHub. El script generó SHA256 pero el valor del hash no se incluyó en la salida del operador. Tampoco figura `D16_SHELL_RESULT` por separado en el fragmento mostrado.

**Gate D16 PASS únicamente para APK debug de la aplicación real, compilación/análisis/tests e integridad del ZIP.** La siguiente prueba decisiva es un dispositivo Android real. Los LAB I8-P/G13 anteriores validaban laboratorios con entradas distintas, no prueban la versión `main.dart`. No instalar ni distribuir como release un APK debug.

Los límites de seguridad se mantienen: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. D16 no ejecutó operaciones DEV ni publicación.
