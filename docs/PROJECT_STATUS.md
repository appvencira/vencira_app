# Estado del proyecto VENCIRA — 20/10/2026

Bootstrap de código y primeras integraciones, todavía en **PR borrador**, sin despliegue ni datos reales.

- Nombre VENCIRA y repositorio privado exclusivo `appvencira/vencira_app` confirmados.
- Dominio `vencira.es`: pedido OVHcloud del 20/10/2026 por 7,25 € con IVA; justificante en estado «Validando...», pendiente de activación final.
- Correo previsto `soporte@vencira.es`, aún no configurado.
- Backend: modelos mínimos, pruebas y health/readiness; API v1 de vencimientos limitada por pertenencia a organización, con sesiones web y CSRF.
- Tests backend SQLite y PostgreSQL 17: superados en la ejecución anterior.
- Flutter: interfaz de consulta de organizaciones y vencimientos mediante API; lista paginada, estados de sesión, cambio de organización y pruebas de contrato/widget. **Proxy de mismo origen añadido para pruebas locales con Nginx; la prueba HTTP autenticada E2E está en CI y las pruebas visuales reales de navegador continúan pendientes**.
- Envío de avisos, alta/edición web, MFA, límites adicionales por IP y seguridad de login Admin, RGPD, copias externas y producción: pendientes.
- No comprar VPS hasta necesitar pruebas externas o despliegue real.

Documentación: `docs/API_MVP.md`, `docs/WEB_LOCAL.md` y `clients/flutter/README.md`. CI anterior de compilación web e integración same-origin: superada. CI del refuerzo de login y candidatos internos: superada (27 tests en SQLite y PostgreSQL, además de Flutter y web).

- Login provisional: límite por cuenta HMAC persistido en BD, 5 fallos/15 minutos -> bloqueo 15 minutos. Sin MFA ni protección frente a abuso distribuido.

- Base de avisos: reglas inactivas por defecto, candidatos futuros deduplicados y conciliación manual por organización. **Nunca envía mensajes**.

- Auditoría API v1: eventos de creación y cambios de vencimientos registrados en la misma transacción, sin conservar valores de referencias de clientes. Cobertura limitada a API v1, sin salida pública. Ver `docs/AUDIT.md`.
- Reglas comerciales: opciones y dudas documentadas en `docs/REMINDER_RULES_DRAFT.md`; sin aprobación de parámetros comerciales ni entregas reales.
- CI del nuevo registro de auditoría: pendiente de comprobar.
