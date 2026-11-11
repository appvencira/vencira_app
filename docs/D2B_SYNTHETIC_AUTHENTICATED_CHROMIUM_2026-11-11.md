# D2-B — login real Chromium y sesión sintética aislada

Fecha: 11/11/2026. **Estado: PREPARADO, PENDIENTE DE EJECUCIÓN.** D1-Z y D2-A están cerrados PASS en sus respectivos alcances.

## Alcance

Ejercitar la transición real entre el formulario Django y la interfaz Flutter bajo HTTPS en Chromium, con una cuenta sintética **creada en PostgreSQL 17 tmpfs** y un espacio de trabajo sintético con rol `owner`. El usuario y su contraseña se generan con un nonce/aleatoriedad local para cada ejecución. No son credenciales de DEV ni se escriben en GitHub.

D2-B comprueba: GET formulario Django 200 con campos usuario, contraseña y token CSRF; envío por botón real y navegación de regreso a `/`; GET `/api/v1/me/` autenticado 200, listado de un workspace como owner 200; `flutter-view` real; respuesta 200 de consulta de workspaces durante el arranque Flutter; recarga y continuidad de sesión; nuevo contexto Chromium **sin cookies** que recibe 401/403 tanto en `me` como en `workspaces`. El mismo smoke se ejecuta tras recrear solo Nginx efímero.

Los controles heredados del laboratorio D2-A se ejecutan nuevamente: build Flutter Web 3.44/CanvasKit local, Caddy TLS sintético, políticas CSRF, PostgreSQL tmpfs, red Docker `--internal`, ningún puerto publicado, ausencia de deploy/migración/restore sobre DEV, comparación de identidad de contenedores DEV y limpieza total. La copia/restore de un esquema ficticio PG17 independiente se repite. No se altera código de producción para facilitar el login.

## Archivos

- `scripts/main_d2b_browser_authenticated_isolated.sh` — orquestador autocontenido y barreras DEV
- `scripts/main_d2b_seed_synthetic.py` — usuario y membresía ficticios, sin datos de clientes
- `scripts/main_d2b_flutter_caddy_probe.py` — HTTPS/CSRF de laboratorio
- `scripts/Dockerfile.d2b-playwright` — contenedor Chromium aislado
- `scripts/main_d2b_chromium_auth_smoke.js` — interacción con formulario real, sesión, API y Flutter

## Ejecución autorizada exclusivamente en laboratorio

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d2b_browser_authenticated_isolated.sh
bash scripts/main_d2b_browser_authenticated_isolated.sh
echo "D2B_SHELL_RESULT=$?"
```

Marcadores **esperados, NO observados todavía**:

```text
D2B_AUTH_FIXTURE=PASS
D2B_LOGIN_FORM_AND_CSRF=PASS
D2B_BROWSER_FORM_LOGIN=PASS
D2B_AUTHENTICATED_ME_200=PASS
D2B_AUTHENTICATED_WORKSPACE_OWNER=PASS
D2B_FLUTTER_AUTHENTICATED_WORKSPACE_HTTP=PASS
D2B_AUTHENTICATED_FLUTTER_VIEW=PASS
D2B_BROWSER_RELOAD_SESSION_PRESERVED=PASS
D2B_ANONYMOUS_SESSION_ISOLATION=PASS
D2B_BROWSER_AUTH_SMOKE=PASS
D2B_CHROMIUM_RENDER_GATE=PASS
D2B_WEB_RECOVERY_RESTART=PASS
D2B_CHROMIUM_AFTER_WEB_RESTART=PASS
D2B_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS
D2B_CHROMIUM_AUTHENTICATED_NAVIGATION_AND_RECOVERY_GATE=PASS
D2B_DEV_CONTAINERS_UNCHANGED=OK
D2B_EPHEMERAL_CLEANUP=DONE
D2B_RESULT=0
```

## Exclusiones y seguridad

D2-B comprueba **inicio de sesión, acceso a workspace, recarga de sesión y aislamiento anónimo**, no clics de operaciones de negocio (crear vencimiento, editar póliza, calendario, modalidades ni adjuntos). Esos flujos precisan pruebas sintéticas separadas y comprobación de datos de usuario. No se prueba MFA real, fuentes Google Fonts, fidelidad visual, configuración exacta Caddy producción, release ni rollback de imágenes/DB persistentes.

El test de login no imprime contraseñas, usernames, cookies, bodies o tokens; si falla, solo imprime marcadores fijos de etapa. La cuenta solo existe en el PG17 efímero. Los argumentos de Docker incluyen credenciales sintéticas, por lo que el host con permisos de Docker podría observarlas durante el laboratorio; **no son secretos de DEV**.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D2B_RELEASE_AUTHORIZED=NO
D2B_DEPLOY_EXECUTED=NO
D2B_LIVE_MIGRATIONS_EXECUTED=NO
D2B_LIVE_RESTORE_EXECUTED=NO
```

**D2-B no está aprobado antes de la ejecución del operador.** Si falla el formulario o Flutter, no hacer concesiones de seguridad: registrar el marcador y resolver la causa.


## Cierre del operador — D2-B PASS (11/11/2026)

El operador ha ejecutado D2-B con **`D2B_RESULT=0`** y `D2B_CHROMIUM_AUTHENTICATED_NAVIGATION_AND_RECOVERY_GATE=PASS`. El laboratorio permaneció aislado y no modificó los contenedores DEV.

Evidencia de infraestructura: `D2B_PROBE_SYNTAX=PASS`, `D2B_FIXTURE_SYNTAX=PASS`, `D2B_DEV_IDENTITY=PASS`, `D2B_INTERNAL_NETWORK=PASS`, `D2B_PG17_TMPFS=PASS`, `D2B_CANDIDATE_IMAGE=PASS`, `D2B_SYNTHETIC_MIGRATIONS=PASS`, `D2B_AUTH_FIXTURE=PASS`, `D2B_GUNICORN_STARTED=YES`, `D2B_FLUTTER_RELEASE_BUILD=PASS`, `D2B_LOCAL_CANVASKIT_BUNDLED=PASS`, `D2B_NGINX_WEB_CONTAINER_STARTED=YES`, `D2B_CADDY_LAB_CONFIG_VALID=PASS`, `D2B_NO_HOST_PORTS=PASS`, `D2B_CADDY_TLS_HTTP_CONTRACT=PASS`, `D2B_CSRF_SECURE_COOKIE=PASS`, `D2B_CSRF_POST_DENIED=PASS`, `D2B_UNTRUSTED_CA_DENIED=PASS`, `D2B_CADDY_HTTPS_PROBE=PASS`, `D2B_CHROMIUM_SMOKE_SYNTAX=PASS`.

**Primera ejecución Chromium:** `D2B_LOGIN_FORM_AND_CSRF=PASS`, `D2B_BROWSER_FORM_LOGIN=PASS`, `D2B_FLUTTER_AUTHENTICATED_WORKSPACE_HTTP=PASS`, `D2B_AUTHENTICATED_ME_200=PASS`, `D2B_AUTHENTICATED_WORKSPACE_OWNER=PASS`, `D2B_AUTHENTICATED_FLUTTER_VIEW=PASS`, `D2B_AUTHENTICATED_PAGE_ERRORS=0`, `D2B_BROWSER_RELOAD_SESSION_PRESERVED=PASS`, `D2B_SYNTHETIC_WORKSPACE_VISIBLE_IN_API=PASS`, `D2B_ANONYMOUS_SESSION_ISOLATION=PASS`, `D2B_NO_CUSTOMER_DATA=YES`, `D2B_BROWSER_AUTH_SMOKE=PASS`, `D2B_CHROMIUM_RENDER_GATE=PASS`.

**Recuperación del Nginx efímero:** `D2B_WEB_RECOVERY_RESTART=PASS`; el segundo Chromium repitió con PASS todas las comprobaciones de login, workspace, Flutter, persistencia y aislamiento de sesión, con `D2B_CHROMIUM_AFTER_WEB_RESTART=PASS`. La restauración de un esquema ficticio sobre PG17 aislado fue `D2B_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS`. `D2B_DEV_CONTAINERS_UNCHANGED=OK` y `D2B_EPHEMERAL_CLEANUP=DONE`.

**Límites de la aprobación:** el propio test especifica `D2B_UI_AUTHENTICATED_NAVIGATION_COVERAGE=LOGIN_AND_RELOAD_ONLY`. No valida creación/edición de vencimientos, calendario, detalles, modalidades, aseguradoras, autenticación MFA, fuentes externas, accesibilidad ni rollback de imágenes/DB operativas. Los indicadores `D2B_OPERATIONAL_IMAGE_AND_DB_ROLLBACK_VERIFIED=NO`, `D2B_CADDY_PRODUCTION_CONFIG_VERIFIED=NO`, `D2B_ROLLBACK_EXECUTED=NO` y `D2B_ROLLBACK_VERIFIED=NO` confirman estos límites. El warning de Wasm dry run es informativo.

**Cierre formal: D2-B PASS dentro del alcance de login y recarga autenticados con usuario ficticio.** Mantener `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `D2B_RELEASE_AUTHORIZED=NO`, `D2B_DEPLOY_EXECUTED=NO`, `D2B_LIVE_MIGRATIONS_EXECUTED=NO`, `D2B_LIVE_RESTORE_EXECUTED=NO`. No repetir D2-B salvo cambios materiales de ese alcance. Siguiente bloque recomendado: D2-C, acciones funcionales sintéticas sobre CRUD y calendario con evidencias antes/después de DB aislada.
