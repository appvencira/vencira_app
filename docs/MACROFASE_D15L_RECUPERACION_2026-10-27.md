# D1.5l — Confirmación de recepción de códigos (gate pendiente)

Implementación backend en rama de integración. El alta MFA se conserva **deshabilitada por defecto** por `VENCIRA_MFA_ENROLLMENT_ENABLED=0`.

Tras confirmar TOTP, el servidor entrega exactamente una vez los diez códigos en el cuerpo de esa respuesta; almacena únicamente hashes en PostgreSQL y un marcador de entrega pendiente en la sesión. Se incorpora `POST /api/v1/me/mfa/recovery/ack/` que exige sesión autenticada, feature flag activa y `{"saved":true}`. Consume el marcador una sola vez, sin repetir códigos ni exponer secretos. Test de rechazo `saved:false`, aceptación, repetición 409 y ausencia de material sensible en ACK. **No almacena el texto de los códigos en sesión ni registro alguno.**

**Advertencia de diseño pendiente:** el factor MFA ya se activa durante confirmación TOTP y ANTES del ACK. Si se pierde la respuesta con códigos o el usuario cierra el navegador, no existe reenvío ni restauración automática: los códigos no se pueden visualizar de nuevo. El ACK demuestra solo declaración del usuario, no garantiza custodia real. No habilitar el alta pública hasta definir un proceso resiliente a pérdida de entrega, UI Flutter premium ES/CA con captura y confirmación explícita, límite de intentos de contraseña, rotación/custodia de Fernet y recuperación administrativa segura. Evitar que se muestren códigos en logs o errores.

**Gate integral O7/O8 pendiente**; sin despliegue ni migraciones 0019–0021 persistentes.
