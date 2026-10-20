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
- [ ] Aprobar reglas de negocio y destinatarios (ver `docs/REMINDER_RULES_DRAFT.md`). El motor ya distingue vencimiento de límite explícito de preaviso, pero solo prepara candidatos sin programación ni envío. Pendiente concretar para cada producto qué plazo jurídico/contractual debe capturarse y el comportamiento `contacted`.
- [ ] Completar auditoría: cobertura de accesos administrativos/escrituras fuera API, retención, inmutabilidad, y derechos RGPD. Registro mínimo de POST/PATCH API en desarrollo.
- [ ] Copias externas, observabilidad y plan de recuperación.
- [ ] VPS cuando se requiera entorno público.
