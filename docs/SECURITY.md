# Seguridad — requisitos y límites

**Prohibido introducir datos personales reales o desplegar en producción en esta fase.**

Actualmente: repositorio privado, `.env` fuera de Git, secretos aleatorios por instalación, PostgreSQL sin puerto público, API Docker vinculada solo a 127.0.0.1, DEBUG=0 en contenedor, endpoints de negocio no publicados.

## Antes de producción

1. MFA, recuperación de cuentas, bloqueo por abuso y control de sesiones.
2. Aislamiento por organización probado en lecturas y escrituras.
3. TLS y proxy seguro, cabeceras, logs sanitizados, protección contra ataques.
4. Copias externas cifradas, restauración ensayada, RPO/RTO y políticas de retención.
5. Seguridad de dependencias, imágenes fijadas, actualización y monitorización.
6. Base jurídica RGPD, finalidades, DPA, roles responsables/encargados, derechos y procesos de borrado.
7. Motor de avisos fiable, idempotente, con límites y baja de destinatarios.
8. Endurecer /admin/ y el acceso a endpoints técnicos.

No mezclar código, datos ni credenciales de otras cuentas de GitHub.
