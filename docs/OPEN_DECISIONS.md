# Decisiones y próximos hitos

## Confirmado
- Nombre del producto: VENCIRA.
- GitHub: únicamente `appvencira/vencira_app`, privado.
- Dominio elegido: `vencira.es`, pedido OVHcloud pendiente de activación.
- Arquitectura inicial: Flutter + Django + PostgreSQL.
- Backend: aislamiento por membresía probado; lectura de organizaciones y vencimientos disponible para usuarios autenticados.

## Pendiente
- [ ] Verificar activación del dominio OVHcloud y comprobar DNS.
- [ ] Configurar y probar `soporte@vencira.es`.
- [ ] Confirmar posibilidad de registro de marca OEPM/EUIPO.
- [ ] Validar requisitos comerciales, precio/planes y roles.
- [ ] Autenticación robusta: MFA, gestión de sesiones y protección de login frente a abuso.
- [ ] Montar proxy de mismo origen para integrar Flutter web con sesión Django; comprobar extremo a extremo.
- [ ] Diseñar identidad OAuth/OIDC o equivalente para apps nativas.
- [ ] Definir las reglas de negocio y destinatarios de avisos. Motor de candidatos internos implementado, sin envío ni programación automática; pendientes auditoría y RGPD.
- [ ] Copias externas, observabilidad y plan de recuperación.
- [ ] VPS cuando se requiera entorno público.
