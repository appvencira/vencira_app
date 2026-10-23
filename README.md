# VENCIRA

**Continuidad entre conversaciones:** antes de desarrollar o desplegar, leer [docs/CONTINUITY_RUNBOOK.md](docs/CONTINUITY_RUNBOOK.md). Incluye rama vigente, PR/migraciones, servidor objetivo, validación local sin GitHub Actions, backups, despliegue y restricciones de seguridad.

**Anticipamos vencimientos. Creamos oportunidades.**

Proyecto comercial de gestión de vencimientos y seguimiento de oportunidades, inicialmente para mediadores de seguros.

**Repositorio único y privado:** `appvencira/vencira_app`. No se copiará ni sincronizará código con ninguna otra cuenta.

Estado (23/10/2026): **entorno de desarrollo DEV en `https://dev.vencira.es`**, bajo control de acceso adicional, con API Django/PostgreSQL 17 y Flutter Web. **O1, O2 y O3 validadas funcionalmente por el usuario desde Android y O4 (protección de migraciones automáticas) desplegada y verificada**; migraciones hasta `0014_renewal_outcomes` aplicadas en el stack aislado `vencira_localcheck`. No utilizar datos personales reales, no considerar apto para producción ni habilitar comunicaciones hasta completar seguridad, RGPD, cifrado externo de copias y otras puertas de lanzamiento.

## Tecnología
- Django 5.2 LTS, Python 3.12 y Django REST Framework.
- PostgreSQL 17 en red interna.
- Flutter para web y, en fases posteriores, móvil.
- Docker Compose local y GitHub Actions.

## Migraciones y arranque seguro (O4)

El arranque de API se endurece en O4 para **comprobar migraciones pendientes sin aplicarlas automáticamente** (`manage.py migrate --check --noinput`). Las migraciones futuras se ejecutarán expresamente, con preflight, respaldo y restauración comprobada, según [el procedimiento O4](docs/OPERATION_O4_MIGRATION_GUARD.md). **O4 ya está desplegada y comprobada en Ubuntu el 23/10/2026**: `API_RUNTIME_MIGRATE_POLICY=CHECK_ONLY`, respaldo del esquema O3 con restauración completa en PostgreSQL 17, 119 pruebas Django, API/DB/Web saludables y `RESULTADO_GLOBAL=0`. El arranque no aplica migraciones. Consulta [el acta O4](docs/OPERATION_O4_MIGRATION_GUARD.md).

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

Para probar sin instalar Flutter en el anfitrión, existe [**docs/SERVER_PREVIEW.md**](docs/SERVER_PREVIEW.md) con `compose.preview.yaml`, build Docker multi-stage, usuario y contratos sintéticos, y acceso por túnel SSH. Los puertos locales 18731/18732 no interfieren con MASBITCOIN. **Actualización (23/10/2026):** esa descripción corresponde al primer prototipo. Ya existe un entorno de prueba remoto separado, `vencira_localcheck`, accesible mediante `dev.vencira.es`, con O1–O3 instaladas y validadas. No confundirlo con producción ni con `vencira_preview`. El estado operativo y las medidas de protección vigentes se documentan en [`docs/CONTINUITY_RUNBOOK.md`](docs/CONTINUITY_RUNBOOK.md).
