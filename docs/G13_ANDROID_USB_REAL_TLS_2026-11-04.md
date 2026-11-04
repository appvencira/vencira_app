# G13 — Android físico → HTTPS verificado → Django temporal (USB)

**04/11/2026. Estado: código implementado, análisis y prueba física PENDIENTES.** No equivale a release.

## Objetivo y situación

G7/G11 prueban HTTPS real en Django temporal; G8/G12 prueban almacenamiento seguro Android en teléfono físico; G9/G10 comprueban arranque, primera emisión y cierre con pruebas unitarias. G13 une las tres dimensiones en una sesión real de Android por USB, manteniendo el backend de laboratorio completamente aislado. No reutiliza contraseñas de usuarios ni la autenticación operativa de VENCIRA.

## Arquitectura y controles

- APK Android DEBUG independiente: paquete es.vencira.vencira.g13lab, almacenamiento protegido en namespace vencira_g13_phone_tls_v1. Gradle impide G8/G12/G13 simultáneos y release/profile en laboratorios.
- Django G7-D2 fixture: Docker --internal, base SQLite en tmpfs, contenedor --read-only, sin puertos del host publicados y sin migraciones persistentes. Solo se ejecuta en VENCIRA_ENV=test.
- CA y certificado TLS generados por cada ensayo. La clave privada permanece dentro del contenedor efímero. El PC exporta únicamente la CA pública al proceso de compilación de una APK específica para ese ensayo.
- Tránsito exclusivo: Android 127.0.0.1:18743 → ADB reverse USB → PC 127.0.0.1:18743 → proxy TCP sin lectura de mensajes → IP Docker privada:8443. El proxy no escucha en otras interfaces.
- La APK usa HttpClient.connectionFactory para prohibir destinos distintos de HTTPS dev.vencira.es:443, pero hace TCP solo hacia Android loopback. Verifica la identidad dev.vencira.es mediante SecureSocket.secure, CA temporal explícita y SecurityContext sin raíces predeterminadas. No hay badCertificateCallback ni conexiones a DNS/IP pública. También debe rechazar una CA desconocida.
- El script del PC comprueba la conexión TLS y el HTTP 401 sin credenciales antes de instalar. Exige un solo teléfono físico autorizado por ADB, sin emulador; al salir elimina ADB reverse, relay y red/servidor Docker.
- El teléfono usa las clases NativeMobileStartupGate, NativeFirstIssuanceEntry, NativeSessionCoordinator, NativeHttpAuthPort, NativeMobileRecoveryEntry, NativeRecoveryLoginGateway, NativeRefreshCredentialVault y NativeRefreshRecoveryJournal. No modifica main.dart, URLs de Django operativo o autenticación por defecto.

## Escenarios físicos — fase 1

Desde la APK, tocar **Iniciar G13: fase 1**. Se verifican TLS con CA efímera, denegación de CA no confiable, primera emisión real contra Django después del marcador duradero, aceptación de bearer 200, cierre con revocación en Django y bearer antiguo 401, fallo sintético de transporte previo a revocar y reintento seguro que revoca realmente, contraseña+MFA TOTP público RFC y revocación, y pérdida de respuesta DESPUÉS de emisión real para dejar marcador protegido y ningún acceso activo. Solo un PID no secreto queda en SharedPreferences.

Marcadores previstos al terminar fase 1: G13_ANDROID_TLS_CERT_VERIFIED=OK, G13_ANDROID_UNTRUSTED_CA_DENIED=OK, G13_ANDROID_REAL_FIRST_ISSUE=OK, G13_ANDROID_DJANGO_LOGOUT_REVOKED=OK, G13_ANDROID_REVOKE_FAULT_FENCED=OK, G13_ANDROID_REVOKE_RETRY_CONFIRMED=OK, G13_ANDROID_MFA_TLS_COMMITTED=OK, G13_ANDROID_UNKNOWN_ISSUANCE_FENCED=OK, G13_ANDROID_FORCE_STOP_REQUIRED=1.

## Escenarios físicos — fase 2

Sin cerrar la terminal Ubuntu ni desconectar USB, desde Ajustes Android **Forzar detención** de VENCIRA G13 TLS. Abrir nuevamente y tocar **Verificar fase 2**. Exige un PID diferente; G9 lee el marcador persistente e impide login normal. G6 recupera con contraseña nueva a Django temporal (usuario sintético sin MFA), reemplaza credencial en almacén Android y borra el checkpoint antes de habilitar acceso. El servidor acepta bearer 200. Luego, mediante las primitivas seguras del diario (no hay todavía logout integrado del gateway de recuperación), revoca en Django, verifica 401 y limpia credencial/marcador. Un marcador corrupto se rechaza, se limpia solo el namespace G13 y el PID.

El resultado esperado, aún **NO CONFIRMADO**, es G13_ANDROID_NEW_PROCESS=OK, G13_ANDROID_TLS_CONNECTION_AFTER_RESTART=OK, G13_ANDROID_DURABLE_MARKER_SURVIVED=OK, G13_ANDROID_G9_RECOVERY_REQUIRED=OK, G13_ANDROID_SERVER_RECOVERY_COMMITTED=OK, G13_ANDROID_RECOVERED_SESSION_REVOKED=OK, G13_ANDROID_CORRUPT_MARKER_BLOCKED=OK, G13_ANDROID_STORAGE_CLEANED=OK y G13_ANDROID_REAL_HTTPS_RESULT=0.

## Ejecutar una sola vez desde Ubuntu con USB

1. Conectar un único Android físico autorizado en Depuración USB. Instalar adb en Ubuntu si falta, tener sudo docker y acceso al contenedor Flutter con Android SDK.
2. Actualizar la rama: cd ~/vencira-m3-localcheck ; git fetch origin feature/m3-android-local-notifications ; git merge --ff-only FETCH_HEAD.
3. Iniciar: bash scripts/g13_android_usb_https_lab.sh.
4. Mantener abierta la terminal cuando aparezca G13_LAB_SESSION_ACTIVE=1. El script compila e instala automáticamente la APK G13 con la CA pública de esa ejecución. Abrir la app en el teléfono y completar ambas fases.
5. Tras recibir el resultado final, pulsar INTRO en la terminal para detener el laboratorio y eliminar su túnel. Compartir exclusivamente marcadores G13, sin capturas de secretos.

Marcadores de preparación esperados: G13_DJANGO_TMPFS_READY=OK, G13_DOCKER_PRIVATE_PEER=OK, G13_PUBLIC_EPHEMERAL_CA=OK, G13_HOST_RELAY_BOUND_LOOPBACK=OK, G13_HOST_VERIFIED_TLS_AND_UNAUTH_401=OK, G13_USB_ADB_REVERSE=OK, G13_ANDROID_APK_BUILD=OK, G13_ANDROID_DEBUG_APK_INSTALLED=OK, G13_LAB_SESSION_ACTIVE=1.

## Entregables

- clients/flutter/lib/g13_lab_main.dart
- clients/flutter/lib/g13_lab/physical_https_checks.dart
- scripts/g13_usb_loopback_relay.py
- scripts/g13_android_usb_https_lab.sh
- scripts/g13_phone_apk_build.sh
- .github/workflows/g13-android-https-source.yml (solo guardias y análisis de código; NO realiza prueba Android)
- scripts/n1_static_security_gate.py, control g13_android_real_tls_usb_only
- clients/flutter/android/app/build.gradle.kts, paquete debug aislado.

## Límites y autorización

**No está probado todavía:** compilación G13, Android → USB → TLS → Django físico ni marcadores de la APK. No se ha realizado despliegue o migración. La APK embebe exclusivamente una CA PÚBLICA temporal, y una APK de sesión anterior no es válida para otro certificado de laboratorio.

G13 tampoco prueba el login móvil operativo, MFA real con datos privados, recuperación MFA tras el segundo arranque (usa identidad sintética sin MFA en esa fase), logout integrado en recovery UI, hardware StrongBox/TEE, resistencia a root, backup/restore o varios procesos concurrentes.

**PR #17 permanece DRAFT. GLOBAL_FREEZE=NOT_VERIFIED, MB1_RELEASE_AUTHORIZED=NO, MFA_RELEASE_AUTHORIZED=NO, C_FICHA_RELEASE_AUTHORIZED=NO, NO_DEPLOY_NO_LIVE_MIGRATION=1.**
