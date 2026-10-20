# Arquitectura inicial de VENCIRA

**Fase:** desarrollo sin despliegue público ni datos reales.

Backend Django 5.2 LTS + Django REST Framework. PostgreSQL 17. Flutter para web/móvil. Docker Compose solo en local. Además de `/api/health/` y `/api/ready/`, existe la API v1 **autenticada** de membresías y vencimientos y acceso mediante sesión web de Django. Los modelos de negocio no están registrados en Django Admin. Ver [API_MVP.md](API_MVP.md).

## Modelo inicial

- Workspace: organización o equipo.
- WorkspaceMember: usuario y rol dentro de organización.
- Renewal: referencia interna, fecha de vencimiento, estado y organización obligatoria.

La autorización por membresía se aplica y prueba en lecturas y escrituras de la API v1. La interfaz Flutter consume actualmente solo operaciones GET, y borra los resultados visibles al cambiar de organización para evitar mezclar información en pantalla.

## Autenticación y cliente Flutter

- El backend dispone de sesiones Django + CSRF.
- El cliente Flutter web inicia la navegación a `/accounts/login/` desde el **mismo origen** y consume GET con cookies gestionadas por el navegador.
- Falta configurar el proxy/local web que sirva frontend y API desde el mismo origen. **No existe flujo integrado de inicio de sesión ni uso real de datos desde Flutter todavía**.
- Una futura aplicación Android/iOS necesitará un flujo de identidad nativo, no la solución provisional por cookie web.

## Pendiente obligatorio

MFA, endurecimiento de autenticación/sesiones y límites de intentos, permisos por rol, motor de avisos con idempotencia y reintentos, auditoría, copias externas, despliegue TLS, RGPD y contrato de tratamiento de datos. Cliente Flutter aún sin scaffolding host final.
