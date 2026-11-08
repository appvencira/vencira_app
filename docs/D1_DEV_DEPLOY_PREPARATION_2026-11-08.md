# VENCIRA — D1: preparación del despliegue controlado en DEV

Fecha: 08/11/2026. Destino previsto: `dev.vencira.es`, **no producción**. Repositorio: `appvencira/vencira_app`, rama `main`.

## Decisión operativa actual

**NO DESPLEGAR / NO MIGRAR todavía.** Este documento es un procedimiento de **preparación y control de cambios**, no una autorización de despliegue. La fuente `main` contiene componentes nativos de laboratorio (solo `VENCIRA_ENV=test`), y la compatibilidad con el esquema persistente de DEV aún no está demostrada. Tampoco se han revisado desde esta rama los scripts efectivos del servicio Docker Compose ni se ha acreditado en esta sesión la restauración reciente de un backup O5.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```

## Diferencias entre código, despliegue y datos

- Los gates PG17 I8-K/I8-M **46/46 PASS** y Flutter **47/47 PASS** se ejecutaron en laboratorios y sobre copias temporales. No autorizan `docker compose up`, migraciones de DEV, ni activar emisor móvil o nuevo MFA.
- `main` mantiene los módulos nativos de candidatos bajo `VENCIRA_ENV=test` y sin rutas públicas en `config.urls`.
- El árbol de `main` **no contiene** en los paths históricos habituales `docs/CONTINUITY_RUNBOOK.md`, `docs/OPERATION_O5_DRIVE_BACKUPS.md`, `docs/PROJECT_STATUS.md` ni los nombres de Compose consultados (`compose.yml`, `docker-compose.yaml`, `infra/compose.yaml`). Los archivos operativos pueden estar en otra ruta o en los checkouts históricos del VPS. No asumir que fueron eliminados de DEV ni que se han restaurado. **Se requiere inventario del servicio actual antes de elegir un manifiesto de despliegue.**
- Un `showmigrations` del API actualmente desplegada no certifica compatibilidad con modelos/migraciones nuevos de main: hay que contrastar el grafo real en una restauración aislada de la base DEV.

## Paso D1-A: inventario reproducible de solo lectura

En Termius, en el checkout independiente de `main` (preferentemente dentro de `tmux`):

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
git rev-parse HEAD

python3 scripts/d1_dev_deploy_inventory_readonly.py \
  2>&1 | tee ~/vencira-d1-deploy-readonly.log

echo "D1_INVENTORY_SHELL_RESULT=${PIPESTATUS[0]}"
```

El script:
1. Identifica el commit de checkout y comprueba los ficheros controlados por Git.
2. Comprueba el estado healthy, etiquetas Compose, IDs de imagen y contenedores DEV (solo `docker inspect`).
3. Comprueba estáticamente que no se han expuesto rutas nativas de laboratorio en `config.urls`, y que el bearer candidato sigue deshabilitado.
4. **Lee** el registro `django_migrations` a través del contenedor API existente, con la API Django `MigrationRecorder(connection).applied_migrations()`. No invoca `migrate` ni scripts de actualización.
5. Compara identificadores de migración en el checkout con lo registrado en DEV; reporta ambos sentidos de discrepancia sin consultar contenido de tablas de negocio ni variables secretas.
6. Declara siempre `D1_RELEASE_AUTHORIZED=NO`, `D1_BACKUP_RESTORE_VERIFIED=NO`, `D1_MIGRATION_COMPATIBILITY_VERIFIED=NO`.

**Precaución:** su éxito indica que el inventario de solo lectura se completó, **NO** que sea seguro desplegar. La presencia de `D1_MAIN_NOT_APPLIED` o `D1_APPLIED_NOT_IN_MAIN` exige reconciliación; no resolver con `--fake` ni aplicando migraciones persistentes para que el contador llegue a cero.

## Paso D1-B: requisitos para promover cambios web en DEV

No ejecutar todavía. Exigir evidencia específica y reproducible:

1. Identificar repositorio/checkout, SHA y archivos Compose/Caddy que alimentan exactamente los servicios persistentes actuales, incluyendo Dockerfiles y bind mounts, sin mostrar `env`, credenciales ni claves privadas.
2. Registrar migraciones actuales y diferencias con `main`. Construir una imagen candidata reproducible; ejecutar `migrate --plan` y `makemigrations --check` sobre una base **restaurada en PostgreSQL 17 temporal**, nunca contra DEV.
3. Ejecutar backup O5 verificado con snapshot reciente y **prueba de restauración completa** del mismo conjunto de datos en una base aislada; comprobar que el backup pertenece a DEV y el estado de integridad y retención, sin imprimir secretos o PII.
4. Fijar el SHA de imagen anterior y nuevo, preparar rollback transaccional de imágenes y base: ante migraciones no reversibles o datos nuevos incompatibles, detener promoción hasta tener un plan practicado de recuperación.
5. Ejecutar la regresión de Django y Flutter web con las imágenes candidatas, login de navegador, agenda/vencimientos, ficha, adjuntos, CSRF, HTTPS Caddy, health y ready. Asegurar que endpoints nativos candidatos y MFA operativo siguen deshabilitados.
6. Presentar evidencia antes de solicitar autorización explícita para una ventana de despliegue DEV. La aceptación de D1-A no autoriza D1-B ni el despliegue.

**No tocar el despliegue mientras `NO_DEPLOY_NO_LIVE_MIGRATION=1`.** Si se autoriza una futura actualización de DEV, documentar explícitamente qué componente y qué migración se promueve, el backup/rollback y los post-checks; no autorizar por extensión la autenticación nativa.

## Hallazgos previos

- I8-M backend 46/46 tests PASS; Flutter 47/47 PASS; arranque negativo TLS y X.509 offline PASS.
- I8-M HTTPS real y persistencia Android siguen sin validar.
- El destino operativo del nuevo contenido **no está demostrado compatible** todavía; por tanto D1-A es inventario y no un ensayo de despliegue.

## D1-A ejecutado — inventario de DEV (operador 08/11/2026)

El operador ejecutó `scripts/d1_dev_deploy_inventory_readonly.py` en `~/vencira-main-check-20261108` con SHA `cdd0b88bc3ce5cf901c92ea414a6357ce3ce37c0`. El worktree estaba limpio y en HEAD detached; `D1_MAIN_TEST_ONLY_CANDIDATE_FENCE=PASS`. Los contenedores `api`, `db` y `web_preview` devolvieron `HEALTH=PASS`. IDs de imagen resumidos: API `sha256:6bb813f527410957b...`, DB `sha256:b0f9560a2de083e2c...`, Web `sha256:4fc638690d97cd029...`.

Datos del inventario:

```text
D1_MAIN_MIGRATIONS_DISCOVERED=42
D1_PERSISTENT_APPLIED_MIGRATIONS_COUNT=36
D1_MAIN_NOT_APPLIED_COUNT=24
D1_APPLIED_NOT_IN_MAIN_COUNT=0
D1_BACKUP_RESTORE_VERIFIED=NO
D1_MIGRATION_COMPATIBILITY_VERIFIED=NO
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_PREFLIGHT_INVENTORY_RESULT=0
D1_INVENTORY_SHELL_RESULT=0
```

**Clasificación de las 24 migraciones listadas como no aplicadas:**
- **9 migraciones de la app principal `reminders`:** `0019_user_mfa_state`, `0020_mfa_attempt_limits`, `0021_mfa_prepared_at`, `0022_mfa_admin_recovery_cases`, `0023_user_mfa_session_epoch`, `0024_mfa_pending_rotation`, `0025_mfa_pending_rotation_codes`, `0026_user_mfa_pending_administrative_case`, `0027_renewal_attachment_metadata`. **Requieren análisis del grafo y ensayo con copia restaurada**; no ejecutar sobre DEV. `0019` depende de `reminders.0018_draft_reasons`, y `0027` depende de `reminders.0026_user_mfa_pending_administrative_case`.
- **5 migraciones de `native_mobile_service`:** `0001` a `0005`. Registro de app condicionado a `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`. **Nunca migrarlas a DEV.**
- **4 migraciones de `native_sessions_lab`:** `0001` a `0004`. Exclusivas de laboratorio test. **Nunca migrarlas a DEV.**
- **6 migraciones de `renewal_attachments`:** `0001` a `0006`. El registro en `INSTALLED_APPS` exige `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1` y `VENCIRA_ENV=test`. **No forman parte del grafo operativo DEV.**

Los conteos se refieren a archivos de migración presentes en el checkout y al registro `django_migrations` leído de forma aislada; **no** equivalen a un `migrate --plan` efectivo del nuevo código con sus settings operativos. Que 36 migraciones estén aplicadas y 42 existan en main **no significa que falten solo 6**: parte de las registradas pertenecen a apps estándar Django y las migraciones de laboratorios no están habilitadas en DEV.

**Interpretación:** se confirma 0 migraciones aplicadas cuyos nombres estén ausentes en `main` para las apps locales allí inventariadas, pero ello no certifica que coincidan modelos, operaciones SQL, datos y dependencias. Las dos aplicaciones de lab y la app de adjuntos separada son test-only; no convertirlas en carga DEV.

**Puerta siguiente D1-B:** verificar vigencia/recuperabilidad O5, localizar el manifiesto real de los contenedores y restaurar un backup DEV en un PostgreSQL 17 temporal. Ejecutar `migrate --plan` y ensayo `0019–0027` solo allí, inspeccionar colisiones de tablas/índices y probar rollback con datos sintéticos o restaurados protegidos. Ninguna operación de despliegue ni migración persistente autorizada todavía. MFA nativa operativa sigue desactivada.
