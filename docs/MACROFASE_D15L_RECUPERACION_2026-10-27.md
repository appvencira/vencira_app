# D1.5l — Confirmación de recepción de códigos (gate pendiente)

Implementación backend en rama de integración. El alta MFA se conserva **deshabilitada por defecto** por `VENCIRA_MFA_ENROLLMENT_ENABLED=0`.

Tras confirmar TOTP, el servidor entrega exactamente una vez los diez códigos en el cuerpo de esa respuesta; almacena únicamente hashes en PostgreSQL y un marcador de entrega pendiente en la sesión. Se incorpora `POST /api/v1/me/mfa/recovery/ack/` que exige sesión autenticada, feature flag activa y `{"saved":true}`. Consume el marcador una sola vez, sin repetir códigos ni exponer secretos. Test de rechazo `saved:false`, aceptación, repetición 409 y ausencia de material sensible en ACK. **No almacena el texto de los códigos en sesión ni registro alguno.**

**Advertencia de diseño pendiente:** el factor MFA ya se activa durante confirmación TOTP y ANTES del ACK. Si se pierde la respuesta con códigos o el usuario cierra el navegador, no existe reenvío ni restauración automática: los códigos no se pueden visualizar de nuevo. El ACK demuestra solo declaración del usuario, no garantiza custodia real. No habilitar el alta pública hasta definir un proceso resiliente a pérdida de entrega, UI Flutter premium ES/CA con captura y confirmación explícita, límite de intentos de contraseña, rotación/custodia de Fernet y recuperación administrativa segura. Evitar que se muestren códigos en logs o errores.

**Gate integral O7/O8 pendiente**; sin despliegue ni migraciones 0019–0021 persistentes.


## Gate D1.5l APROBADO (27/10/2026)

Operador confirmó `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5L=0`. Log `/tmp/vencira-o7-o8-preflight.zaAGqLYm.log`. Sin despliegue ni migración persistente; alta MFA continúa apagada. **Pendiente imprescindible:** entrega resiliente de códigos ante pérdida de respuesta, flujo Flutter completo y custodia/restitución de claves antes de habilitar el alta.
