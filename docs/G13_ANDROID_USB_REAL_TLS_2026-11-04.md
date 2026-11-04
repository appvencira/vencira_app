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


## G13 desde un único móvil Android y acceso remoto al VPS — modo Termux SSH (04/11/2026)

**Es posible ejecutar G13 sin PC y sin cable USB.** El móvil no necesita depuración USB, ADB ni conexión física al VPS. El mismo Android sirve para gestionar el VPS (sesión de consola), descargar la APK (SCP/SFTP) y ejecutar G13 usando un túnel SSH local de Termux. No se abre ninguna interfaz pública del fixture.

**Modo incorporado en el ejecutor existente:** bash scripts/g13_android_usb_https_lab.sh --ssh-tunnel. Se reutilizan los mismos Docker --internal, SQLite tmpfs, CA pública efímera y proxy TCP ligado exclusivamente a 127.0.0.1:18743 en el VPS. El modo remoto omite ADB e instalación por USB; guarda la APK en el directorio de trabajo del VPS, anuncia G13_TERMUX_SSH_APK_REMOTE_PATH y conserva el laboratorio activo hasta que se confirme el cierre. El modo sin argumentos sigue siendo el G13 USB original.

Secuencia recomendada:

1. **En el VPS por consola móvil**, descargar la rama y entrar en una sesión tmux interactiva persistente, para que al cambiar de app Android no se apague el laboratorio:
   - cd ~/vencira-m3-localcheck
   - git fetch origin feature/m3-android-local-notifications
   - git merge --ff-only FETCH_HEAD
   - tmux new -s vencira-g13
   - Dentro de tmux: bash scripts/g13_android_usb_https_lab.sh --ssh-tunnel
   - Mantener tmux activo hasta G13_LAB_SESSION_ACTIVE=1; no pulsar Intro en el prompt final. Si hace falta abandonar la vista tmux, separar con Ctrl+B seguido de D; una reconexión puede usar tmux attach -t vencira-g13. Si tmux no está instalado, instalarlo mediante los procedimientos autorizados del VPS, no cerrar la sesión que mantiene el runner.

2. **En el mismo teléfono, Termux** (instalación oficial desde F-Droid/GitHub, sin mezclar fuentes), preparar cliente SSH y carpeta de descargas:
   - pkg update
   - pkg install openssh
   - termux-setup-storage (conceder permiso Android)
   - Abrir una sesión Termux para descargar por SCP, sustituyendo VPS_HOST por la misma IP/DNS y usuario usados en tu conexión SSH habitual:
     scp vencira@VPS_HOST:/home/vencira/vencira-m3-localcheck/clients/flutter/build/g13-phone/VENCIRA-G13-LAB-debug.apk ~/storage/downloads/
   - Instalar la APK desde el administrador de archivos / Descargas en Android, permitiendo la instalación desde esa aplicación cuando Android lo solicite. **No compartir esta APK**, que lleva solo una CA pública de laboratorio y es válida únicamente para el fixture actual.

3. **En Termux, abrir otra sesión, iniciar el túnel:**
   ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -N -L 127.0.0.1:18743:127.0.0.1:18743 vencira@VPS_HOST
   - La autenticación SSH debe ser la normal, con verificación de la clave de host previamente conocida. **Nunca usar StrictHostKeyChecking=no, GatewayPorts ni 0.0.0.0**.
   - El comando permanece abierto sin imprimir salida mientras el túnel esté activo. Permite un wake lock de Termux si Android suspende sesiones en segundo plano; desactivar restricciones de batería para Termux durante el ensayo. Cambiar a la APK G13 sin detener Termux. En caso de desconexión se puede reconectar, pero no reconstruir Django o regenerar certificados.
   - El puerto **escucha únicamente en el bucle local del teléfono**. La sesión SSH cifra el tráfico hasta 127.0.0.1 del VPS; ese proxy reenvía el TLS original a Django interno.

4. **En VENCIRA G13 TLS** ejecutar fase 1, forzar detención únicamente de la APK G13, reabrir y ejecutar fase 2. No forzar detención de Termux. Mantener el mismo servidor temporal y el mismo túnel durante ambas fases. Compartir solo los marcadores de G13 (G13_ANDROID_REAL_HTTPS_RESULT=0 esperado, no demostrado).
5. **Cerrar:** tras completar fase 2, volver a VPS/tmux y pulsar Intro en el runner para ejecutar cleanup del proxy, contenedor y red Docker; después interrumpir la sesión SSH de Termux con Ctrl+C. No configurar puertos entrantes ni reglas del firewall. Una nueva ejecución genera CA nueva y exige reinstalar la nueva APK.

**Limitaciones:** el túnel exige que sshd del VPS permita LocalForward/AllowTcpForwarding y que la conexión SSH del móvil pueda mantenerse viva. Algunas aplicaciones de consola SSH Android no permiten crear un listener 127.0.0.1:18743; Termux con OpenSSH sí. Si un cortafuegos/sshd bloquea el forwarding, G13 no podrá probarse así hasta resolver esa política sin abrir públicamente el fixture. Las pruebas G7–G12 anteriores no necesitan repetirse.

**Estado:** implementación de modo SSH en GitHub, pendiente de ejecutar N1/Flutter/build sobre VPS y de validación física completa. No atribuir G13 PASS antes del recibo del teléfono. PR DRAFT, GLOBAL_FREEZE=NOT_VERIFIED, MB1_RELEASE_AUTHORIZED=NO, MFA_RELEASE_AUTHORIZED=NO, C_FICHA_RELEASE_AUTHORIZED=NO, NO_DEPLOY_NO_LIVE_MIGRATION=1.


## G13 — Primer intento Termius/SSH: el relay local no arrancó (04/11/2026)

Recibo confirmado: N1 completo PASS (incluidos controles G13 USB y SSH), G13_HOST_RELAY_PYTHON_SYNTAX=OK, G13_MODE=TERMUX_SSH_LOCAL_FORWARD, Docker build completo, G13_DJANGO_TMPFS_READY=OK, G13_DOCKER_PRIVATE_PEER=OK y G13_PUBLIC_EPHEMERAL_CA=OK. Se interrumpió en G13_HOST_RELAY_NOT_READY; el cleanup devolvió G13_USB_LAB_CLEANUP=OK, G13_USB_HOST_RUNNER_RESULT=1 y NO_DEPLOY_NO_LIVE_MIGRATION=1. No hubo compilación Flutter G13 ni prueba HTTPS en teléfono todavía.

La causa EXACTA no quedó registrada porque el log temporal del relay se eliminaba durante la limpieza. Posibles causas: puerto local 18743 ocupado, estado TIME_WAIT posterior a listener cerrado o error del propio proceso. **No atribuir causa concreta hasta ver el nuevo código de diagnóstico.**

Correcciones implementadas:
- scripts/g13_usb_loopback_relay.py: allow_reuse_address=True permite el rebinding tras TIME_WAIT, pero no desplaza un listener activo; los errores de bind se clasifican mediante códigos G13_HOST_RELAY_STARTUP_ERROR sin imprimir excepciones, credenciales ni cuerpos.
- scripts/g13_android_usb_https_lab.sh: sondeo inicial del puerto **solo** 127.0.0.1:18743 antes de levantar Docker (G13_HOST_PORT_PREFLIGHT=OK o G13_HOST_PORT_PREFLIGHT_ERROR=LOOPBACK_PORT_OCCUPIED); si el relay no llega a READY, imprime un código de fallo saneado antes de eliminar el log. No termina procesos ajenos.
- scripts/test_g13_usb_loopback_relay.py: tres pruebas stdlib con puertos efímeros para verificar peer privado, rechazo de apropiación de un listener activo, y paso de bytes sintéticos entre dos sockets de loopback. Se añade antes de Docker en el runner y en CI; marcador objetivo G13_HOST_RELAY_SMOKE=OK.

**G13 sigue PENDING**; ejecutar de nuevo bash scripts/g13_android_usb_https_lab.sh --ssh-tunnel después de actualizar la rama. Si se confirma puerto ocupado, diagnosticar dueño con ss -ltnp '( sport = :18743 )' y evitar detener servicios ajenos o abrir firewall. En caso de error nuevo, compartir los códigos G13_HOST_PORT_PREFLIGHT / G13_HOST_RELAY_STARTUP_ERROR, no archivos de secretos. PR #17 DRAFT; GLOBAL_FREEZE=NOT_VERIFIED, MB1_RELEASE_AUTHORIZED=NO, MFA_RELEASE_AUTHORIZED=NO, C_FICHA_RELEASE_AUTHORIZED=NO, NO_DEPLOY_NO_LIVE_MIGRATION=1.
