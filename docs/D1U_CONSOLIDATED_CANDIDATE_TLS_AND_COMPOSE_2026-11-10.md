# VENCIRA — D1-U consolidado: Compose policy + TLS candidato aislado

Fecha: 10/11/2026. Destino único de código: `main`. **NO EJECUTADO TODAVÍA EN VPS. No declarar PASS.**

## Objetivo

Sustituir microinventarios por un solo bloque que comprueba: (a) semántica básica del Compose real de DEV sin publicar su configuración y (b) HTTPS funcional de la imagen candidata Django con PostgreSQL17 sintético en contenedores separados. Evitar cualquier cambio en DEV, incluso migraciones. **La terminación TLS del laboratorio la realiza Python WSGI, NO Caddy.** Por ello el gate **NO** certifica el nuevo candidato detrás de Caddy operativo, ni prueba la integración Flutter+Nginx.

## Ejecutor

`scripts/main_d1u_consolidated_gate.sh` agrupa:

1. `scripts/main_d1u_compose_semantics_readonly.py`: usa etiquetas `docker inspect` para recuperar las ubicaciones exactas de los dos manifiestos, llama a `docker compose config --no-interpolate --no-env-resolution --format json` en memoria y exige los servicios `api`, `db`, `web_preview`, sin privilegios ni namespaces de host. Exige declaración de volumen para DB. No imprime valores, rutas, puertos, digest, variables de entorno o contenido. Si el Compose usa otro modelo válido, falla antes de clasificarlo como PASS y hay que revisar el contrato, sin relajar controles ciegamente. Esta lectura **no valida** configuración efectiva de Caddy ni backup de imágenes.
2. `scripts/main_d1u_candidate_https_pg17_isolated.sh`: identifica los contenedores DEV, construye imagen Django de `main` y crea red Docker interna, PG17 con PGDATA `tmpfs`, variables totalmente sintéticas y certificado localhost de un día (sin claves operativas). Aplica migraciones **solo a DB sintética**. Lanza un servidor WSGI HTTPS aislado sin publicar puertos, con rootfs readonly, y consulta desde el propio contenedor por URL `https://localhost:18443`.
3. `scripts/main_d1u_https_candidate_lab.py`: verifica usando CA sintética explícitamente confiada endpoints health, ready, login, CSRF, rechazo anónimo de me y rutas nativas de muestra 404; **niega** conexión a nombre de host 127.0.0.1 incompatible con SAN localhost y **niega** CA no confiable. El proceso de prueba no imprime respuestas JSON ni datos.
4. `trap EXIT` en el shell de laboratorio destruye contenedores, red, imagen temporal y secretos sintéticos; comprueba que IDs e imágenes de los tres contenedores DEV existentes no hayan cambiado.

Los tres scripts son una primera implementación sin ejecución comprobada. Ante fallo, `D1U_RESULT=0` **no** aparecerá. No suprimir errores ni atribuir PASS a los scripts intermedios.

## Ejecutar en Termius (única validación del bloque)

Revisar el código con antelación antes de ejecutar con sudo: usa Docker y crea recursos **solo de laboratorio**. Necesita Docker, sudo, openssl, Python y acceso a imágenes ya existentes o registry para build.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
git status --short
bash scripts/main_d1u_consolidated_gate.sh
echo "D1U_SHELL_RESULT=$?"
```

Criterios de aceptación:

```text
D1U_COMPOSE_SERVICE_NAMES=PASS
D1U_COMPOSE_API_STATIC_POLICY=PASS
D1U_COMPOSE_DB_STATIC_POLICY=PASS
D1U_COMPOSE_WEB_PREVIEW_STATIC_POLICY=PASS
D1U_COMPOSE_SEMANTICS_GATE=PASS
D1U_DEV_IDENTITY=PASS
D1U_INTERNAL_NETWORK=PASS
D1U_PG17_TMPFS=PASS
D1U_CANDIDATE_IMAGE=PASS
D1U_SYNTHETIC_MIGRATIONS=PASS
D1U_CANDIDATE_CONTAINER_INTERNAL=PASS
D1U_HTTPS_CANDIDATE=PASS
D1U_TRUSTED_CERT_AND_HOSTNAME=PASS
D1U_UNTRUSTED_AND_HOSTNAME_NEGATIVE=PASS
D1U_CANDIDATE_HTTPS_LAB_GATE=PASS
D1U_DEV_CONTAINERS_UNCHANGED=OK
D1U_EPHEMERAL_CLEANUP=DONE
D1U_CANDIDATE_TLS_GATE=PASS
D1U_RESULT=0
D1U_SHELL_RESULT=0
```

El resultado de este bloque **no incluye necesariamente la compilación web Flutter nueva**; eso quedó probado anteriormente en D1-O. El código web servido a través de Nginx+Caddy real queda pendiente.

## Plan de rollback: situación y secuencia propuesta, NO ejecutable todavía

D1-R constató un volumen persistente Docker para PostgreSQL y ningún volumen o bind mount en API/Web. Conservar imagen API/Web anterior y sus digests **antes** de cualquier upgrade; inventariar y verificar origen y custodia del volumen DB, imagen PostgreSQL anterior, ficheros Compose/Caddy efectivos y nuevos artefactos frontend. Sin destruir ni renombrar el volumen original, preparar snapshot O5 con punto consistente y restauración aislada actualizada. Preparar ventana con control de escrituras, responsables y reversión de API/Web; si las migraciones transforman datos, decidir explícitamente entre rollback de schema y restauración de backup, con evaluación de escrituras posteriores y RPO/RTO.

Antes de solicitar autorización de promoción deben verificarse el HTTPS del candidato servido por el **proxy equivalente a Caddy real**, el artefacto Flutter Web, las sesiones/CSRF reales y autorización de adjuntos; así como el runbook de reversión y observabilidad post-release. **D1-U no prueba rollback**, por lo que nunca declara apto para despliegue.

## Política de seguridad invariable

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```

D1-N/O/P/Q/R/S/T acreditan su alcance previo, no una certificación única de release. No habilitar bearer nativo, endpoints candidatos ni MFA operativa.


## Primer ensayo del operador y corrección — 10/11/2026

El primer ensayo del ejecutor consolidado terminó **FAIL**, sin tocar DEV:

```text
D1U_COMPOSE_SERVICE_NAMES=PASS
D1U_COMPOSE_API_STATIC_POLICY=PASS
D1U_COMPOSE_DB_STATIC_POLICY=PASS
D1U_COMPOSE_WEB_PREVIEW_STATIC_POLICY=PASS
D1U_COMPOSE_SEMANTICS_GATE=PASS
D1U_DEV_IDENTITY=PASS
D1U_INTERNAL_NETWORK=PASS
D1U_PG17_TMPFS=PASS
D1U_CANDIDATE_IMAGE=PASS
D1U_DEV_CONTAINERS_UNCHANGED=OK
D1U_EPHEMERAL_CLEANUP=DONE
D1U_RESULT=1
D1U_CANDIDATE_TLS_GATE=FAIL
```

**Causa exacta:** el ejecutor `main_d1u_candidate_https_pg17_isolated.sh` contenía el texto literal `\\n#` al final de la línea `chmod`, por lo que Bash interpretaba `server.pemn#` y las palabras del comentario como argumentos de `chmod`. El primer ensayo se abortó antes de arrancar el servidor TLS. El script tampoco exportaba explícitamente `DJANGO_SETTINGS_MODULE` al ejecutar la aplicación WSGI independiente. El commit **`e0a902c6`** corrige ambos defectos sin alterar la configuración de DEV.

**Estado actual D1-U: COMPOSE PASS / HTTPS todavía pendiente de validación.** No repetir D1-N/O/P/Q/R/S/T. Repetir el bloque D1-U únicamente tras sincronizar `main`, con preflight `bash -n`:

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d1u_consolidated_gate.sh scripts/main_d1u_candidate_https_pg17_isolated.sh
bash scripts/main_d1u_consolidated_gate.sh
echo "D1U_SHELL_RESULT=$?"
```

No afirmar `D1U_RESULT=0` ni `D1U_CANDIDATE_TLS_GATE=PASS` hasta disponer de su salida real. El marcador `D1U_SHELL_RESULT` no consta en el primer ensayo. El comando vuelve a comprobar el subgate Compose porque es parte del ejecutor consolidado; no representa trabajo nuevo.


## Segundo ensayo del operador y corrección de arranque WSGI — 10/11/2026

Tras corregir el `chmod`, el operador comunicó `D1U_COMPOSE_SEMANTICS_GATE=PASS`, `D1U_DEV_IDENTITY=PASS`, `D1U_INTERNAL_NETWORK=PASS`, `D1U_PG17_TMPFS=PASS`, `D1U_CANDIDATE_IMAGE=PASS`, `D1U_SYNTHETIC_MIGRATIONS=PASS` y `D1U_CANDIDATE_CONTAINER_INTERNAL=PASS`, pero `D1U_HTTPS_CANDIDATE=FAIL`, `D1U_RESULT=6`, `D1U_CANDIDATE_TLS_GATE=FAIL`. La limpieza quedó `DONE` y los contenedores DEV `UNCHANGED=OK`.

**Defecto probable identificado en código:** el servidor WSGI se iniciaba ejecutando `python /opt/d1u.py` mientras los módulos Django están en `/app` dentro de la imagen (`WORKDIR /app`). Python ante un script de `/opt` no garantiza que añada `/app` a `sys.path`, por lo que `from django.core.wsgi import get_wsgi_application` podía fallar al importar `config.settings`. No hay logs del contenedor que demuestren inequívocamente esta causa, así que se califica como **hipótesis fundada**, no diagnóstico confirmado.

Corrección publicada en `main`: `scripts/main_d1u_https_candidate_lab.py` inserta `/app` en el path de importación del servidor y ahora registra solo el índice del caso fallido y su código HTTP si procede (commit `c4a80922`). El orquestador separa la comprobación de que el contenedor siga vivo, la apertura del socket TLS y una única prueba completa posterior, con marcadores sanitizados `D1U_HTTPS_SERVER_RUNNING`, `D1U_HTTPS_SERVER_READY` y `D1U_HTTPS_CONTRACT_PROBE` (commit `da10e784`). No imprime cuerpos de respuestas ni logs del servidor.

**Resultado actual:** COMPOSE PASS / TLS pendiente de nuevo ensayo. No afirmar `D1U_CANDIDATE_TLS_GATE=PASS` hasta disponer de evidencia. Para reejecutar, sincronizar `main` y usar el comando D1-U documentado anteriormente. No requiere repetir gates D1-N a D1-T.


## Tercer intento — fallo de arranque confirmado por revisión de fuente (10/11/2026)

El operador obtuvo `D1U_HTTPS_SERVER_RUNNING=FAIL`, `D1U_RESULT=6` después de `D1U_CANDIDATE_CONTAINER_INTERNAL=PASS`. La inspección directa de `scripts/main_d1u_https_candidate_lab.py` reveló **secuencias literales `\\n` fuera de una cadena**, insertadas en el cuerpo de `serve()` entre comentario, `sys.path.insert` y `from django.core.wsgi`. Constituyen un **SyntaxError** al interpretar el fichero y explican que el proceso principal termine inmediatamente; no hace falta inferir un error de CA ni de red. La evidencia de salida no incluye traceback, pero el defecto sintáctico es comprobable en el código del commit anterior.

Correcciones en `main`:
- `9f0019dd`: sustitución de las secuencias incorrectas por saltos de línea reales en el script Python.
- `d9e4eb49`: en el ejecutor consolidado se incluye preflight con `ast.parse` de los dos scripts Python y `bash -n` de los dos Bash **antes de iniciar la revisión Compose o el laboratorio**.

No confundir la corrección publicada con ejecución validada. D1-U sigue **TLS PENDIENTE** hasta obtener `D1U_CANDIDATE_TLS_GATE=PASS`, `D1U_RESULT=0` y `D1U_SHELL_RESULT=0`. No repetir controles previos D1-N a D1-T.


## Resultado final del laboratorio — 10/11/2026

**D1-U PASS en su alcance de semántica básica Compose y HTTPS Django sintético.** El operador ha comunicado:

```text
D1U_PYTHON_SYNTAX_PREFLIGHT=PASS
D1U_BASH_SYNTAX_PREFLIGHT=PASS
D1U_COMPOSE_SERVICE_NAMES=PASS
D1U_COMPOSE_API_STATIC_POLICY=PASS
D1U_COMPOSE_DB_STATIC_POLICY=PASS
D1U_COMPOSE_WEB_PREVIEW_STATIC_POLICY=PASS
D1U_COMPOSE_DB_VOLUME_DECLARED=YES
D1U_COMPOSE_SEMANTICS_GATE=PASS
D1U_DEV_IDENTITY=PASS
D1U_INTERNAL_NETWORK=PASS
D1U_PG17_TMPFS=PASS
D1U_CANDIDATE_IMAGE=PASS
D1U_SYNTHETIC_MIGRATIONS=PASS
D1U_CANDIDATE_CONTAINER_INTERNAL=PASS
D1U_HTTPS_SERVER_READY=PASS
D1U_CANDIDATE_TLS_VERIFIED=PASS
D1U_CANDIDATE_HTTPS_HTTP_CONTRACT=PASS
D1U_HOSTNAME_MISMATCH_DENIED=PASS
D1U_UNTRUSTED_CA_DENIED=PASS
D1U_HTTPS_CONTRACT_PROBE=PASS
D1U_HTTPS_CANDIDATE=PASS
D1U_CANDIDATE_HTTPS_LAB_GATE=PASS
D1U_DEV_CONTAINERS_UNCHANGED=OK
D1U_EPHEMERAL_CLEANUP=DONE
D1U_CANDIDATE_TLS_GATE=PASS
D1U_RESULT=0
```

El log recibido no contiene `D1U_SHELL_RESULT` con valor numérico independiente; el resultado `D1U_RESULT=0` del ejecutor consolidado sí consta. Estos marcadores corresponden a una **certificación de laboratorio con servidor TLS WSGI sintético, no del Caddy real**. También constan expresamente:

```text
D1U_CADDY_CANDIDATE_VERIFIED=NO
D1U_ROLLBACK_VERIFIED=NO
D1U_COMPOSE_CADDY_EFFECTIVE_CONFIG_VERIFIED=NO
D1U_CADDY_OPERATIVE_CONFIG_REVIEW=NOT_RUN
D1U_ROLLBACK_PRACTICED=NO
D1U_DEPLOY_EXECUTED=NO
D1U_LIVE_MIGRATIONS_EXECUTED=NO
```

**Próximo bloque concentrado:** Caddy candidato en red aislada, integrado con el artefacto web y HTTP/CSRF; plan de rollback verificable para imágenes y volumen PostgreSQL antes de considerar una futura promoción DEV. Mantener guardas y no interpretar D1-U como autorización de release.
