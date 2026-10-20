# VENCIRA

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

Autenticación provisional por sesión Django y API v1 de vencimientos restringida a miembros. Flutter dispone de una pantalla de consulta (organizaciones, vencimientos, paginación, estados de error y sesión), pendiente de conectar **extremo a extremo mediante un proxy de mismo origen**. Consulta [clients/flutter/README.md](clients/flutter/README.md).

**No habilitar públicamente** mientras falten límites al inicio de sesión, MFA, auditoría y verificación de seguridad y cumplimiento.
