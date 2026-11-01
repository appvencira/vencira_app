# VENCIRA — Macrobloque G1–G3 CI + frontera de privilegios (01/11/2026)

## Trabajo publicado
- G1: inventarios AST de código y caller tracing de `PrivateQuarantineStore`, ahora en `.github/workflows/mb1-audit.yml`. Las salidas categorizan candidatos y no prueban ejecución ni ausencia de rutas dinámicas.
- G2: `scripts/mb1_g23_role_boundary_contract.py` exige evidencia independiente para rol de API sin superusuario/CREATEDB/CREATEROLE/BYPASSRLS/DDL, distinción de credenciales de backup/admin y control de CONNECT. No intenta cambiar privilegios reales.
- G3: el mismo contrato exige API y planificadores detenidos, sesiones drenadas, exclusión de escritores SQL internos/externos/administrativos, protección de objetos y diario frente a writers no cooperativos, aislamiento host/Docker y captura de recursos bajo una época lógica común.
- `scripts/test_mb1_g23_role_boundary_contract.py`: nueve casos unitarios de estructura estricta, denegación por defecto, evidencias parciales, rechazo de entradas mal formadas y ausencia de autorización aunque todas las casillas se autodeclaren. Tests integrados en GitHub Actions.

## Decisión técnica
**Prohibido declarar PASS de freeze con 16 booleanos de un JSON.** Las atestaciones solo son candidatas para revisión externa. En particular, mientras el rol de API en DEV/preview sea superusuario y haya bypass SQL administrativo/FS no cooperativo, no existe garantía de corte global. Tampoco O5 actual abarca objetos y diario como respaldo operacional.

## Estado y siguiente bloque de cierre
Código y tests publicados; CI **pendiente de observar un PASS real**. La consulta del conector de GitHub para runs de commits, limitada a runs vinculados a PR, no sirve para comprobar todos los pushes. El enlace de Actions permite consultar el estado completo.

La siguiente ingeniería con valor de cierre será **separación de privilegios y capacidad de escritores en clon PG17 representativo**, con diseño de reversión y evidencia adversarial; posteriormente, revisión humana de todos los procesos que comparten red, volúmenes y credenciales. No reemplazar esto por más contadores ni por cambios en DEV.

```text
MB1_G1_UNIVERSAL_WRITERS=NOT_VERIFIED
MB1_G2_OPERATIONAL_ROLE_SEPARATION=NOT_VERIFIED
MB1_G3_NONCOOPERATIVE_WRITER_EXCLUSION=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
Hitos cerrados: 1/15 (6,7 %).
