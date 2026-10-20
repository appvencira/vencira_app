# Integración Flutter Web + Django en el mismo origen

**Solo para pruebas locales.** No publicar este Nginx en Internet, no cargar datos personales ni modificar el DNS de vencira.es.

## Objetivo

Usar **una sola dirección**, http://127.0.0.1:18732, para:

- `/` y los recursos estáticos: Flutter Web (precompilado).
- `/api/`: Django REST Framework.
- `/accounts/`: formulario de acceso y cierre de sesión Django.

Las cookies de sesión pertenecen al mismo host y la API no requiere abrir CORS. El backend sigue disponible solo en loopback http://127.0.0.1:18731 y PostgreSQL permanece en una red interna de Docker.

## Inicio

Necesitas Docker, Docker Compose, Python 3 y **Flutter SDK** en el equipo donde compiles:

```bash
git clone git@github.com:appvencira/vencira_app.git
cd vencira_app
git checkout chore/bootstrap-vencira
python3 scripts/init_env.py          # Solo la primera vez
cd clients/flutter
flutter pub get
flutter build web --release --pwa-strategy=none
cd ../..
docker compose -f compose.yaml -f compose.web.yaml config --quiet
docker compose -f compose.yaml -f compose.web.yaml up --build -d
python3 scripts/smoke_same_origin.py
```

Abre http://127.0.0.1:18732. El flujo de login existe, pero hasta crear un usuario de prueba y asignarlo a una organización mostrará acceso pendiente.

**Alternativa sin Flutter SDK local:** en GitHub Actions el job `flutter` publica un artefacto `vencira-web-build` al pasar las pruebas. Descárgalo y extrae **su contenido** en `clients/flutter/build/web` antes de levantar el proxy (sin ejecutar `flutter build web`).

## Preparar un usuario solo para esta máquina

No hay registro público de usuarios. Usa las órdenes del backend de desarrollo exclusivamente con datos sintéticos:

```bash
docker compose -f compose.yaml -f compose.web.yaml exec api python manage.py createsuperuser
docker compose -f compose.yaml -f compose.web.yaml exec api python manage.py shell
```

En el shell (sustituye `usuario_prueba` por el que acabas de crear):

```python
from django.contrib.auth import get_user_model
from reminders.models import Workspace, WorkspaceMember, Renewal
from datetime import date
u = get_user_model().objects.get(username="usuario_prueba")
w = Workspace.objects.create(name="Organización de prueba")
WorkspaceMember.objects.create(workspace=w, user=u, role="owner")
Renewal.objects.create(workspace=w, customer_reference="PRUEBA-LOCAL-001", expires_on=date(2027, 1, 31))
exit()
```

Inicia sesión desde el enlace del panel, siempre en **127.0.0.1:18732**, no mezclando localhost y 127.0.0.1. Después vuelve a la pantalla principal. Debes ver la organización y el vencimiento ficticio.

## Pruebas en CI

La CI:
1. Compila Flutter Web y guarda los archivos generados como artefacto.
2. Levanta PostgreSQL, Django y Nginx local con `docker compose`.
3. Crea temporalmente un usuario y vencimiento sintéticos con contraseña aleatoria.
4. Ejecuta `scripts/smoke_same_origin.py`: verifica acceso web, bloqueo anónimo, CSRF, login, consulta privada y logout.
5. Destruye los contenedores y volúmenes efímeros del runner de CI.

**Este smoke test no equivale a una auditoría de seguridad ni sustituye pruebas reales de navegador.**

## Detener

```bash
docker compose -f compose.yaml -f compose.web.yaml down
```

Para conservar los datos de prueba no uses `down -v`. No ejecutar comandos globales de Docker que interfieran con otros proyectos.

## No listo para producción

Pendientes: protección ante fuerza bruta, MFA, recuperación de cuenta, TLS, secretos de producción, control de sesiones y roles, auditoría, backup/restauración y RGPD. Las apps Android/iOS aún necesitarán autenticación propia.
