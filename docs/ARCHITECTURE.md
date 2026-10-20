# Arquitectura inicial de VENCIRA

**Fase:** arranque técnico sin despliegue público ni datos reales.

Backend Django 5.2 LTS + Django REST Framework. PostgreSQL 17. Flutter para web/móvil. Docker Compose solo en local. Además de `/api/health/` y `/api/ready/`, se ha añadido la API v1 **autenticada** de membresías y vencimientos y el acceso mediante sesión web de Django. Los modelos de negocio siguen sin estar registrados en Django Admin. Ver [API_MVP.md](API_MVP.md).

## Modelo inicial

- Workspace: organización o equipo.
- WorkspaceMember: usuario y rol dentro de organización.
- Renewal: referencia interna, fecha de vencimiento, estado y organización obligatoria.

**Se implementa autorización por membresía para la API v1 local**, con filtros explícitos y pruebas negativas entre organizaciones. El control se ejecuta en cada ruta; no basta con filtrar modelos en el cliente. **Aún no es apto para exposición pública**: faltan throttling, MFA, auditoría, permisos comerciales granulares y seguridad de producción.

## Pendiente

MFA, endurecimiento de autenticación/sesiones y límites de intentos, permisos por rol, motor de avisos con idempotencia y reintentos, auditoría, copias externas, despliegue TLS, RGPD y contrato de tratamiento de datos. Cliente Flutter aún sin scaffolding nativo de plataformas.
