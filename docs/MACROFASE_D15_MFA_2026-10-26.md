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
