# D1.5k — Alta MFA desde API protegida (GATE PENDIENTE)

Se añade `backend/reminders/mfa_enrollment_api.py` y rutas `/api/v1/me/mfa/setup/start/` y `/api/v1/me/mfa/setup/confirm/`. **Feature flag `VENCIRA_MFA_ENROLLMENT_ENABLED=0` por defecto, no habilitar en DEV.**

Comportamiento propuesto: usuario con sesión autenticada confirma contraseña actual; se valida disponibilidad del anillo externo `VENCIRA_MFA_FERNET_KEYS`, se prepara un secreto TOTP cifrado sin activación y se devuelve URI otpauth con secreto al titular para QR manual futuro. Confirmación TOTP en 10 min, limitada por intentos y sesión, activa MFA, genera 10 códigos de recuperación mostrados solo en respuesta. Se marca sesión actual como verificada para no bloquear al usuario y el middleware bloquea otras sesiones sin segundo factor. Respuestas no-store. Tests: `backend/reminders/test_mfa_enrollment_api.py`.

**Bloqueantes pendientes para habilitar feature flag:** diseño confirmado de entrega y aceptación de guardado de códigos para evitar bloqueo por corte de conexión en primera respuesta, UI premium en configuración Flutter con QR y clave manual (sin guardar secreto en logs), pruebas de CSRF navegador, protección específica contra intentos repetidos de contraseña de reautenticación, recuperación al perder todos los factores, inventario de endpoints administrativos, custodia/rotación externa probada con restauración. El flujo no incluye aún ACK de recepción de códigos y por ello NO ESTÁ LISTO para habilitación. Sin migraciones persistentes 0019–0021, sin despliegues.

Gate O7/O8 integral requerido antes de seguir; nunca poner claves reales en chats, consola copiada o repositorio.
