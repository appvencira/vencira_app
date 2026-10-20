# VENCIRA

**Anticipamos vencimientos. Creamos oportunidades.**

Proyecto comercial de gestión de vencimientos y seguimiento de oportunidades, inicialmente para mediadores de seguros.

**Repositorio único y privado:** `appvencira/vencira_app`. No se copiará ni sincronizará código con ninguna otra cuenta.

Estado: **base técnica en desarrollo**. No introducir datos reales de clientes ni exponer servicios a Internet.

## Tecnología
- Django 5.2 LTS, Python 3.12 y Django REST Framework.
- PostgreSQL 17 en red interna.
- Flutter (web y móvil) en fase de arranque.
- Docker Compose local y GitHub Actions.

## Primer arranque
```bash
python3 scripts/init_env.py
docker compose up --build -d
curl -fsS http://127.0.0.1:18731/api/health/
curl -fsS http://127.0.0.1:18731/api/ready/
```

Documentación: [desarrollo](docs/LOCAL_DEVELOPMENT.md), [arquitectura](docs/ARCHITECTURE.md), [seguridad](docs/SECURITY.md).

Dominio elegido: `vencira.es`; pedido OVHcloud 20/10/2026 pendiente de confirmación de activación. Correo previsto: `soporte@vencira.es`, aún no configurado.
