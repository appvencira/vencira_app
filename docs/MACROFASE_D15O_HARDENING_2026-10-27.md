# D1.5o — Protección de reautenticación MFA (GATE PENDIENTE)

En rama `integration/local-e2e-prep` se reutiliza el bucket persistente de `backend/reminders/login_security.py` para bloquear la reautenticación de `POST /api/v1/me/mfa/setup/start/` tras cinco contraseñas erróneas en 15 minutos, con bloqueo de 15 minutos y HTTP 429/`Retry-After`. Un acierto dentro de la ventana válida restablece el contador; nunca se devuelve contraseña ni dato sensible. Se añadió prueba de intentos repetidos y rechazo de la contraseña correcta durante el bloqueo: `backend/reminders/test_mfa_enrollment_api.py`. Backend y UI de enrolamiento siguen apagados por defecto.

**QR aún pendiente.** La configuración TOTP manual está implementada en Flutter, pero incluir QR requiere evaluar dependencia compatible y asegurar que el otpauth URI nunca se envía a servicios de terceros, no se registra y se limpia al terminar. No añadir servicio remoto de QR.

Pendientes: límites de abuso por IP/proxy, restauración real de claves, recuperación sin factores, pruebas visuales móvil ES/CA y plan de despliegue con rollback fail-closed. No habilitar flags, desplegar ni ejecutar migraciones 0019–0021 persistentes.

Gate O7/O8 aislado requerido para validar estos cambios.


## Gate D1.5o — APROBADO (27/10/2026)

El operador confirma: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5O=0`. Log local `/tmp/vencira-o7-o8-preflight.nnMcgvpe.log`. Validado bloqueo compartido de reautenticación de alta MFA; ningún despliegue ni migración persistente. QR todavía pendiente, custodia real de claves y recuperación sin todos los factores pendientes; no habilitar MFA.
