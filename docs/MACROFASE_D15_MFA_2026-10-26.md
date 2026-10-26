# VENCIRA — D1.5 · MFA TOTP y recuperación segura

Estado: D1.5a implementada en rama de integración, **gate pendiente**. NO desplegada ni activada.

## D1.5a — Núcleo aislado

- `backend/reminders/mfa_totp.py`: generador CSPRNG de secretos Base32 de 160 bits; TOTP RFC 6238 SHA1, 30 s, 6 dígitos; comparación temporal constante; tolerancia configurable como máximo ±1 ventana; devuelve contador candidato para impedir replay en una transacción posterior; URI `otpauth` compatible con autenticadoras.
- `backend/reminders/test_mfa_totp.py`: vectores públicos RFC 6238 SHA1 con 8 dígitos, generación, ventana, repetición, formatos inválidos y URI.
- Sin nuevas dependencias, modelos, migraciones, endpoints ni alteración de login. **No es un sistema MFA completo**.

## D1.5b — Antes de exponer la activación

1. Persistir secreto TOTP **cifrado con clave independiente, rotación documentada** (no hash irreversible; se necesita para verificar el OTP). Secretos de producción nunca en logs, URL HTTP ni backups sin cifrar. Evaluar librería auditada y dependencias.
2. Flujo seguro de enrolamiento: sesión reciente/contraseña confirmada, pendiente sin activar, QR/clave mostrada exclusivamente al titular, confirmación con código válido, marcar MFA activo atómicamente. Proteger contra CSRF e intentos repetidos.
3. Recuperación: códigos aleatorios suficientes, mostrar una sola vez, almacenar solo hash robusto con comparación segura, consumo atómico/idempotencia controlada, rotación y alertas. Procedimiento verificado si se pierden teléfono y códigos.
4. Login: nunca crear sesión completamente autenticada tras solo contraseña si el usuario tiene MFA activo. Estado de reto preautenticado, expiración, throttling, protección contra fijación de sesión y regresión de login sin MFA.
5. Anti-replay: persistir `last_accepted_counter` por usuario con transacción y `select_for_update`; no aceptar mismo contador ni repetir token dentro de ventana.
6. Revocación/reset MFA con prueba fuerte de identidad, cierre de sesiones pertinente, historial de seguridad minimizado sin PII.
7. ES/CA, accesibilidad, móvil, backups/restauración y continuidad. No convertir VENCIRA en CRM.

## Gates

- Ejecutar tests aislados SQLite y PG17, incluyendo carreras de consumo y anti-replay.
- Ninguna migración de PostgreSQL persistente ni habilitación MFA sin autorización específica.
- No declarar sistema listo para datos reales hasta verificar privacidad y revisión de seguridad integral.


## 26/10/2026 — Gate D1.5a superado

Confirmado por el operador: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5A=0`. Log `/tmp/vencira-o7-o8-preflight.5c3aWGs3.log`. Sin migración o despliegue. D1.5b pendiente: diseño y pruebas de cifrado de secretos y recuperación antes de cualquier enrolamiento.


## D1.5b, primera entrega — cifrado y recuperación (PENDIENTE GATE)

Se añadió dependencia `cryptography>=44,<47` a `backend/requirements.txt`; módulo `backend/reminders/mfa_secrets.py` cifra secretos TOTP con Fernet y clave independiente proporcionada explícitamente, enlace del valor a `user_id`, claves antiguas sólo para descifrado, rotación recifrando con nueva clave; genera 10 códigos de recuperación de 160 bits cada uno y utiliza PBKDF2-SHA256 de Django para almacenar únicamente hashes. Pruebas `backend/reminders/test_mfa_secrets.py`: secreto no expuesto, alteración, vinculación a cuenta, rotación, claves erróneas, generación y comprobación de códigos. Commits `a8fc40c4`, `2b4fa620`, `32038191`. **No habilitado; faltan** modelo de persistencia y transacciones anti-replay/consumo único, control de concurrencia, mecanismo de custodia y rotación real de claves, protección frente a brute force, enrolamiento y login MFA. El helper de recuperación **no consume** códigos: nunca afirmar que es un sistema de recuperación de un solo uso completo antes de implementar persistencia transaccional. Gate integral aislado pendiente, sin migraciones ni despliegue DEV.


## 26/10/2026 — Gate D1.5b APROBADO

El operador confirmó `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5B=0`, log local `/tmp/vencira-o7-o8-preflight.4UXX7YJr.log`. Valida las primitivas cifrado/rotación/códigos sin persistencia. Pendiente consumo atómico con bloqueo transaccional, límites de intentos, enrolamiento y recuperación. Sin deploy, migración persistente ni habilitación MFA.


## D1.5c — Persistencia aditiva y consumo, PENDIENTE DE GATE

Se añadieron `UserMfaState` (OneToOne usuario, secreto cifrado, `enabled=False`, contador anti-replay) y `UserMfaRecoveryCode` (hashes) al modelo, migración aditiva **0019_user_mfa_state** y `mfa_store.py` para consumo transaccional de TOTP y recuperación con `select_for_update()`; tests sintéticos `test_mfa_store.py`. Commits de modelo `4eb0130d`, migración `457693ed`, operaciones `ec5614f0`, tests `a56d32ff`. Ningún endpoint invoca estos consumos, ni se activa MFA. **Falta ejecutar gate integral y comprobar migrations check --dry-run y PG17 temporal.** También faltan tests concurrentes PG17 y limitación de intentos para consumo de recuperación antes de habilitar endpoints. No aplicar la migración a la BD persistente ni usar scripts de despliegue C2 anteriores.


## D1.5c — Gate integral APROBADO (26/10/2026)

Confirmación operador: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5C=0`. Log local `/tmp/vencira-o7-o8-preflight.htuRUzm2.log`. La migración 0019 fue probada en entornos efímeros, **no aplicada en PostgreSQL persistente (0018)**. Pendientes obligatorios: concurrencia real de códigos sobre PG17, límite de intentos, enrolamiento MFA con confirmación y recuperación verificada; aún sin endpoints MFA ni activación.


## D1.5d — Limitación compartida y carrera PG17; gate PENDIENTE

Se introdujeron campos de intentos y bloqueo de cuenta en `UserMfaState` y migración aditiva **0020_mfa_attempt_limits** (`62ba2764`, `04ba395f`). En `mfa_store.py` (`6a7f1152`), verificación TOTP y recuperación comparten contador máximo de 5 fallos en 15 minutos y bloqueo durante 15 minutos; serialización mediante bloqueo de `UserMfaState` en transacción, reseteo tras éxito; códigos no consumidos si la cuenta está bloqueada. Prueba de bloqueo mixto (`8442783c`). Test PostgreSQL con dos conexiones y barrera para demostrar que sólo una petición simultánea puede consumir el código (`d2c2689d`); SQLite lo omite expresamente. **NO gate todavía.** MFA no conectado al login ni a endpoints. Esquema persistente permanece en 0018 y no se desplegarán migraciones 0019/0020 sin gate y aprobación posteriores. Antes de lanzar comercialmente: revisar coste del hash PBKDF2 en intentos inválidos, posibles DoS de lockout, latencia de bloqueo de fila, métricas y alertas; probar el flujo integral de recuperación.


## D1.5d — Gate integral APROBADO (26/10/2026)

Confirmado por el operador: `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5D=0`. Log `/tmp/vencira-o7-o8-preflight.L17WSQrM.log`. La suite incluye prueba de carrera con dos conexiones PostgreSQL temporal y bloqueo de intentos mixtos. Las migraciones aditivas 0019 y 0020 se validaron en pruebas, pero no están aplicadas en la BD persistente (0018). Pendiente enrolamiento confirmable, recuperación completa y segundo factor en login, sin habilitación automática.


## D1.5e — Enrolamiento interno, gate PENDIENTE

Servicio interno en `backend/reminders/mfa_enrollment.py`: preparación crea secreto cifrado con `enabled=False` y URI `otpauth` para el titular; confirmación con TOTP en ventana de 10 minutos fijada en `prepared_at` (nuevo campo aditivo de migración **0021_mfa_prepared_at**) genera 10 códigos de recuperación hasheados y marca `enabled=True` en una transacción; verificación fallida no habilita MFA y sigue límite de intentos. Tests `backend/reminders/test_mfa_enrollment.py` con preparación, confirmación, expiración e invalidación de secreto anterior. Commits `d317d316`, `cd2021a3`, `a833f7e`, `84b9c81`, `e6400bd`.

**CRÍTICO:** servicio interno NO conectado con HTTP/Flutter/login. No invocar `confirm_mfa` ni permitir habilitar `enabled=True` en despliegue alguno hasta que D1.5f garantice segundo factor antes de crear sesión completa; no hay custodia de claves MFA real ni procedimiento de recuperación completo. Claves suministradas en pruebas exclusivamente. 0019/0020/0021 **no aplicar en PostgreSQL persistente**. Pendiente gate aislado completo.
