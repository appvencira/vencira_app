# VENCIRA — MB1 ensayo E2E de recuperación en dos PG17 aislados

**Fecha:** 30/10/2026. Preparado en GitHub; **pendiente ejecución en Ubuntu**.

Se implementó `scripts/rehearse_mb1_pg17_e2e_disposable.sh` para reducir el número de microgates. Crea una red Docker interna y dos contenedores PostgreSQL 17 **desechables** (origen y destino), construye Django desde la rama, aplica el esquema independiente hasta `renewal_attachments.0006` en origen, inserta un expediente/adjunto **exclusivamente sintético** mediante ORM, escribe objeto y diario sintéticos en `/tmp`, hace `pg_dump -Fc` real, restaura con `pg_restore` real en destino, comprueba el registro con ORM y verifica SHA-256 del dump, objeto y diario. Al terminar (incluidos fallos) destruye los contenedores y la red de ensayo. No se publican puertos ni se conecta a DEV. El log local permanece en directorio `/tmp/vencira-mb1-e2e.*` con permisos privados. `clients/flutter/pubspec.lock` queda intacto.

**Este gate es una integración real de pg_dump/pg_restore, pero NO constituye el backup integral autenticado B09E ni una recuperación operativa.** Los bytes del objeto son un fixture y sus hashes no están ligados criptográficamente al manifiesto de PG17. No implementa cifrado de su `source.dump` (solo datos sintéticos), no crea un manifiesto autenticado, no demuestra que todos los escritores externos estén excluidos, ni valida custodia de claves fuera del VPS. B09E ya había probado restauración autenticada de materiales sintéticos por separado: este nuevo gate cubre una necesidad distinta (Django+dos servidores PG17 reales), pero no agrega automáticamente todas las garantías.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_E2E_EXIT_CODE=$?"
```

Solo si el operador ejecuta y pasa el gate se esperan:
```text
MB1_E2E_PG17_SOURCE_TARGET=OK
MB1_E2E_REAL_PG_DUMP_RESTORE=OK
MB1_E2E_SYNTHETIC_OBJECT_JOURNAL_HASH=OK
MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=NOT_CREATED
MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED
MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED
MB1_E2E_RESULT=0
MB1_E2E_EXIT_CODE=0
```

Criterios pendientes de cierre MB1: cortar de forma efectiva entradas y procesos de escritura BD/filesystem en un clon, capturar un conjunto autenticado y cifrado de la MISMA época, inyectar fallos en captura/restauración y reconciliar anomalías, custodia independiente de claves, recuperación ante pérdida de VPS. Nunca usar este script sobre datos reales.

```text
MB1_E2E_EXECUTION=PENDING
MB1_GLOBAL_FREEZE=BLOCKED
MB1_OPERATIONAL_DR=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Evidencia de ejecución comunicada — 30/10/2026

El operador comunicó: `MB1_E2E_PG17_SOURCE_TARGET=OK`, `MB1_E2E_REAL_PG_DUMP_RESTORE=OK`, `MB1_E2E_SYNTHETIC_OBJECT_JOURNAL_HASH=OK`, `MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=NOT_CREATED`, `MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_E2E_RESULT=0`, `MB1_OPERATIONAL_RELEASE=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log privado: `/tmp/vencira-mb1-e2e.PW97vX2R/drill.log` (no inspeccionado). No se incluyó `MB1_E2E_EXIT_CODE` adicional. **PASS para restauración PG17 sintética y hashes locales; no para backup integral operativo**.


## Extensión cifrada y autenticada — pendiente de validación

Nueva revisión del gate E2E: `backend/renewal_attachments/mb1_e2e_authenticated_pack.py` empaqueta el `pg_dump -Fc` y bytes de objeto/diario sintéticos mediante Fernet, autentica un manifiesto conjunto con HMAC-SHA256, registra hashes SHA-256 y `snapshot_id` común. El ejecutor ahora empaqueta, prueba **clave errónea y archivo alterado**, elimina el dump original y **verifica/autentica/descifra antes de transmitir por stdout a `pg_restore`** en destino efímero. Utiliza `--network none` para el empaquetador. El manifiesto no está firmado mediante un custodio independiente: claves y paquete están temporalmente en el mismo directorio de ensayo del VPS, y se conserva un `source.dump` sintético durante el empaquetado.

**Importante:** todavía no demuestra corte universal frente a escritores externos, captura coherente SQL+filesystem, custodia externa de claves, anti-rollback o validez operativa. El uso de Fernet en memoria tiene un límite de tamaño de prueba; no sirve como streaming de backup a escala comercial. No modificar despliegues. El operador debe repetir **únicamente el gate E2E**, ya que cambió su comportamiento:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_E2E_AUTH_EXIT_CODE=$?"
```

Si pasa: `MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=OK`, `MB1_E2E_WRONG_KEY_AND_TAMPER_REJECTED=OK`, `MB1_E2E_REAL_PG_DUMP_RESTORE=OK`, `MB1_E2E_RESULT=0`. **Estado actual de esta extensión: PENDING_OPERATOR_VALIDATION.**


## MB1 — detección fail-closed de sesiones ajenas (30/10/2026)

Se ha extendido el **mismo** ensayo E2E con una comprobación `pg_stat_activity` sobre el origen PostgreSQL **efímero**, inmediatamente antes del volcado. El script abre deliberadamente una sesión `psql` paralela con `pg_sleep(8)`, comprueba que la barrera rechaza iniciar la captura cuando detecta una conexión ajena y espera a que desaparezca; después repite la comprobación antes de `pg_dump`. No mata sesiones desconocidas. Marcadores previstos: `MB1_E2E_FOREIGN_DB_SESSION_REJECTED=OK`, `MB1_E2E_SOURCE_DB_SESSION_DRAIN=OK`, junto con los de restauración cifrada.

**Alcance estricto:** esto detecta conexiones de tipo cliente a la base de ensayo en el instante consultado. **No impide una conexión nueva inmediatamente después**, no prueba transacciones ya terminadas, no protege filesystem, no controla escritores a través de otros almacenes y no congela una base de producción. La carrera de tiempo entre consulta y `pg_dump` es un bloqueo pendiente de diseño; no elevar el procedimiento a un gate de freeze universal. La duración máxima de la espera sintética es 12 segundos y el único escritor inducido es una sesión de prueba `pg_sleep(8)`.

Solo ejecutar de nuevo el mismo script E2E; no repetir baterías independientes. Estado de esta modificación: **PENDING_OPERATOR_VALIDATION**. `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_OPERATIONAL_RELEASE=NO`.


## Aislamiento de red del origen de prueba — 30/10/2026

Tras superar el ensayo autenticado previo, el ejecutor ahora desconecta el contenedor PostgreSQL de origen de su **única red interna de ensayo** justo después de drenar clientes. Un segundo contenedor PostgreSQL del mismo entorno intenta entrar al origen y debe fracasar; si entra, el gate falla. Se comprueba también que un `psql` local dentro del contenedor de origen sigue respondiendo para que `pg_dump` funcione mediante el socket local. El origen permanece sin red hasta su eliminación en el `trap` del script. Esta modificación está **pendiente de ejecutar**; no repetir tests anteriores.

La exclusión certificable cubre únicamente nuevas conexiones por esa red temporal. Un `docker exec` privilegiado desde el host puede seguir conectándose, y los archivos de `/tmp` siguen expuestos a escritores del host con permisos suficientes. No existe un bloqueo universal de SQL/filesystem ni custodia externa real de claves. Estado: `MB1_E2E_SOURCE_NETWORK_INGRESS_DENIED=PENDING`, `MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_OPERATIONAL_RELEASE=NO`.
