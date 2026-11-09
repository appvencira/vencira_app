# D1-I — Ensayo de migraciones y restauración sintética en PostgreSQL 17

**09/11/2026 — Estado: código integrado en `main`, ejecución VPS pendiente.**

## Objetivo y límites

Se reutiliza el patrón de red Docker interna, PostgreSQL 17 con `tmpfs`, imagen Django derivada del checkout `main`, secretos sintéticos temporales y limpieza `trap EXIT` de I8-P. Se protege la identidad de los tres contenedores DEV al inicio y al final.

El script `scripts/main_d1i_pg17_synthetic_migrations_rollback.sh` realiza en **una única ejecución**:

1. Imagen Django candidata efímera y PG17 aislado, sin publicar puertos ni conectar al contenedor DB existente.
2. `check` y `makemigrations reminders --check --dry-run` sobre backend actual.
3. Inicialización de una base **sintética** hasta `reminders.0018`.
4. `pg_dump -Fc` de ese esquema sintético, guardado **solo dentro del contenedor efímero**.
5. `migrate reminders 0027 --plan` y luego ejecución real de `0019–0027` **solo en PostgreSQL temporal**; verificación SQL de las nueve migraciones registradas.
6. `migrate reminders 0018` con comprobación SQL de rollback.
7. `pg_restore` del dump sintético a una segunda base nueva del mismo PostgreSQL temporal; comprobación SQL de presencia de `0018`.
8. Reaplicación de `reminders.0027` y `migrate --plan`, teardown de contenedor, imagen, red y archivo temporal, e inventario de integridad DEV.

**No confirma todavía:** compatibilidad de migración con **datos reales o un snapshot de DEV**, éxito de O5 Restic, despliegue, funcionamiento de las pantallas de Flutter ni disponibilidad de reversión de todos los datos en una actualización real. PostgreSQL temporal está vacío de datos personales y las tablas corresponden a un esquema recién construido en `main`, no a la base histórica DEV; un PASS no autoriza un despliegue.

## Gate en Termius (una ejecución)

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD

bash -n scripts/main_d1i_pg17_synthetic_migrations_rollback.sh

set -o pipefail
bash scripts/main_d1i_pg17_synthetic_migrations_rollback.sh \
  2>&1 | tee ~/vencira-d1i-pg17-rehearsal.log
echo "D1I_SHELL_RESULT=${PIPESTATUS[0]}"
```

**Éxito requerido:** `D1I_MODEL_MIGRATION_PARITY=PASS`, `D1I_BASELINE_0018=PASS`, `D1I_0019_0027_APPLIED=PASS`, `D1I_ROLLBACK_TO_0018=PASS`, `D1I_SYNTHETIC_DUMP_RESTORED=PASS`, `D1I_0019_0027_REAPPLY=PASS`, `D1I_DEV_CONTAINERS_UNCHANGED=OK`, `D1I_RESULT=0`, `D1I_SHELL_RESULT=0`. El script no debe marcar PASS si falla `migrate` o `pg_restore`.

Mantener `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Este gate nunca conecta el contenedor persistente DEV ni ejecuta `docker compose up`.

## Puerta D1-J posterior

Restaurar **un snapshot O5 real** sobre PG17 aislado mediante un procedimiento que conserve privacidad y secretos y compruebe inequívocamente el destino de la restauración. Ejecutar `migrate --plan` y `reminders.0019–0027` en esa copia restaurada, con comprobaciones de consistencia/rollback. Hasta entonces, D1-I es un ensayo técnico útil pero insuficiente para desplegar.
