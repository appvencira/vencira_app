# VENCIRA — Ensayo integrado y primera prueba local

**Estado (22/10/2026):** rama de integración `integration/local-e2e-prep`. **No desplegada**, sin datos reales y sin modificar `dev.vencira.es`. Esta guía se mantiene como procedimiento reproducible de la futura prueba local.

## Versiones y dependencias incorporadas

La rama integra en un solo árbol las cuatro líneas de desarrollo sin fusionar las PR originales:

| PR | Contenido |
|---|---|
| #4 | Flutter, catálogos ES/CA, temas Sistema/Claro/Oscuro y pruebas responsive |
| #6 | Django: permisos por responsable, asignaciones, directorio de miembros, migración 0007 |
| #7 | Django: `/api/v1/workspaces/{id}/agenda/?day=YYYY-MM-DD`, recordatorios previstos y vencimientos |
| #9 | Flutter: agenda diaria, tira semanal, navegación, Hoy, traducciones, test de API/widget |

La integración se obtuvo mediante un **commit de dos padres** que conserva las ramas de procedencia, copiando los blobs actuales del cliente Flutter sobre la rama backend ya validada. No se han cambiado las reglas de acceso ni la base de datos del servidor en este proceso.

## Verificación automatizada requerida

Workflow: `.github/workflows/integration-local.yml` ejecuta **tres bloques independientes de producción** (en runners efímeros de GitHub, NO en el VPS):

1. **Django:** `check`, `makemigrations --check --dry-run`, suite completa en SQLite y PostgreSQL 17.
2. **Flutter:** comparación ARB ES/CA, `flutter gen-l10n`, análisis, tests unitarios y widgets, compilación web; genera artefacto temporal.
3. **HTTP mismo origen:** construye Django y PostgreSQL en un Compose efímero, monta Flutter Web compilado, comprueba política de origen/referrer, genera un usuario y póliza totalmente ficticios, inicia sesión con CSRF, consulta agenda del día y motivo del vencimiento, rechaza fecha inválida, crea/edita anotación, cierra sesión y exige 401/403 para agenda y workspace. Finalmente destruye el volumen **exclusivo de CI**.

**Control:** no declarar esta rama validada hasta que los tres trabajos estén verdes en el commit exacto. La verificación por API no es inspección de experiencia visual en un navegador real.

## Primera prueba manual local — cuando demos paso

**Requisitos:** Linux x86-64/arm64 con Docker Engine + Compose v2, Git y Python 3. La máquina debe disponer de recursos para compilar Flutter web en Docker. Trabajar en un directorio nuevo, con código obtenido mediante la cuenta autorizada en el repositorio privado.

**Importante:** NO ejecutar los comandos en la VPS que aloja `vencira_preview`. El proyecto y los puertos siguientes están pensados para **otra máquina**. Si se utiliza la misma máquina, exigir auditoría previa de puertos, datos, recursos y volúmenes. No exponer 28731/28732 a Internet.

```bash
git clone --branch integration/local-e2e-prep https://github.com/appvencira/vencira_app.git vencira-localcheck
cd vencira-localcheck
python3 scripts/init_env.py
python3 - <<'PY'
from pathlib import Path
path = Path(".env")
config = path.read_text()
config = config.replace("VENCIRA_BIND_PORT=18731", "VENCIRA_BIND_PORT=28731")
config = config.replace("VENCIRA_WEB_BIND_PORT=18732", "VENCIRA_WEB_BIND_PORT=28732")
path.write_text(config)
PY
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml config --quiet
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml up --build -d
VENCIRA_WEB_BIND_PORT=28732 python3 scripts/smoke_same_origin.py
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml \
  exec -T api python manage.py seed_preview
```

El último comando imprime **una sola vez** las credenciales de `vencira_demo`. No pegarlas en el chat ni conservarlas en logs públicos. Usar exclusivamente las referencias DEMO. Navegador **en la propia máquina**: `http://127.0.0.1:28732`. Desde otra máquina usar SSH con túnel; nunca cambiar las vinculaciones loopback por `0.0.0.0`.

Para consultar estados sin tocar otros proyectos:

```bash
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml ps
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml logs --tail=60
```

Detener sin borrar datos de prueba:

```bash
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml down
```

**Destruir datos EFÍMEROS de ESTA prueba** únicamente si se quiere empezar de cero, comprobando el nombre del proyecto:

```bash
docker compose -p vencira_localcheck -f compose.yaml -f compose.preview.yaml down -v --remove-orphans
```

El comando `down -v` NO forma parte del apagado normal: borra el PostgreSQL de la prueba. No debe ejecutarse en `vencira_preview` ni en ningún Compose compartido.

## Aceptación manual

- Verificar login y cierre; ningún vencimiento aparece después de salir.
- Seleccionar idioma ES/CA, tema Sistema/Claro/Oscuro, recargar y comprobar persistencia.
- Abrir agenda y navegar entre días de diferentes meses; comprobar estado vacío, avisos **previstos** y vencimientos.
- Inspeccionar 320, 375, 768 y 1440 px, fuente 200 %, contraste, orientación vertical y horizontal.
- Crear y editar registros ficticios; verificar que el preaviso no supera el vencimiento.
- Con dos miembros de pruebas distintos, intentar acceder a anotaciones ajenas: deben responder 404. El propietario debe poder ver y reasignar.
- Comprobar que al cambiar de organización, día o cerrar sesión se limpian los datos anteriores.
- Registrar fallos con URL/commit/salida técnica **sin incluir credenciales, cookies, tokens ni datos personales**.

## Lo que esta prueba NO certifica

MFA, cifrado del almacenamiento del dispositivo, offline nativo, RGPD completo, archivos privados, entregas reales de notificaciones, aplicación móvil publicada ni interfaz mensual definitiva. Tampoco garantiza migraciones en un entorno que ya contenga datos reales. Antes de cualquier lanzamiento habrá auditoría de permisos, backup/rollback y aceptación por responsables.

## Seguimiento

- PR integrada de ensayo: pendiente de abrir desde esta rama.
- Procedencia: PR #4 / #6 / #7 / #9.
- `docs/FLUTTER_DAY_AGENDA.md`, `docs/TEAM_ASSIGNMENT_SECURITY.md`, `docs/AGENDA_DAY_CONTRACT.md`.
