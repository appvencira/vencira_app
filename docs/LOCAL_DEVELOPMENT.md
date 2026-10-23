# Desarrollo local

Requisitos: Docker, Docker Compose y Python 3.

```bash
python3 scripts/init_env.py
docker compose config --quiet
# Sólo primera inicialización de BD nueva, explícita y controlada:
docker compose up -d db
docker compose run --rm api python manage.py migrate --noinput
# La API posterior únicamente verifica migraciones al arrancar:
docker compose up --build -d
curl -fsS http://127.0.0.1:18731/api/health/
curl -fsS http://127.0.0.1:18731/api/ready/
docker compose logs --tail=50 api
```

API ligada a localhost y base de datos sin puerto publicado. No usar contra datos reales. Desde O4, iniciar API **no aplica migraciones**: ejecuta `manage.py migrate --check --noinput` y falla si quedan pendientes. El ejemplo anterior de `migrate --noinput` es **exclusivamente para una base vacía local nueva**. En cualquier entorno con datos, usar el procedimiento con backup/restauración y migración específica controlada de [O4](OPERATION_O4_MIGRATION_GUARD.md). El proyecto de pruebas `vencira_localcheck` se opera sólo con sus scripts protegidos. Para parar, `docker compose down` conserva el volumen; `docker compose down -v` lo borra.

Tests backend independientes de Docker:
```bash
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r backend/requirements.txt
export VENCIRA_ENV=test VENCIRA_DB_ENGINE=sqlite DJANGO_DEBUG=1
export DJANGO_SECRET_KEY=ci-tests-only-secret-long-enough-1234567890
export DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
python backend/manage.py check
python backend/manage.py makemigrations --check --dry-run
python backend/manage.py test
```

CI ejecutará pruebas del backend y cliente Flutter cuando GitHub Actions esté disponible.

## Verificar API privada

Con los contenedores locales activos, crea usuarios de prueba en Django y asigna membresías desde Django shell, nunca con datos reales. El acceso de navegador utiliza `http://127.0.0.1:18731/accounts/login/`, y tras inicio de sesión `/api/v1/me/` y `/api/v1/workspaces/`. La sesión se basa en CSRF para modificaciones; no usar `curl` con contraseñas introducidas en historial de shell.

Todas las rutas disponibles y restricciones están documentadas en [API_MVP.md](API_MVP.md).

## Probar navegador + API en un mismo origen

Consulta [WEB_LOCAL.md](WEB_LOCAL.md). Requiere compilar Flutter Web y añadir `compose.web.yaml`; sirve `/`, `/api/` y `/accounts/` a través de `http://127.0.0.1:18732` sin abrir CORS ni puertos públicos.
