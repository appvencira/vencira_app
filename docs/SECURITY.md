# Seguridad — requisitos y límites

**Prohibido introducir datos personales reales o desplegar en producción en esta fase.**

Actualmente: repositorio privado, `.env` fuera de Git, secretos aleatorios por instalación, PostgreSQL sin puerto público, API Docker vinculada solo a 127.0.0.1, DEBUG=0 en contenedor. Los endpoints de negocio v1 ahora están disponibles **solo para sesiones autenticadas con membresía**; no deben exponerse fuera de loopback.

## Antes de producción

1. El login web ahora utiliza un contador por identificador anonimizado con HMAC, compartido mediante PostgreSQL; 5 fallos en 15 minutos bloquean nuevas peticiones 15 minutos (HTTP 429). **Esto es provisional y susceptible a bloqueo malicioso de cuentas:** siguen pendientes MFA, recuperación, rate-limiting IP en el proxy, limpieza del registro y protección del Django Admin, que no pasa por esta pantalla.
2. Revisar independientemente el aislamiento por organización implementado y probado en lecturas y escrituras, así como permisos diferenciados por rol.
3. TLS y proxy seguro, cabeceras, logs sanitizados, protección contra ataques.
4. Copias externas cifradas, restauración ensayada, RPO/RTO y políticas de retención.
5. Seguridad de dependencias, imágenes fijadas, actualización y monitorización.
6. Base jurídica RGPD, finalidades, DPA, roles responsables/encargados, derechos y procesos de borrado.
7. Motor de avisos fiable, idempotente, con límites y baja de destinatarios.
8. Endurecer /admin/ y el acceso a endpoints técnicos.

No mezclar código, datos ni credenciales de otras cuentas de GitHub.

## Previsión de avisos

Las reglas se crean desactivadas y los candidatos se preparan manualmente sin canal de salida, destinatarios ni integración externa. Hay aislamiento por organización en el servicio y clave única de deduplicación. No se han activado avisos reales. Ver `docs/REMINDER_ENGINE.md`.

## Auditoría mínima de operaciones API

POST/PATCH en la API v1 de vencimientos genera eventos internos transaccionales y con tenant obligatorio. No se almacenan los valores de referencia de cliente en el evento. **No es un registro inmutable y no cubre escrituras fuera de la API**. Antes de producción hacen falta trazabilidad de administradores, garantías de retención y políticas de acceso a logs. Ver `docs/AUDIT.md`.
