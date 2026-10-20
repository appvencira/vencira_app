# Estado del proyecto VENCIRA — 20/10/2026

Bootstrap de código y primeras integraciones, todavía en **PR borrador**, sin despliegue ni datos reales.

- Nombre VENCIRA y repositorio privado exclusivo `appvencira/vencira_app` confirmados.
- Dominio `vencira.es`: pedido OVHcloud del 20/10/2026 por 7,25 € con IVA; justificante en estado «Validando...», pendiente de activación final.
- Correo previsto `soporte@vencira.es`, aún no configurado.
- Backend: modelos mínimos, pruebas y health/readiness; API v1 de vencimientos limitada por pertenencia a organización, con sesiones web y CSRF.
- Tests backend SQLite y PostgreSQL 17: superados en la ejecución anterior.
- Flutter: interfaz de consulta de organizaciones y vencimientos mediante API; lista paginada, estados de sesión, cambio de organización y pruebas de contrato/widget. **Proxy de mismo origen añadido para pruebas locales con Nginx; la prueba HTTP autenticada E2E está en CI y las pruebas visuales reales de navegador continúan pendientes**.
- Motor de avisos, alta/edición web, MFA, limitación de login, RGPD, copias externas y producción: pendientes.
- No comprar VPS hasta necesitar pruebas externas o despliegue real.

Documentación: `docs/API_MVP.md`, `docs/WEB_LOCAL.md` y `clients/flutter/README.md`. CI de compilación web e integración same-origin: pendiente de verificación.
