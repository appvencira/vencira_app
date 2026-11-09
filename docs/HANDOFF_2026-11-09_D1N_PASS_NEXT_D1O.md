# VENCIRA — Traspaso maestro para nuevo chat (09/11/2026, tras D1-N)

**Repositorio:** [appvencira/vencira_app](https://github.com/appvencira/vencira_app)  
**Destino de integración exclusivo:** `main`. No crear ramas nuevas ni fusionar ramas históricas indiscriminadamente.  
**Punto de trabajo VPS por Termius:** `~/vencira-main-check-20261108`.  
**Entorno persistente DEV:** `dev.vencira.es`, Compose `vencira_localcheck`, contenedores `vencira_localcheck-api-1`, `vencira_localcheck-db-1`, `vencira_localcheck-web_preview-1`.  
**Fecha y corte:** 09/11/2026, después de recibir `D1N_RESULT=0`.

## 1. Decisión de seguridad innegociable

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```

**No se ha desplegado `main` a DEV ni migrado la BD persistente.** Las migraciones `reminders.0019–0027` se han ejecutado exclusivamente sobre bases temporales aisladas. No habilitar endpoints MFA/bearer nativos candidatos, no conectar login nativo experimental a APK operativa, no cambiar los flags ni ejecutar `docker compose up`/migrate persistente sin autorización específica después de los gates pendientes.

## 2. Estado real, con pruebas aportadas por el operador

| Bloque | Evidencia | Cierre |
| --- | --- | --- |
| D1-I | PG17 sintético, paridad Django, `0018→0027→0018→0027`, dump sintético restaurado, DEV intacto, `D1I_RESULT=0` | **PASS sintético** |
| D1-J/K | Inspección solo lectura de wrappers root y systemd | **PASS de clasificación**, no prueba de backup |
| D1-L | Configuración O5 legítima, **25 snapshots PostgreSQL etiquetados**, último **19 horas** en el momento de prueba, `restic check` metadatos PASS, `D1L_RESULT=0` | **PASS metadatos/snapshot** |
| D1-M | Restic O5 real → `pg_restore` PostgreSQL17 sin red/`tmpfs`, esquema `reminders.0018`, contenedor temporal eliminado, DEV intacto, `D1M_RESULT=0` | **PASS restauración real** |
| D1-N | Segunda recuperación Restic real → PG17 `tmpfs`, imagen candidata Django, `makemigrations --check`, plan/aplicación `reminders.0019–0027`, conteos base conservados, rollback a `0018`, DEV intacto, `D1N_RESULT=0` | **PASS migración histórica/rollback** |
| B2 Flutter | **7/7** widget tests PASS: dashboard vacío/error, workspace/vencimiento sintético a 320/390 px, ficha y regreso con recarga, `B2_UI_SMOKE_RESULT=0` | **PASS alcance widget** |
| I8/G7/G13 | HTTPS y certificados en laboratorio, pruebas nativas previas | **PASS de sus gates de laboratorio**, no operación real |
| Android APK | Entrada normal en `clients/flutter/lib/main.dart` sigue usando `AndroidWebAccessScreen` en Android; shell nativo de laboratorio solo inyectado en debug | **LOGIN NATIVO OPERATIVO PENDIENTE** |
| D1-O | Regresión integral Django, seguridad, web y HTTP/HTTPS sobre candidato | **PENDIENTE** |
| Despliegue DEV | Plan release controlado, rollback imagen y BD, aprobación explícita | **NO AUTORIZADO** |
| Android visual | Teléfono físico / UI completa | **PENDIENTE** |

### Prueba exacta D1-N de este cierre

El operador comunicó:

```text
D1N_READ_ONLY_SOURCE_REPOSITORY=YES
D1N_BACKUP_EXECUTED=NO
D1N_LIVE_RESTORE_EXECUTED=NO
D1N_LIVE_MIGRATIONS_EXECUTED=NO
D1N_DEPLOY_EXECUTED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1N_CONFIG_MATCH=PASS
D1N_DEV_IDENTITY=PASS
D1N_RECENT_POSTGRESQL_SNAPSHOT=PASS
D1N_LAB_NETWORK_INTERNAL=PASS
D1N_PG17_NETWORK_ISOLATED=PASS
D1N_PG17_TMPFS_READY=PASS
D1N_RESTORE_REAL_O5_PG17=PASS
D1N_HISTORICAL_0018=PASS
D1N_BACKUP_PAYLOAD_PG_RESTORE_VERIFIED=YES
D1N_REAL_BACKUP_RESTORED=PASS
D1N_CANDIDATE_DJANGO_IMAGE=PASS
D1N_BASELINE_COUNTS=PASS
D1N_MODEL_MIGRATION_PARITY=PASS
D1N_MIGRATION_PLAN=PASS
D1N_MIGRATIONS_0019_0027=PASS
D1N_CORE_COUNTS_UP=PASS
D1N_ROLLBACK_TO_0018=PASS
D1N_CORE_COUNTS_DOWN=PASS
D1N_REAL_DATA_CONTENT_PRINTED=NO
D1N_HISTORICAL_MIGRATION_GATE=PASS
D1N_DEV_CONTAINERS_UNCHANGED=OK
D1N_LAB_CONTAINER_REMOVED=YES
D1N_LIVE_RESTORE_EXECUTED=NO
D1N_LIVE_MIGRATIONS_EXECUTED=NO
D1N_DEPLOY_EXECUTED=NO
D1N_RESULT=0
```

**No constan en el mensaje** `D1N_EPHEMERAL_NETWORK_REMOVED` ni `D1N_SHELL_RESULT`, aunque `D1N_RESULT=0` indica éxito del script. No inventar marcadores. Si interesa sanidad de recursos, comprobar **solo mediante inventario read-only**, no repetir restauraciones por ello.

### Precisión de las pruebas

La integridad de `restic check` D1-L es de metadatos; D1-M acreditó efectivamente lectura y restauración del contenido PostgreSQL de un snapshot. D1-N aplicó y revirtió el grafo sobre datos históricos reales. **Comparar conteos de `auth_user`, `reminders_workspace`, `reminders_renewal` no garantiza igualdad de todas las filas/campos ni cobertura de todas las tablas.** No equivale a un deploy ni certificación funcional HTTP/web.

## 3. Arquitectura, datos y salvaguardas

- Backend Django 5.2 / PostgreSQL 17, aplicación `reminders`; migraciones operativas en DEV hasta `reminders.0018`, nuevas `0019–0027` presentes en `main` pero **no aplicadas en DEV**.
- Algunas migraciones de apps `native_sessions_lab`, `native_mobile_service`, `renewal_attachments` son **solo test** con registro condicional explícito; no activarlas en DEV.
- Frontend Flutter y web Nginx con Caddy HTTPS; flujo nativo HTTPS y MFA sigue experimental y prohibido en operación.
- Backup O5: systemd `vencira-o5-backup.timer`, `vencira-o5-health.timer`; ejecutor root `o5_schedule_backup.sh` delega en `/usr/local/libexec/vencira/o5_backup_to_drive.sh`. Configuración privada bajo `/etc/vencira-backup/config.env`, contraseña y Rclone fuera de Git. Backend Restic vía Rclone/Google Drive, etiqueta `vencira-postgresql`, dump `vencira-postgres.dump` generado con `pg_dump -Fc` por `--stdin-from-command` y `restic check`. **No incluir contenido de variables, credenciales ni claves en GitHub/chat**.
- D1-M/D1-N usan redes/contenedores separados, no reutilizan servicios DEV, no publican puertos ni escriben datos reales en directorios persistentes; las credenciales sintéticas de Django son locales y temporales.
- GitHub `main` es el único destino de cambios. Los scripts se ejecutan desde el checkout independiente `~/vencira-main-check-20261108`, no desde `/home/vencira/vencira-localcheck` utilizado por DEV.

## 4. Archivos de continuidad

1. **Documento maestro histórico:** `docs/MAIN_BRANCH_AUDIT_2026-11-08.md`. Contiene auditoría de ramas/PR, todas las pruebas y evolución D1/B2; consultar las secciones finales (D1-L a D1-N) para el estado actual y no tomar como actuales los estados `pending` intermedios.
2. **Esta guía de traspaso:** `docs/HANDOFF_2026-11-09_D1N_PASS_NEXT_D1O.md`.
3. **Procedimiento D1-N y resultado:** `docs/D1N_O5_HISTORICAL_PG17_MIGRATIONS_2026-11-09.md`.
4. **Restauración real D1-M:** `docs/D1M_REAL_O5_PG17_RESTORE_2026-11-09.md`.
5. **Restic metadatos D1-L:** `docs/D1L_O5_REAL_RESTIC_GATE_2026-11-09.md`.
6. **Preparación del despliegue:** `docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md`.
7. **Gates B2:** `clients/flutter/test/b2_dashboard_viewport_smoke_test.dart`, `scripts/main_b2_dashboard_viewport_smoke.sh`.

### Commits representativos

- D1-L: `2b97e82d` (snapshots etiquetados), `c0e888a4` (acceso O5 autenticado); docs `86d306c0`.
- D1-M: `07f1480e` (restauración real), `7e83de29` (procedimiento).
- D1-N: `44f35f25` (migraciones/restauración real), `f4c1307a` (procedimiento), `18b25dd4` (resultado PASS).
- B2: `6209e35a` (doble API corregido), `c24b2c55` (navegación Material), `cf5caff0` y actualizaciones posteriores de auditoría.
- El documento maestro ya recibió `06823ba1` (D1-M PASS) y `8343379e` (D1-N preparado), y se actualizará para D1-N PASS.

## 5. Próximo bloque prioritario: D1-O, regresión integral de candidato

**No repetir D1-I/L/M/N ni B2 sin cambios de código que lo justifiquen.** Preparar un **bloque grande** que cubra:
1. `manage.py check`, `makemigrations --check`, tests Django representativos y migraciones obligatorias con imagen candidata, en bases desechables y sin tocar DEV.
2. Contratos HTTP/seguridad: autentificación sesión web, CSRF, aislamiento por workspace, control de permisos de ficha y adjuntos, MFA fail-closed; asegurar que emisor/bearer nativo candidato siguen sin rutas públicas.
3. Build/análisis/test Flutter web y revisión de rutas principales, con criterios de fallo explícitos.
4. Inventario del Compose/Caddy real y plan de promoción/rollback para una futura ventana DEV; **solo lectura** hasta autorización.
5. Documentar resultados en `main` al final del bloque, con marcadores reproducibles y sin datos personales.

**Luego**, si los gates pasan, presentar el resumen de riesgos y pedir **autorización explícita** antes de desplegar o ejecutar cualquier migración en DEV. Separar esta decisión del futuro login nativo Android: que web sea promovible no autoriza activar MFA/issuer nativo.

## 6. Comandos seguros de continuación

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
git rev-parse --short HEAD
git status --short
```

Para el próximo chat, empezar consultando en GitHub `docs/HANDOFF_2026-11-09_D1N_PASS_NEXT_D1O.md` y el final de `docs/MAIN_BRANCH_AUDIT_2026-11-08.md`. **No solicitar al operador repetir logs ya compartidos.** Continuar directamente con preparación de D1-O y publicar código/documentación en `main`; consultar solo cuando exista un gate nuevo para Termius.

## 7. Preferencia operativa del usuario

Avanzar en **bloques grandes**, sin abrir ramas adicionales, sin interminables inventarios de rutas y sin pedir autorizaciones innecesarias para trabajo aislado. Preguntar únicamente cuando haga falta ejecutar validación local o una acción persistente. No declarar PASS no verificado, no mostrar credenciales y no prometer despliegues antes de cumplir los bloqueos reales.
