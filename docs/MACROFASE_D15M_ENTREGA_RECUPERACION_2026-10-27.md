# D1.5m — Entrega recuperable sin bloqueo por respuesta perdida

Estado: implementación backend **PENDIENTE DE GATE INTEGRAL**. Feature flag `VENCIRA_MFA_ENROLLMENT_ENABLED=0`. Sin despliegue ni migraciones PostgreSQL persistentes.

## Corrección de riesgo crítico

Antes, el TOTP de enrolamiento activaba MFA inmediatamente antes de que el cliente recibiera códigos de recuperación. Si se perdía la respuesta, podía quedar la cuenta bloqueada sin códigos. Ahora:
1. `setup/start`: contraseña actual, secreto cifrado, MFA inactivo.
2. `setup/confirm`: valida TOTP, crea 10 hashes de códigos provisionales en PostgreSQL, devuelve códigos legibles una sola vez. **MFA permanece inactivo**.
3. `recovery/ack`: requiere declaración de guardado **y demostrar posesión de uno de los códigos entregados**. Activa MFA en transacción; marca sesión actual verificada. Otros dispositivos previos quedan restringidos por middleware.

Si falla la entrega de códigos, el usuario puede iniciar de nuevo la preparación (contraseña obligatoria); esta borra los hashes provisionales anteriores y rota el secreto. Los códigos NO se guardan en claro ni en sesiones; los valores solo se incluyen en la única respuesta de confirmación. No se pueden recuperar otra vez. La segunda confirmación no regenera códigos mientras existe lote provisional.

Archivos: `backend/reminders/mfa_enrollment.py`, `backend/reminders/mfa_enrollment_api.py`, `backend/reminders/test_mfa_enrollment.py`, `backend/reminders/test_mfa_enrollment_api.py`.

## Bloqueos para salida

Pendiente gate SQLite, PG17 temporal, Flutter. La interfaz Flutter ES/CA con QR y descarga controlada NO está integrada todavía; tampoco protección específica anti fuerza bruta de contraseña de setup, custodia real de claves, recuperación sin factores y pruebas manuales. La prueba de posesión de un solo código NO equivale a garantía absoluta de que el usuario ha guardado todos. Mantener alta deshabilitada hasta completar estos requisitos.
