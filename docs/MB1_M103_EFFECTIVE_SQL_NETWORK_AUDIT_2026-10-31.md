# VENCIRA — M1-03: auditoría agrupada de privilegios SQL y acceso por red

Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## Decisión

El censo histórico M1-03 YA había medido: dos proyectos Docker, seis contenedores, servicios API/DB, redes publicadas, procesos del host y timers, definición efectiva de systemd/cron, 76 archivos/264 llamadas AST y 131 candidatos P0, además de roles PG17 agregados. **No repetir** censos por inercia.

El trabajo todavía no resuelto era comprobar privilegios **efectivos** para modificar PostgreSQL y qué contenedores concretos comparten las redes de cada DB, además de actualizar el gate B18K tras la corrección del commit SQL ambiguo.

## Entrega conjunta — ejecutada con resultado 0 (véase evidencia)

- `scripts/audit_mb1_m103_effective_pg_network_readonly.py` (commit `2fd101a`): consulta exclusivamente catálogos SQL y metadatos Docker. Se fija a `vencira_localcheck/db` y `vencira_preview/db`, exige las dos instancias distintas y que los datos puedan inspeccionarse por completo. Para cada proyecto da contadores agregados de roles login, superusuarios, DDL, replicación, permisos CREATE sobre esquema public, roles con alguna capacidad DML en tablas public, sesiones de clientes y transacciones activas durante la consulta, normas pg_hba host/trust/amplias/incorrectas, y miembros de red del mismo proyecto, de otro proyecto, sin etiqueta o privilegiados. NO publica nombres de roles, IDs, IPs, redes, rutas, SQL de negocio ni secretos. Un conteo no garantiza rutas autorizadas ni excluye root/Docker host.
- `scripts/test_mb1_m103_effective_pg_network_readonly.py` (commit `19b5641`): diez pruebas puras contra resultados inesperados, negativos, booleanos, redes ausentes y nodos sin nombre; ningún acceso al servidor.
- `scripts/gate_b18k_critical_primitive_calls.py` actualizado (commit `f6f8c2f`): elimina de la lista permitida la llamada `discard_quarantine` desde intake tras el fix de ACK ambiguo, la prohíbe expresamente, e incorpora una ruta `stage_private_attachment` exclusivamente de ensayo y bajo entorno test. Sigue limitado a llamadas AST directas; aliases, imports dinámicos y escrituras externas no están cubiertos. No ampliar allowlist por un FAIL sin examinar cada ruta.
- `scripts/validate_mb1_m103_grouped_effective_access.sh` (commit `9c3da31`): UN comando para sintaxis Python, diez tests puros, gate estático B18K y consulta efectiva SQL/red. La única etapa elevada usa `sudo` pero ejecuta solo lectura `SELECT`, `docker ps`, `docker inspect` y `docker network inspect`. No entra en ningún contenedor ajeno ni modifica roles, permisos, red, base, Docker ni O5.

## Comando de reproducción (ya ejecutado por el operador)

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/validate_mb1_m103_grouped_effective_access.sh
bash scripts/validate_mb1_m103_grouped_effective_access.sh
echo "MB1_M103_GROUP_EXIT_CODE=$?"
```

Salida esperada si no hay cambios inesperados:

- `Ran 10 tests`, `OK`, `MB1_M103_PURE_CONTRACTS=OK`.
- `B18K_FORBIDDEN_DESTRUCTIVE_CALLS=0`, `B18K_UNEXPECTED_CALLSITE_PAIRS=0`, `B18K_STATIC_GATE=OK`, `MB1_M103_CRITICAL_SOURCE_CALLS=OK`.
- Para **ambos** proyectos, contadores de miembros y roles por clase; `MB1_M103_EFFECTIVE_ACCESS_INVENTORY=OK`.
- `MB1_M103_PG_NETWORK_READONLY=OK`, `MB1_M103_GROUP_DONE=OK`, `MB1_M103_GROUP_RESULT=0`, `MB1_M103_GROUP_EXIT_CODE=0`.

Cualquier anomalía estructural, ausencia de contenedor, error SQL, acceso denegado, ruta crítica no autorizada o norma de pg_hba mal formada provoca fallo de auditoría (sin cambios). Es posible que las capacidades elevadas sean mayores de cero; eso es evidencia de un **riesgo a gestionar**, no error del ensayo ni permiso para entrar en mantenimiento.

## Límites y aceptación M1-03

**No declarar M1-03 cerrado** por un `RESULT=0`: todavía hay 131 rutas P0 sin revisión exhaustiva y no se han excluido accesos de superusuario, root del host, otros clientes de la red Docker, scripts externos o escrituras por filesystem. Un inventario de miembros de la red y roles PG no demuestra que se pueda impedir su escritura.

Siguiente decisión tras resultado: clasificar de manera argumentada **solo los mutadores efectivos pendientes**, identificar propietarios y autorización SQL de cada actor, diseñar su mecanismo de exclusión antes de un freeze. Si la infraestructura real revela acceso compartido inesperado, remediar primero en clon; ninguna intervención automática en DEV.

```text
MB1_M103_WRITER_ROUTES=INVENTORY_NOT_FULLY_REVIEWED
MB1_M103_EXTERNAL_SQL_ACCESS=NOT_EXCLUDED
MB1_M103_PRIVILEGED_HOST_WRITERS=NOT_EXCLUDED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Evidencia aportada por operador — M1-03 auditoría agrupada PASS de inventario (31/10/2026)

`MB1_M103_EFFECTIVE_ACCESS_INVENTORY=OK`, `MB1_M103_PG_NETWORK_READONLY=OK`, `MB1_M103_GROUP_DONE=OK`, `MB1_M103_GROUP_PHASE=DONE`, `MB1_M103_GROUP_RESULT=0`. Por los gates de `set -Eeuo pipefail`, este resultado confirma que las comprobaciones previas del ejecutor no interrumpieron el flujo; la transcripción enviada empieza en las métricas SQL y no contiene el número exacto de pruebas ni `MB1_M103_GROUP_EXIT_CODE`, que no se deben inventar.

| Métrica | `vencira_localcheck` | `vencira_preview` |
|---|---:|---:|
| Redes DB | 1 | 1 |
| Contenedores miembros de red | 3 | 3 |
| Miembros mismo proyecto | 3 | 3 |
| Otros proyectos / sin etiqueta / privilegiados | 0 / 0 / 0 | 0 / 0 / 0 |
| Roles login | 1 | 1 |
| Superusuarios login | 1 | 1 |
| Roles login con DDL, CREATE public, DML, replicación | 1 en cada categoría | 1 en cada categoría |
| Sesiones adicionales / transacciones activas instantáneas | 0 / 0 | 0 / 0 |
| Reglas HBA tipo host | 5 | 5 |
| Reglas `trust` (TODAS las clases local+host) | 6 | 6 |
| Reglas host con dirección amplia | 1 | 1 |
| Reglas HBA inválidas | 0 | 0 |

**Interpretación de seguridad:** ambos PostgreSQL operan con un solo rol habilitado para login y ese rol tiene privilegios de superusuario; aumenta el alcance de cualquier compromiso de sus credenciales. No está probado aún que el proceso API use directamente ese rol (hay que comparar configuración efectiva sin exponer nombres ni contraseñas). Seis reglas `trust` incluyen potencialmente reglas de socket/local; no puede afirmarse que las seis permitan acceso remoto sin contraseña. La regla de host amplia NO indica por sí sola `trust`; puede requerir `scram-sha-256` y estar confinada a la red Docker. **No calificar como exposición pública ni alterar pg_hba/conf mientras falte clasificación.** La ausencia puntual de conexiones y miembros foráneos no excluye root, Docker host, conexiones efímeras o futuras.

El operador también recibió `MB1_M103_WRITER_ROUTES=INVENTORY_NOT_FULLY_REVIEWED`, `MB1_M103_EXTERNAL_SQL_ACCESS=NOT_EXCLUDED`, `MB1_M103_PRIVILEGED_HOST_WRITERS=NOT_EXCLUDED`, `MB1_M103_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **M1-03 continúa abierto.** Siguiente auditoría única: cruzar clases local/host, autenticación de regla amplia y privilegio de la identidad efectiva de API. Sin reejecutar censo de 10 tests.

## Segunda pasada focalizada: HBA local frente a host + identidad real de API (pendiente)

La primera auditoría reveló `LOGIN_ROLES=1` y `SUPERUSER_LOGIN=1` tanto en localcheck como en preview; además `HBA_TRUST_RULES=6` (local+host) y `HBA_UNRESTRICTED_ADDRESS_RULES=1` (método aún desconocido). Antes de recomendar endurecimiento **es imprescindible clasificar dónde aparece `trust` y si la API usa efectivamente el superusuario**.

Nuevo código **solo lectura**:
- `scripts/audit_mb1_m103_hba_and_app_identity_readonly.py` (`7daf9af`) consulta `pg_hba_file_rules` y separa reglas `local/trust`, `host/trust`, `host` con dirección amplia y sus métodos: `trust`, `scram-sha-256`, `md5`, `password` y otros. Compara internamente las variables de conexión `POSTGRES_USER` de API y DB obtenidas mediante `docker inspect`, y comprueba si el rol de conexión de DB es superusuario; **no imprime usuarios, variables, contraseñas, direcciones ni reglas**. Un `API_USES_DB_SUPERUSER=YES` evidencia coincidencia de identidad y privilegio del rol observado; `NOT_MATCHED/UNKNOWN` requiere análisis posterior, no declara seguridad.
- `scripts/test_mb1_m103_hba_and_app_identity_readonly.py` (`36f14d3`): 11 pruebas puras de clasificación, recuentos inconsistentes, datos ausentes y comparación de identidad.
- `scripts/validate_mb1_m103_hba_identity_focused.sh` (`3ed78ef`): ejecuta esas 11 pruebas y una única lectura agregada SQL+Docker por cada proyecto. **No repite** las 10 pruebas ni los censos anteriores.

### Comando único en el VPS (no ejecutado aún)

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/validate_mb1_m103_hba_identity_focused.sh
bash scripts/validate_mb1_m103_hba_identity_focused.sh
echo "MB1_M103_DETAIL_EXIT_CODE=$?"
```

Esperado: `Ran 11 tests`, `OK`, `MB1_M103_DETAIL_TESTS=OK`, `MB1_M103_HBA_IDENTITY_DETAIL=OK`, `MB1_M103_DETAIL_HBA_API_IDENTITY=OK`, `MB1_M103_DETAIL_DONE=OK`, `MB1_M103_DETAIL_RESULT=0` y `MB1_M103_DETAIL_EXIT_CODE=0`.

La presencia de reglas host con `trust` puede ser relevante incluso sin puertos publicados: permite autenticación sin contraseña a los clientes a los que alcance esa regla. Si sólo aparece `trust` local y la regla amplia usa `scram-sha-256`, el hallazgo cambia de naturaleza, aunque el uso de un superusuario por la API siga siendo un riesgo de mínimo privilegio. **No ajustar HBA, usuarios ni Docker en DEV en esta fase.**

Persisten `MB1_M103_WRITER_ROUTES=INVENTORY_NOT_FULLY_REVIEWED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`. M1-03 permanece abierto hasta verificar y revisar todas las rutas de escritura efectivas, incluidos accesos externos y usuarios privilegiados.
