# Arquitectura inicial de VENCIRA

**Fase:** desarrollo sin despliegue público ni datos reales.

Backend Django 5.2 LTS + Django REST Framework. PostgreSQL 17. Flutter para web/móvil. Docker Compose solo en local. Además de `/api/health/` y `/api/ready/`, existe la API v1 **autenticada** de membresías y vencimientos y acceso mediante sesión web de Django. Los modelos de negocio no están registrados en Django Admin. Ver [API_MVP.md](API_MVP.md).

## Modelo inicial

- Workspace: organización o equipo.
- WorkspaceMember: usuario y rol dentro de organización.
- Renewal: referencia interna, fecha de vencimiento, estado y organización obligatoria.

La autorización por membresía se aplica y prueba en lecturas y escrituras de la API v1. La interfaz Flutter consulta, crea y edita vencimientos mediante GET/POST/PATCH y CSRF. Los resultados visibles se eliminan al cambiar de organización y cuando se cierra sesión. Las escrituras API quedan auditadas dentro de la misma transacción.

## Autenticación y cliente Flutter

- El backend dispone de sesiones Django + CSRF.
- Flutter Web inicia sesión a través de `/accounts/login/` desde el **mismo origen**; consulta y modifica vencimientos con cookies del navegador y token obtenido de `/api/v1/csrf/`. Cierra sesión con POST a `/accounts/logout/`.
- Se añade un proxy Nginx local opcional (`compose.web.yaml`) que sirve frontend y API desde el mismo origen y permite ensayar el login con sesión Django. El smoke test HTTP automatizado se define en `scripts/smoke_same_origin.py`. **Todavía faltan pruebas visuales con navegador real, hardening y despliegue seguro**.
- Una futura aplicación Android/iOS necesitará un flujo de identidad nativo, no la solución provisional por cookie web.

## Pendiente obligatorio

MFA, endurecimiento de autenticación/sesiones y límites de intentos, permisos por rol, motor de avisos con idempotencia y reintentos, auditoría, copias externas, despliegue TLS, RGPD y contrato de tratamiento de datos. Cliente Flutter aún sin scaffolding host final.

## Preview autocontenida para servidor

`compose.preview.yaml` construye Flutter en Docker, utiliza su propio proyecto `vencira_preview` y expone únicamente los puertos de loopback 18731/18732. Acceso previsto: túnel SSH. Ver [SERVER_PREVIEW.md](SERVER_PREVIEW.md). No tiene herramientas de producción (MFA, TLS público, RGPD, backups). No se ha desplegado remotamente.
