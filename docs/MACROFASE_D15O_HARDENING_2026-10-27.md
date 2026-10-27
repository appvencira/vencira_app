# D1.5o — Protección de reautenticación MFA (GATE PENDIENTE)

En rama `integration/local-e2e-prep` se reutiliza el bucket persistente de `backend/reminders/login_security.py` para bloquear la reautenticación de `POST /api/v1/me/mfa/setup/start/` tras cinco contraseñas erróneas en 15 minutos, con bloqueo de 15 minutos y HTTP 429/`Retry-After`. Un acierto dentro de la ventana válida restablece el contador; nunca se devuelve contraseña ni dato sensible. Se añadió prueba de intentos repetidos y rechazo de la contraseña correcta durante el bloqueo: `backend/reminders/test_mfa_enrollment_api.py`. Backend y UI de enrolamiento siguen apagados por defecto.

**QR aún pendiente.** La configuración TOTP manual está implementada en Flutter, pero incluir QR requiere evaluar dependencia compatible y asegurar que el otpauth URI nunca se envía a servicios de terceros, no se registra y se limpia al terminar. No añadir servicio remoto de QR.

Pendientes: límites de abuso por IP/proxy, restauración real de claves, recuperación sin factores, pruebas visuales móvil ES/CA y plan de despliegue con rollback fail-closed. No habilitar flags, desplegar ni ejecutar migraciones 0019–0021 persistentes.

Gate O7/O8 aislado requerido para validar estos cambios.
