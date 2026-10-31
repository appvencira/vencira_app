# VENCIRA — M1-03: auditoría agrupada de privilegios SQL y acceso por red

Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## Decisión

El censo histórico M1-03 YA había medido: dos proyectos Docker, seis contenedores, servicios API/DB, redes publicadas, procesos del host y timers, definición efectiva de systemd/cron, 76 archivos/264 llamadas AST y 131 candidatos P0, además de roles PG17 agregados. **No repetir** censos por inercia.

El trabajo todavía no resuelto era comprobar privilegios **efectivos** para modificar PostgreSQL y qué contenedores concretos comparten las redes de cada DB, además de actualizar el gate B18K tras la corrección del commit SQL ambiguo.

## Entrega conjunta nueva — PENDIENTE de ejecutar

- `scripts/audit_mb1_m103_effective_pg_network_readonly.py` (commit `2fd101a`): consulta exclusivamente catálogos SQL y metadatos Docker. Se fija a `vencira_localcheck/db` y `vencira_preview/db`, exige las dos instancias distintas y que los datos puedan inspeccionarse por completo. Para cada proyecto da contadores agregados de roles login, superusuarios, DDL, replicación, permisos CREATE sobre esquema public, roles con alguna capacidad DML en tablas public, sesiones de clientes y transacciones activas durante la consulta, normas pg_hba host/trust/amplias/incorrectas, y miembros de red del mismo proyecto, de otro proyecto, sin etiqueta o privilegiados. NO publica nombres de roles, IDs, IPs, redes, rutas, SQL de negocio ni secretos. Un conteo no garantiza rutas autorizadas ni excluye root/Docker host.
- `scripts/test_mb1_m103_effective_pg_network_readonly.py` (commit `19b5641`): diez pruebas puras contra resultados inesperados, negativos, booleanos, redes ausentes y nodos sin nombre; ningún acceso al servidor.
- `scripts/gate_b18k_critical_primitive_calls.py` actualizado (commit `f6f8c2f`): elimina de la lista permitida la llamada `discard_quarantine` desde intake tras el fix de ACK ambiguo, la prohíbe expresamente, e incorpora una ruta `stage_private_attachment` exclusivamente de ensayo y bajo entorno test. Sigue limitado a llamadas AST directas; aliases, imports dinámicos y escrituras externas no están cubiertos. No ampliar allowlist por un FAIL sin examinar cada ruta.
- `scripts/validate_mb1_m103_grouped_effective_access.sh` (commit `9c3da31`): UN comando para sintaxis Python, diez tests puros, gate estático B18K y consulta efectiva SQL/red. La única etapa elevada usa `sudo` pero ejecuta solo lectura `SELECT`, `docker ps`, `docker inspect` y `docker network inspect`. No entra en ningún contenedor ajeno ni modifica roles, permisos, red, base, Docker ni O5.

## Ejecución única en VPS VENCIRA (todavía NO validada)

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
