# VENCIRA — D1-X, preparación de promoción: configuración cargada + recuperación de BD sintética

Fecha: 10/11/2026. Solo rama `main`. **PUBLICADO, NO EJECUTADO EN EL VPS**.

## Contexto de evidencia

D1-N confirmó restauración de backup O5 real sobre PostgreSQL 17 aislado; D1-O hizo pruebas integrales Django/Flutter; D1-P HTTPS existente en DEV; D1-Q/R/T inventarios; D1-S regresión Django; D1-U/V comprobaron HTTPS candidato con Django y Caddy sintético; D1-W comprobó Flutter release real, Nginx, Caddy, Django y un esquema sintético restaurado, con limpieza `DONE` y `RESULT=0`.

Estas pruebas **no demuestran todavía** el plan de marcha atrás de imágenes y datos con tráfico real, ni la interfaz real abierta en un navegador, ni que el Caddyfile de laboratorio reproduzca exactamente el servicio operativo.

## D1-X — una sola ejecución con dos comprobaciones nuevas

El ejecutor `scripts/main_d1x_consolidated_readiness.sh` verifica HEAD=origin/main y árbol limpio, sintaxis Python/Bash, y ejecuta:

**1. Caddy realmente cargado, lectura sin secretos** — `scripts/main_d1x_loaded_caddy_readonly.py`: solicita únicamente `GET http://127.0.0.1:2019/config/` (API administrativa local de Caddy), sin proxy HTTP, sin modificaciones. No imprime ni persiste el JSON de configuración. Comprueba la existencia de servidores HTTP y de al menos un handler `reverse_proxy` y publica solo marcadores. **No asocia todavía rutas a un host concreto, no compara con el Caddyfile en disco y no inspecciona la configuración interna de Nginx**. Si la API administrativa está deshabilitada/no disponible: `D1X_CADDY_LOADED_CONFIG_GATE=NOT_VERIFIED`, `D1X_RESULT=2`; no se infiere ausencia de Caddy ni problema de seguridad.

**2. Restauración de base PostgreSQL completa exclusivamente sintética** — `scripts/main_d1x_full_db_recovery_isolated.sh`: inventaría identidades de los tres contenedores DEV usando `docker inspect` y crea una red Docker `--internal`, un contenedor PostgreSQL 17 temporal con `PGDATA` en `tmpfs`, sin puertos expuestos ni volúmenes persistentes. Genera tabla ficticia, `pg_dump -Fc` de **toda la BD sintética**, la modifica/elimina, recupera con `pg_restore --clean --if-exists` y verifica el valor anterior. Todo ocurre dentro del contenedor temporal; el dump también se encuentra en `tmpfs`. Al terminar elimina contenedor y red y verifica identidades DEV.

Este segundo control **NO** sustituye el restore del backup O5 real probado antes, ni prueba rollback del volumen DEV, ni la compatibilidad de migraciones de negocio, ni conmutación de imágenes/web/proxy. No lee la base de datos DEV.

## Validación única en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash scripts/main_d1x_consolidated_readiness.sh
echo "D1X_SHELL_RESULT=$?"
```

Criterios:

```text
D1X_PYTHON_AST=PASS
D1X_BASH_SYNTAX=PASS
D1X_CADDY_LOADED_HTTP_SERVER_CONFIG=PASS
D1X_CADDY_REVERSE_PROXY_PRESENT=YES
D1X_CADDY_LOADED_CONFIG_GATE=PASS
D1X_DB_DEV_IDENTITY=PASS
D1X_DB_INTERNAL_NETWORK=PASS
D1X_DB_PG17_TMPFS=PASS
D1X_DB_NO_PORTS_NO_PERSISTENT_MOUNTS=PASS
D1X_DB_FULL_SYNTHETIC_DB_SNAPSHOT=PASS
D1X_DB_FULL_SYNTHETIC_DB_RESTORE=PASS
D1X_DB_DATA_RECONCILIATION=PASS
D1X_DB_DEV_CONTAINERS_UNCHANGED=OK
D1X_DB_EPHEMERAL_CLEANUP=DONE
D1X_DB_RESULT=0
D1X_SYNTHETIC_FULL_DB_GATE=PASS
D1X_RESULT=0
D1X_SHELL_RESULT=0
```

Si Caddy API no está disponible, pero la recuperación sintética es correcta, el resultado global será **2 = NO VERIFICADO**, no PASS. No activar la API administrativa o alterar Caddy para hacer pasar la prueba: acordar otro mecanismo de revisión en modo lectura. Si falla un test, no inventar el resultado; conservar marcadores de fase.

## Pendiente incluso con D1-X PASS

- **Visual navegador real:** abrir aplicación Flutter en Chromium/WebKit/Android sobre un entorno controlado y verificar montaje de widgets, navegación, login, menú, calendario y errores de consola; una respuesta HTTP 200 de `index.html` no prueba esto. Ningún test de navegador está incluido en D1-X, y el gate lo marca `D1X_BROWSER_VISUAL_VERIFIED=NO`.
- **Caddy específico del host dev:** la presencia del handler reverse_proxy no demuestra ruta, upstream, headers o certificado de `dev.vencira.es`; revisión comparada y segura aún necesaria.
- **Runbook ejecutable de rollback:** custodia de digests previos API/Web, esquema/versión anterior, instantánea O5 consistente y ensayada en aislamiento, punto de quiescencia/escrituras, pérdida potencial RPO/RTO, reversión de proxy/containers, métricas y postchecks. La restauración sintética de D1-X no reemplaza estos pasos.
- **Promoción DEV** sigue sin autorización; **Android nativo y MFA real** no están avalados por estas pruebas WEB.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_LIVE_RESTORE_EXECUTED=NO
```
