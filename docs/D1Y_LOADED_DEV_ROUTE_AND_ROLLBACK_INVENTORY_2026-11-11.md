# VENCIRA — D1-Y: rutas efectivas DEV y artefactos de recuperación (solo lectura)

Fecha: 11/11/2026. Rama única `main`. **Implementado, pendiente de Termius. No declarar PASS.**

## Motivación

Los ensayos D1-N a D1-X han verificado restauración histórica O5 y migraciones en laboratorio, Django/Flutter, HTTPS con Caddy sintético, base de datos efímera y configuración HTTP cargada en el Caddy operativo. Sigue sin demostrarse que la configuración cargada contenga específicamente las reglas de `dev.vencira.es`, y que estén preparados todos los artefactos necesarios para restaurar rápidamente API, web y base de datos tras una promoción.

## Una ejecución con dos subgates de solo lectura

`scripts/main_d1y_consolidated_readonly.sh`:

1. **Ruta de Caddy cargada** — `scripts/main_d1y_caddy_dev_route_readonly.py` consulta solo `GET http://127.0.0.1:2019/config/` con proxy deshabilitado. Inspecciona internamente la estructura de rutas y `match.host`, busca `dev.vencira.es` y un `reverse_proxy` dentro de ese alcance, sin imprimir JSON, upstreams, host paths, cookies o credenciales. Una regla con matchers adicionales o selección de ruta compleja no garantiza que una solicitud concreta llegue a ese upstream, por lo que el resultado **solo acredita presencia estructural**. Nunca comprueba certificado HTTPS, accesibilidad del backend, encabezados efectivos ni frontend SPA real. Si no identifica inequívocamente la ruta, devuelve `NOT_VERIFIED` en lugar de fabricar un PASS.
2. **Inventario de recuperación de imágenes en ejecución** — `scripts/main_d1y_rollback_artifacts_readonly.py` consulta `docker inspect` para los tres contenedores del proyecto `vencira_localcheck`, exige que estén en marcha y que sus imágenes inmutables estén disponibles localmente con `docker image inspect`. Comprueba que la base PostgreSQL utiliza un volumen Docker nombrado en `/var/lib/postgresql/data`. **No comprueba ni declara custodia de imágenes anteriores**, porque todavía no hay un manifiesto verificado de la versión previa ni un punto de recuperación congelado.

No hay Docker create/run, cambios en Caddy, conexión a PostgreSQL, migraciones, `pg_restore`, backup O5, deploy, cambios sobre volúmenes o credenciales. Solo se leen metadatos.

## Comando único Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash scripts/main_d1y_consolidated_readonly.sh
echo "D1Y_SHELL_RESULT=$?"
```

Se buscarán `D1Y_SOURCE_AST=PASS`, `D1Y_CADDY_DEV_HOST_MATCH_PRESENT=YES`, `D1Y_CADDY_DEV_HOST_SCOPED_PROXY_PRESENT=YES`, `D1Y_DEV_ROUTE_GATE=PASS`, imágenes locales disponibles para API/DB/Web, volumen nombrado PASS y `D1Y_RESULT=0`. Si devuelve 2, equivale a **no verificado**, no a caída de servicio: revisar el mapa real del proxy antes de modificar el analizador. No se debe cambiar la configuración Caddy para satisfacer un gate.

## Lo que NO verifica D1-Y

- No valida los destinos de cada `reverse_proxy`, ni que el host realmente enrute a Web/API correctos en todos los paths.
- No conserva imágenes anteriores ni comprueba rollback operativo. Se necesita inventario completo de release anterior y destino de restauración; un volumen nombrado presente no es backup.
- No realiza prueba visual en navegador (Flutter rendering, navegación, login, calendario). El resultado de D1-W sobre archivos JS 200 no sustituye esa prueba.
- No valida rollback con escrituras posteriores, RPO/RTO ni recuperabilidad de la sesión en un navegador real. Antes de promover, se exige plan y aprobación expresa.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_LIVE_RESTORE_EXECUTED=NO
```


## Defensa de interpretación de hosts

Antes de consultar Caddy, `main_d1y_consolidated_readonly.sh` ejecuta `python3 -m unittest discover -s scripts -p 'test_main_d1y_caddy_dev_route.py' -q`. El módulo `scripts/test_main_d1y_caddy_dev_route.py` comprueba una ruta explícita DEV, una ruta ajena, una subruta DEV y un matcher anidado de dominio ajeno que no debe heredarse como ruta DEV. Marcador previsto `D1Y_ROUTE_UNIT_TESTS=PASS`. Publicado en `main`, **todavía no ejecutado**; no atribuir PASS previo.


## Incidencia de preflight (11/11/2026)

La primera ejecución en Termius se detuvo **antes de inspeccionar Caddy o Docker**: `SyntaxError: unexpected character after line continuation character` en `scripts/main_d1y_caddy_dev_route_readonly.py`, línea 54. El código fuente tenía secuencias literales `\\n` dentro de la expresión de `host_scope`. `D1Y_SHELL_RESULT=1`; no hay prueba de ruta ni inventario en esta ejecución. Corrección publicada directamente en `main`: commit `220e712e`, sustituyendo los caracteres escapados por saltos de línea reales.

La guardia AST detectó el problema antes de cualquier consulta o mutación. Tras sincronizar `main` repetir únicamente `bash scripts/main_d1y_consolidated_readonly.sh`. **D1-Y sigue sin validar.**


## Validación del operador — 11/11/2026: D1-Y PASS

Tras corregir el error sintáctico de preflight, el operador confirmó:

```text
D1Y_SOURCE_AST=PASS
D1Y_ROUTE_UNIT_TESTS=PASS
D1Y_CADDY_READ_ONLY=YES
D1Y_CADDY_CONFIG_CONTENT_PRINTED=NO
D1Y_CADDY_MUTATIONS_EXECUTED=NO
D1Y_CADDY_LOADED_CONFIG_AVAILABLE=YES
D1Y_CADDY_DEV_HOST_MATCH_PRESENT=YES
D1Y_CADDY_DEV_HOST_SCOPED_PROXY_PRESENT=YES
D1Y_CADDY_RESULT=0
D1Y_DEV_ROUTE_GATE=PASS
D1Y_ROLLBACK_API_RUNNING_IMAGE_PRESENT=PASS
D1Y_ROLLBACK_DB_RUNNING_IMAGE_PRESENT=PASS
D1Y_ROLLBACK_WEB_PREVIEW_RUNNING_IMAGE_PRESENT=PASS
D1Y_ROLLBACK_DB_NAMED_VOLUME_PRESENT=PASS
D1Y_ROLLBACK_INVENTORY_GATE=PASS
D1Y_READONLY_GATE=PASS
D1Y_RESULT=0
```

Conclusión: **D1-Y PASS en estructura de reglas Caddy cargadas para `dev.vencira.es` y disponibilidad local de imágenes actualmente en ejecución**, con el volumen persistente PostgreSQL presente. No consta marcador independiente `D1Y_SHELL_RESULT` numérico. Una línea del log concatena `D1Y_ROLLBACK_OPERATIONAL_ROLLBACK_VERIFIED=NO` con `D1Y_ROLLBACK_RESULT=0`; las barreras expresas `D1Y_OPS_ROLLBACK_VERIFIED=NO` y `D1Y_READONLY_GATE=PASS` son inequívocas.

**NO verificado y no autorizado:** upstreams reales de cada ruta, certificado TLS host en este gate, navegación visual, imágenes de releases anteriores, conjunto completo de artefactos de reversión, política de escrituras posactualización o rollback operativo. El operador informó de dos solicitudes de contraseña sudo con errores iniciales, pero terminó los inspect correctamente y sin cambios operativos. `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
