# VENCIRA

**Continuidad entre conversaciones:** antes de desarrollar o desplegar, leer [docs/CONTINUITY_RUNBOOK.md](docs/CONTINUITY_RUNBOOK.md). Incluye rama vigente, PR/migraciones, servidor objetivo, validación local sin GitHub Actions, backups, despliegue y restricciones de seguridad.

**Anticipamos vencimientos. Creamos oportunidades.**

Proyecto comercial de gestión de vencimientos y seguimiento de oportunidades, inicialmente para mediadores de seguros.

**Repositorio único y privado:** `appvencira/vencira_app`. No se copiará ni sincronizará código con ninguna otra cuenta.

Estado: **base técnica en desarrollo**. No introducir datos reales de clientes ni exponer servicios a Internet.

## Tecnología
- Django 5.2 LTS, Python 3.12 y Django REST Framework.
- PostgreSQL 17 en red interna.
- Flutter para web y, en fases posteriores, móvil.
- Docker Compose local y GitHub Actions.

## Primer arranque
```bash
python3 scripts/init_env.py
docker compose up --build -d
curl -fsS http://127.0.0.1:18731/api/health/
curl -fsS http://127.0.0.1:18731/api/ready/
```

Documentación: [desarrollo](docs/LOCAL_DEVELOPMENT.md), [arquitectura](docs/ARCHITECTURE.md), [seguridad](docs/SECURITY.md), [API](docs/API_MVP.md).

Dominio elegido: `vencira.es`; pedido OVHcloud 20/10/2026 pendiente de confirmación de activación. Correo previsto: `soporte@vencira.es`, aún no configurado.

## API y cliente Flutter

Autenticación provisional por sesión Django y API v1 de vencimientos restringida a miembros. Flutter dispone de un panel para consultar, crear y editar vencimientos, con acceso por sesión, CSRF, paginación, distinción entre vencimiento y preaviso y cierre de sesión. El proxy de mismo origen y su integración HTTP se verifican en CI. Consulta [clients/flutter/README.md](clients/flutter/README.md).

**No habilitar públicamente ni usar datos reales.** El login solo tiene una defensa provisional, la auditoría se limita a la API y faltan MFA, controles RGPD, retención y copias externas.

## Web y API desde una sola dirección local

Se añade `compose.web.yaml` con proxy Nginx en `http://127.0.0.1:18732`. Compila Flutter Web antes de arrancar el proxy. Procedimiento, verificación HTTP autenticada y limitaciones en [docs/WEB_LOCAL.md](docs/WEB_LOCAL.md).

## Primera prueba en servidor aislado

Para probar sin instalar Flutter en el anfitrión, existe [**docs/SERVER_PREVIEW.md**](docs/SERVER_PREVIEW.md) con `compose.preview.yaml`, build Docker multi-stage, usuario y contratos sintéticos, y acceso por túnel SSH. Los puertos locales 18731/18732 no interfieren con MASBITCOIN. **No se ha ejecutado ningún despliegue remoto ni se ha modificado `vencira.es`.**
