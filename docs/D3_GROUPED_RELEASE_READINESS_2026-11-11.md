# D3 — Prepublicación agrupada VENCIRA (11/11/2026)

**Estado: preparado en main; pendiente de ejecución de operador. No autoriza despliegue.**

## Objetivo

Tras D1-Z→D2-E **6/6 PASS**, no repetir Flutter Web/Django/PG17, ni los test de widgets, salvo regresión material. El siguiente cuello de botella es recuperación operativa. D3 agrupa de manera segura el ensayo que es posible validar sin tocar datos ni contenedores DEV.

## D3-A: restore completo de base sintética + revalidación de runtime

Archivo `scripts/main_d3a_full_pg17_rollback_isolated.sh`. Se comprueba que la rama es `main`, HEAD sincronizado, árbol limpio y la identidad ID:imagen de los tres contenedores DEV. Se crea red Docker **internal-only**, PG17 en **tmpfs** con base `d3a`, y se construye una imagen Django candidata efímera a partir del código de `main`. Se ejecutan `check`, paridad de migraciones `makemigrations --check --dry-run`, y `migrate` solo en el laboratorio.

La fixture se reutiliza de `scripts/main_d2e_seed_synthetic.py` con identidad `d2e-synthetic-...`, una organización, una membresía, un vencimiento falso `D2E-EDIT`, notas `Before D2E`. Se toma `pg_dump -Fc` de **toda la base sintética**, se altera deliberadamente solo la anotación ficticia `AFTER_SNAPSHOT`, se destruye/recrea **exclusivamente la BD d3a efímera**, y se restaura con `pg_restore --exit-on-error`. Se verifica retorno al estado `Before D2E`, recuperación de usuario y membresía, `django check` y `migrate --check`. Trap de cleanup elimina red, contenedor, imagen y secretos temporales. Un guardafrenos confirma contenedores DEV idénticos antes/después. No hay puertos expuestos ni volúmenes persistentes.

**D3-A no verifica** un cambio reversible entre dos imágenes de producción, persistencia en volumen real, restauración desde O5 real, ni rollback de la configuración actual de Caddy. No se le adjudicará ese PASS.

## D3 agrupado: una ejecución

`scripts/main_d3_grouped_release_preflight.sh` comprueba rama/árbol/sintaxis, ejecuta D3-A una sola vez y, si pasa, emite inventario explícito de restricciones operativas. No vuelve a compilar Flutter ni repite D2-E. El indicador `D3_RESULT=0` significa **solo que el preflight agrupado terminó**, no autorización para publicar.

Ejecutar desde Termius:

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d3_grouped_release_preflight.sh
bash scripts/main_d3_grouped_release_preflight.sh
echo "D3_SHELL_RESULT=$?"
```

Esperado, **no verificado**:

```text
D3A_MAIN_CLEAN_SYNC=PASS
D3A_DEV_IDENTITY=PASS
D3A_NETWORK_INTERNAL=PASS
D3A_PG17_TMPFS=PASS
D3A_CANDIDATE_MIGRATIONS=PASS
D3A_SYNTHETIC_FIXTURE=PASS
D3A_FULL_DATABASE_SNAPSHOT=PASS
D3A_SYNTHETIC_FAULT_INJECTED=PASS
D3A_RENEWAL_ROLLBACK=PASS
D3A_AUTH_RESTORE=PASS
D3A_MEMBERSHIP_RESTORE=PASS
D3A_RESTORED_DJANGO_RUNTIME=PASS
D3A_FULL_SYNTHETIC_DB_ROLLBACK_GATE=PASS
D3A_DEV_CONTAINERS_UNCHANGED=OK
D3A_EPHEMERAL_CLEANUP=DONE
D3A_RESULT=0
D3_FULL_SYNTHETIC_DATABASE_RECOVERY=PASS
D3_OPERATIONAL_IMAGE_AND_PERSISTENT_DB_ROLLBACK_VERIFIED=NO
D3_PRODUCTION_CADDY_CONFIG_VERIFIED=NO
D3_PUBLIC_RELEASE_AUTHORIZED=NO
D3_RELEASE_READINESS=GATED
D3_RESULT=0
D3_SHELL_RESULT=0
```

Si falla, se corrige únicamente la causa observada, sin repetir gates D1-Z→D2-E.

## Camino crítico del piloto y lanzamiento

1. **D3-A:** restauración de base completa sintética en PG17 aislado, con prueba de aplicación posterior.
2. **D3-B:** *pendiente diseño y ejecución*: ensayo de rollback de imagen inmutable y BD persistente con backup real O5 en laboratorio separado y evidencias de compatibilidad, sin afectar DEV ni producción. Evitar confundirlo con D3-A.
3. **D3-C:** revisión **read-only** de Caddy real para `dev.vencira.es`, dominios, TLS, cookies y configuración de publicación. La configuración lab de Caddy bajo `d2e-proxy` no acredita configuración real de despliegue.
4. **D3-D:** gate final de seguridad, sesiones, migraciones y release; scope de piloto sin MFA vs producción con MFA deben aprobarse por separado. **No habilitar MFA** ni migraciones live por deducción.

## Estado de autorización

`MFA_RELEASE_AUTHORIZED=NO`

`NO_DEPLOY_NO_LIVE_MIGRATION=1`

`D3_RELEASE_AUTHORIZED=NO`

`D3_DEPLOY_EXECUTED=NO`

`D3_LIVE_MIGRATIONS_EXECUTED=NO`

`D3_LIVE_RESTORE_EXECUTED=NO`

El porcentaje global de VENCIRA no se infiere del 6/6 del tramo anterior. No establecer fecha de producción sin evidencia del rollback operativo y gates de seguridad.


## Actualización: Caddy de DEV por inspección estrictamente read-only

Se añadió `scripts/main_d3c_caddy_readonly_preflight.sh` (commit `b3459035`) al orquestador D3 (commit `cc5daa49`). Comprueba en el **host**, sin leer/imprimir configuración ni certificados:
- Presencia de `/etc/caddy/Caddyfile` y resultado de `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`.
- `systemctl is-active caddy`.
- Conexión a `https://dev.vencira.es/` con TLS validado por curl (sin `-k` ni credenciales), HTTP 200 o redirección estándar.

Si el despliegue usa otra topología (por ejemplo Caddy en contenedor), el preflight informa UNVERIFIED; no inventa una configuración del host. Nunca aplica `reload`, `restart`, modifica Caddyfile, abre puertos, visita endpoints privados ni ejecuta migraciones. Aunque pase, no certifica rutas de producción, dominio `vencira.es`, funcionamiento de MFA ni release.

**La ejecución agrupada continua con D3-A y después D3-C.** D3-C fallido queda explícito como `D3_D3C_CADDY_READONLY_PREFLIGHT=UNVERIFIED`; la salida `D3_RESULT=0` significa únicamente que el orquestador terminó con recuperación DB sintética PASS y declaración de bloqueos, no que Caddy/producción esté autorizado. Los marcadores `D3_PRODUCTION_CADDY_CONFIG_VERIFIED=NO` y `D3_PUBLIC_RELEASE_AUTHORIZED=NO` siguen forzados. Ninguno de los dos scripts se ha ejecutado aún en VPS.


## Primer ensayo D3: fallo de preflight de rama — corregido

El operador ejecutó D3 y obtuvo `D3_MAIN_REQUIRED=FAIL`, `D3_SHELL_RESULT=2`. Ocurrió **antes de iniciar PostgreSQL o comprobaciones de Caddy**; no es un fallo de restauración. La condición anterior rechazaba el checkout local cuando `git branch --show-current` no era `main`. El directorio de validación puede estar en HEAD desacoplado o con otro nombre de rama, pese a señalar exactamente el commit de `origin/main`.

**Correcciones en main:** `03b375bf` (orquestador D3) y `1a602505` (D3-A). Eliminan exclusivamente la comprobación por **nombre de rama**, pero mantienen:
- `HEAD` exactamente idéntico a `refs/remotes/origin/main`.
- `git status --porcelain` vacío (sin cambios rastreados o no rastreados).
- Comprobación de identidad de los tres contenedores DEV y ausencia de deploy/migraciones operativas.

No se crea otra rama ni se ejecutan `checkout`, `reset` o acciones sobre los datos. El nuevo script **no está todavía validado por el operador**. Repetir `git fetch`, `git merge --ff-only origin/main`, `bash scripts/main_d3_grouped_release_preflight.sh` y registrar `D3_SHELL_RESULT`.

Progreso D3: **0 gates verificados; primer intento bloqueado por preflight de rama**. D1-Z→D2-E permanece 6/6 PASS.


## Ejecución validada por operador: D3-A PASS + D3-C PASS (11/11/2026)

El operador ha ejecutado `scripts/main_d3_grouped_release_preflight.sh` y ha aportado logs completos terminados en **`D3_RESULT=0`**; no es una inferencia de scripts sin ejecutar.

**D3-A PASS**: `D3A_MAIN_CLEAN_SYNC=PASS`, `D3A_DEV_IDENTITY=PASS`, `D3A_NETWORK_INTERNAL=PASS`, `D3A_PG17_TMPFS=PASS`, `D3A_CANDIDATE_IMAGE=PASS`, `D3A_CANDIDATE_MIGRATIONS=PASS`, `D3A_SYNTHETIC_FIXTURE=PASS`, `D3A_INITIAL_STATE=PASS`, `D3A_FULL_DATABASE_SNAPSHOT=PASS`, `D3A_SYNTHETIC_FAULT_INJECTED=PASS`, `D3A_RENEWAL_ROLLBACK=PASS`, `D3A_AUTH_RESTORE=PASS`, `D3A_MEMBERSHIP_RESTORE=PASS`, `D3A_RESTORED_DJANGO_RUNTIME=PASS`, `D3A_FULL_SYNTHETIC_DB_ROLLBACK_GATE=PASS`, `D3A_DEV_CONTAINERS_UNCHANGED=OK`, `D3A_EPHEMERAL_CLEANUP=DONE`, `D3A_RESULT=0`. Cobertura: base **sintética completa** en PG17 tmpfs; no O5 real ni volumen persistente, ni rollback de imagen operativa.

**D3-C PASS**: `D3C_CADDYFILE_PRESENT=YES`, `D3C_CONFIG_SYNTAX=PASS`, `D3C_SERVICE_ACTIVE=PASS`, `D3C_DEV_HTTPS_CERT_AND_CONNECT=PASS`, `D3C_REAL_CADDY_SYNTAX_AND_SERVICE_VERIFIED=PASS`, `D3C_RESULT=0`. Es verificación del **Caddy activo en host y TLS de dev.vencira.es**, exclusivamente de solo lectura y sin reload. **No** certifica configuración/enrutamiento del dominio público de producción `vencira.es`: `D3C_PRODUCTION_DOMAIN_ROUTING_VERIFIED=NO`.

**Orquestador**: `D3_D3A_FULL_DATABASE_ROLLBACK_PASS=YES`, `D3_D3C_CADDY_READONLY_PREFLIGHT=PASS`, `D3_FULL_SYNTHETIC_DATABASE_RECOVERY=PASS`, `D3_RESULT=0`. Se mantiene `D3_OPERATIONAL_IMAGE_AND_PERSISTENT_DB_ROLLBACK_VERIFIED=NO`, `D3_PRODUCTION_CADDY_CONFIG_VERIFIED=NO`, `D3_MFA_RELEASE_AUTHORIZED=NO`, `D3_PUBLIC_RELEASE_AUTHORIZED=NO`, `D3_RELEASE_READINESS=GATED`. No se ha desplegado ni migrado live.

**Balance de gates acotados:** 6 PASS D1-Z→D2-E más D3-A y D3-C = **8/8 PASS** de los gates ejecutados en ese tramo. No cuantifica el progreso global de VENCIRA.

**Siguiente camino crítico y aceleración:** no repetir D2-E/D3-A/D3-C. Preparar D3-B: recuperación conjunta de imagen candidata anterior y backup O5 **en laboratorio aislado**, restaurando a almacenamiento efímero y sin leer secretos en logs ni modificar servicio DEV; después revisar enrutamiento y autorización de producción. Una prueba sintética de base NO es evidencia de backup O5 real.
