# G12 — Android físico: primera emisión y recuperación con almacenamiento protegido

Estado: **IMPLEMENTADO EN RAMA / COMPILACIÓN APK Y ENSAYO FÍSICO PENDIENTES** (04/11/2026).

## Evidencia cerrada antes de G12

G7 D2/E/F/G/H = PASS HTTPS con Django sintético, G8-PHONE = PASS en Android físico para la persistencia cifrada tras reinicio real, G9 = PASS unitario, G10 = PASS unitario, G11 = PASS HTTPS sintético con Django temporal. Ninguno de esos resultados demuestra todavía el recorrido G9/G10/G6 completo **en un proceso Android físico con el plugin real**.

## Alcance exacto

G12 es una aplicación **exclusivamente de laboratorio, Android DEBUG**, aislada tanto de G8 como de VENCIRA real. Su APK tendrá `applicationId=es.vencira.vencira.g12lab`, nombre `VENCIRA G12 Pruebas` y `FlutterSecureStorage AndroidOptions(storageNamespace: 'vencira_g12_phone_only_v1', resetOnError: false, migrateOnAlgorithmChange: false)`.

**No conecta a Django ni a internet**. `NativeApiEndpoint.parse('https://dev.vencira.es')` se usa únicamente para derivar los nombres DEV de las claves y NO construye un cliente HTTP. El puerto `_SyntheticPort` simula contraseña, MFA, recuperación y revocación con credenciales sintéticas públicas fijas, verificando que exista marcador durable y que el fence esté cerrado antes de toda operación. Son **simulaciones de respuesta de servidor**, no evidencia de revocación remota real. La prueba HTTPS real ya se cubrió separadamente en G11. No afirmar que G12 ejecuta HTTPS en el teléfono.

## Prueba física en dos arranques

**Preparar prueba G12** (primer arranque de la APK):
1. Verifica vault y marcador G12 inicialmente vacíos.
2. Ejecuta G9 `cleanLogin`, G10 primera emisión y confirma refresh protegido antes de abrir la sesión.
3. Ejecuta G10 logout con fence cerrado, revocación sintética y limpieza del almacén.
4. Repite con desafío MFA sintético: la contraseña sola no desbloquea; TOTP sintético confirma la credencial y el logout limpia.
5. Ensaya fallo de revocación sintética con marcador durable, fence cerrado y retry seguro hasta limpiar.
6. Simula emisión remota con respuesta perdida: NO conoce ningún access/refresh, deja un marcador cifrado permanente y fence cerrado.
7. Guarda únicamente el PID no secreto en `SharedPreferences`. Claves y credenciales sintéticas usan el plugin protegido.

**Reiniciar proceso**: Ajustes de Android → Aplicaciones → VENCIRA G12 Pruebas → Forzar detención. Abrir de nuevo la APK. No basta cerrar la pantalla, cambiar de app o volver a la página anterior. **Verificar tras reinicio**:
1. Exige PID distinto y marcador protegido presente, refresh ausente y fence sin ticket.
2. Comprueba claves de dev separadas de prod (siempre dentro del paquete de laboratorio).
3. G9 exige `fullReauthentication`, nunca un login normal por fallback.
4. G6 recuperación: contraseña sintética → desafío MFA sintético → token nuevo y reemplazo cifrado verificado → borrado de marcador → fence activado. El antiguo refresh no se reproduce.
5. Limpieza protegida final: arma marcador, cierra fence, hace revocación sintética, borra el refresh y verifica borrado de marcador. No es un `logout()` público del gateway de recuperación; esa integración sigue pendiente.
6. Comprueba rechazo de marcador corrupto y borra solo las claves G12 y PID.

Salida esperada paso 2 **solo tras ejecución en teléfono**, nunca anticipar PASS:

```text
G12_ANDROID_NEW_PROCESS_CONFIRMED=OK
G12_ANDROID_PENDING_MARKER_SURVIVED=OK
G12_ANDROID_G9_RECOVERY_ONLY=OK
G12_ANDROID_MFA_RECOVERY_COMMITTED=OK
G12_ANDROID_CORRUPT_MARKER_DENIED=OK
G12_ANDROID_STORAGE_CLEARED=OK
G12_ANDROID_PHYSICAL_AUTH_RESULT=0
```

## Archivos y compilación

- `clients/flutter/lib/g12_lab_main.dart`: interfaz Android aislada, rechaza release o invocación sin `--dart-define`.
- `clients/flutter/lib/g12_lab/physical_auth_checks.dart`: ensayos con plugin Android y `_SyntheticPort` no conectado a red.
- `clients/flutter/android/app/build.gradle.kts`: `.g12lab` solo en debug; G8 `.g8lab` sin cambios funcionales; flags mutuamente excluyentes, release/profile negados.
- `scripts/g12_phone_apk_build.sh`: N1, `flutter analyze`, `flutter build apk --debug --target=lib/g12_lab_main.dart`, `aapt` comprueba ID de paquete y `sha256sum`.
- `.github/workflows/g12-phone-auth-apk.yml`: workflow de compilación y artifact `VENCIRA-G12-PHONE-DEBUG-ONLY` que contiene el ZIP con `VENCIRA-G12-LAB-debug.apk` y checksum. Retención 7 días.
- `scripts/n1_static_security_gate.py`: guarda `g12_physical_android_offline_auth_isolated` que exige el aislamiento, almacenamiento real, rechazo a HTTP y ausencia en rutas operativas.

El resultado de la compilación debe incluir:

```text
N1_STATIC_g12_physical_android_offline_auth_isolated=OK
N1_STATIC_GATE_RESULT=OK
G12_PHONE_APK_ID_VERIFY=OK
G12_PHONE_PACKAGE=es.vencira.vencira.g12lab
G12_PHONE_APK_BUILD=OK
G12_PHONE_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Pasos para comprobar

1. Comprobar primero workflow G12 en `https://github.com/appvencira/vencira_app/actions/workflows/g12-phone-auth-apk.yml`. Si GitHub Actions termina verde, desde la ejecución → Artifacts → `VENCIRA-G12-PHONE-DEBUG-ONLY` descargar ZIP, extraer APK e instalar en Android. **No usar la APK G8 antigua.**
2. Pulsar `Preparar prueba G12`, verificar los seis marcadores de preparación, forzar detención del proceso y reabrir.
3. Pulsar `Verificar tras reinicio` y compartir solo los marcadores. Ante fallo usar `Limpiar datos G12`, sin tocar app o almacenes de producción.

**Alternativa de compilación local**:

```bash
cd ~/vencira-m3-localcheck
git fetch origin feature/m3-android-local-notifications
git merge --ff-only FETCH_HEAD
# En el mismo contenedor Android SDK de G8:
bash scripts/g12_phone_apk_build.sh
```

## Límites y release

El experimento usa un simulador de servidor en el teléfono y, por diseño, NO valida transporte HTTPS Android ni el emisor real de producción; G11 solo cubre HTTPS bajo Docker. Tampoco demuestra protección contra root, hardware TEE/StrongBox, copia/restauración tras reinstalar o multi-proceso concurrente. El gateway de recuperación no tiene todavía API integral de logout segura, y esa prueba se hace a nivel de diario/vault. No instalar esta entrada en `main.dart` ni habilitar endpoints de Django.

**G12=NO VALIDADO mientras falten compilación/ensayo físico. PR #17 DRAFT. `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.**
