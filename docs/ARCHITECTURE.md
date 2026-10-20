# Arquitectura inicial de VENCIRA

**Fase:** arranque técnico sin despliegue público ni datos reales.

Backend Django 5.2 LTS + Django REST Framework. PostgreSQL 17. Flutter para web/móvil. Docker Compose solo en local. Los únicos endpoints HTTP públicos del backend son `/api/health/`, `/api/ready/` y el sistema estándar Django Admin; los modelos de negocio NO están registrados en el Admin.

## Modelo inicial

- Workspace: organización o equipo.
- WorkspaceMember: usuario y rol dentro de organización.
- Renewal: referencia interna, fecha de vencimiento, estado y organización obligatoria.

**No se han implementado autorizaciones de acceso a vencimientos ni endpoints CRUD**. Filtrar modelos por organización no es una garantía de aislamiento. Antes de abrir API de negocio debe haber controles explícitos y pruebas negativas entre organizaciones.

## Pendiente

Autenticación/MFA, control de permisos por tenant, motor de avisos con idempotencia y reintentos, auditoría, copias externas, despliegue TLS, RGPD y contrato de tratamiento de datos. Cliente Flutter aún sin scaffolding nativo de plataformas.
