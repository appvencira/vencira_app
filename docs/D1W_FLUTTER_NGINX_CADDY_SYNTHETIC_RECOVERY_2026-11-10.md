# VENCIRA — D1-W: Flutter real → Nginx → Caddy TLS → Django / PG17

Fecha: 10/11/2026. Rama única `main`. **GATE PUBLICADO; PENDIENTE DE VALIDACIÓN EN VPS.**

## Propósito

D1-V acreditó Caddy 2.11.7 → Gunicorn/Django candidato con PostgreSQL 17 sintético, cookies Secure y CSRF. D1-W sustituye el fixture de página raíz por **Flutter Web realmente compilado desde `clients/flutter`**, servido por **Nginx** dentro de la misma red Docker aislada y proxy inverso **Caddy**. Incluye un ejercicio de backup, alteración y restauración de un **esquema PostgreSQL exclusivamente sintético**; no ejercita rollback operativo completo.

## Implementación

`scripts/main_d1w_flutter_nginx_caddy_isolated.sh` parte de los controles de D1-V:

- Comprueba HEAD == `origin/main` y árbol limpio, sintaxis AST de `scripts/main_d1w_flutter_caddy_probe.py`, proyecto e identidades de tres contenedores DEV **solo con `docker inspect`**.
- Crea una red Docker `--internal` con nombres aleatorios. Crea PostgreSQL 17 en `tmpfs`, imagen Django de `backend/`, aplica migraciones solo en la BD efímera y arranca Gunicorn.
- Compila Flutter usando `ghcr.io/cirruslabs/flutter:3.44.0` sobre copia desechable de `clients/flutter`; exporta los ficheros `build/web` al directorio efímero del laboratorio. Nginx `nginx:1.27-alpine` los sirve con montaje read-only.
- Lanza Caddy 2.11.7 con Caddyfile **sintético**: rutas `/api/*`, `/accounts/*` y `/admin/*` van a Django; otras rutas, a Nginx. Caddy termina TLS con certificado sintético `d1w-proxy`.
- El cliente Python dentro de la red comprueba vía HTTPS el `index.html`, `main.dart.js`, `flutter_bootstrap.js` con HTTP 200 y Content-Type JavaScript; además valida health, ready, login, token CSRF Secure, POST sin CSRF rechazado, acceso anónimo denegado, ruta nativa 404 y certificado CA desconocido rechazado.
- Crea esquema `d1w_rollback_fixture` con dato sintético, realiza `pg_dump -Fc`, altera/elimina el esquema y lo restaura con `pg_restore`, confirmando el estado anterior. **No es un ensayo de restic/O5 ni restaura tablas de negocio ni toda la base de datos.**
- El ejecutor elimina todos los contenedores, red, imagen Docker candidata y temporales del laboratorio con `trap EXIT`, verificando las identidades de contenedores DEV antes/después. No publica puertos del API/Web/Caddy al host y no accede al volumen PostgreSQL DEV.

La compilación Flutter puede necesitar descargar dependencias y consumir recursos. El contenedor de compilación no se une a la red interna de BD (no se entregan credenciales); solo accede a una copia de código del repositorio y al destino temporal del artefacto.

## Validación única desde Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d1w_flutter_nginx_caddy_isolated.sh
python3 - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d1w_flutter_caddy_probe.py").read_text(encoding="utf-8"))
print("D1W_PROBE_AST=PASS")
PY
bash scripts/main_d1w_flutter_nginx_caddy_isolated.sh
echo "D1W_SHELL_RESULT=$?"
```

Exigir antes de cerrar:

```text
D1W_DEV_IDENTITY=PASS
D1W_INTERNAL_NETWORK=PASS
D1W_PG17_TMPFS=PASS
D1W_CANDIDATE_IMAGE=PASS
D1W_SYNTHETIC_MIGRATIONS=PASS
D1W_FLUTTER_RELEASE_BUILD=PASS
D1W_NGINX_WEB_CONTAINER_STARTED=YES
D1W_CADDY_LAB_CONFIG_VALID=PASS
D1W_NO_HOST_PORTS=PASS
D1W_FLUTTER_WEB_ROOT_AND_ASSETS=PASS
D1W_CADDY_TLS_HTTP_CONTRACT=PASS
D1W_CSRF_SECURE_COOKIE=PASS
D1W_CSRF_POST_DENIED=PASS
D1W_UNTRUSTED_CA_DENIED=PASS
D1W_CADDY_HTTPS_PROBE=PASS
D1W_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS
D1W_FLUTTER_CADDY_POSTGRES_AND_SYNTHETIC_RESTORE_GATE=PASS
D1W_DEV_CONTAINERS_UNCHANGED=OK
D1W_EPHEMERAL_CLEANUP=DONE
D1W_RESULT=0
D1W_SHELL_RESULT=0
```

**Si falla, no asumir PASS ni ejecutar cambios en DEV.** Recoger los marcadores de fase, sin enviar variables de entorno, cookies ni secretos. El código es un primer candidato de gate que aún no se ha ejecutado.

## Bloqueos que siguen después de un hipotético PASS

1. El Caddyfile del laboratorio **no es** el Caddyfile actualmente cargado en DEV; faltará revisar confidencialmente la configuración efectiva y las reglas de Nginx/SPA reales. Las pruebas HTTP no son una prueba visual/manual del flujo Flutter en navegador.
2. `D1W_SYNTHETIC_SCHEMA_BACKUP_RESTORE=PASS` solo validaría restauración de un esquema sintético, no el rollback de imágenes Docker, Caddy, volúmenes persistentes, migraciones de negocio o escrituras realizadas tras una ventana.
3. Se requiere inventariar y conservar digests de imágenes anteriores, realizar copia O5 inmediatamente antes de una futura ventana, documentar control de escrituras, RPO/RTO, postchecks, cambio de imágenes y vuelta atrás en un ensayo seguro. **Nunca** usar `down -v` sobre DEV.
4. La promoción DEV requiere **autorización explícita posterior**; MFA real y login Android nativo son pistas separadas.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_LIVE_RESTORE_EXECUTED=NO
```
