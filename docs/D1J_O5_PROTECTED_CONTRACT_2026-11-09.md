# D1-J — Contrato de los wrappers O5 protegidos (09/11/2026)

**Estado: D1-I PASS; D1-J preparado, pendiente de ejecutar.** Integración exclusiva en `main`.

## Motivo

Los dos temporizadores `vencira-o5-backup.timer` y `vencira-o5-health.timer` están activos y habilitados, y sus últimos servicios reportaron `Result=success`, `ExecMainStatus=0`. D1-G confirma que invocan scripts Shell directos sin argumentos; los scripts están en directorios inaccesibles para el usuario ordinario. **Todavía no se ha consultado Restic ni demostrado un snapshot restaurable.**

## Clasificación protegida D1-J

`scripts/d1j_o5_privileged_contract_readonly.py` es un clasificador estático de alcance estricto. Necesita ejecutarse como root únicamente para **leer** dos fragmentos systemd y los dos wrappers `ExecStart` de los servicios O5. Rechaza rutas relativas, múltiples comandos `ExecStart`, symlinks, archivos grandes y objetivos que no sean wrappers Shell. Informa solo marcadores fijos YES/NO para presencia en el texto de Restic, Rclone, pg_dump, pg_restore, Docker, comandos reconocibles y posibles fuentes de variables de entorno.

**No ejecuta** los wrappers ni las herramientas detectadas; **no imprime** el contenido, rutas, argumentos, secretos ni valores de variables. Detectar una palabra no garantiza que el comando se ejecute realmente: el informe es solo un inventario de texto. Este script no modifica DEV, copias ni las unidades O5. Se recomienda revisar su código en `main` antes de utilizar privilegios, y ejecutar solo desde el checkout oficial verificado; no copiarlo a ubicaciones públicas ni usar scripts que no se hayan contrastado.

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
git status --short
python3 -m py_compile scripts/d1j_o5_privileged_contract_readonly.py

sudo python3 scripts/d1j_o5_privileged_contract_readonly.py
echo "D1J_SHELL_RESULT=$?"
```

No enviar contraseñas de sudo ni archivos O5 protegidos. Compartir solo marcadores `D1J_*`. Si aparece `D1J_ERROR_TYPE` no modificar los permisos para hacerlo pasar ni ejecutar el script de backup manualmente.

**Criterio de clasificación:** `D1J_RESULT=0`, `D1J_BACKUP_WRAPPER_READABLE=YES`, `D1J_HEALTH_WRAPPER_READABLE=YES`, con salida de marcadores sin secretos. Esto **NO cierra D1-J de restauración**.

## Puerta de restauración real pendiente

Una vez entendido el contrato, verificar snapshots Restic con la identidad y custodia de credenciales ya establecidas por el operador. Para una restauración, fijar explícitamente un directorio temporal nuevo y vacío, comprobar aislamiento de PostgreSQL17, seleccionar snapshot inequívoco de DEV, evitar escribir sobre `/opt/vencira` o la base persistente y comprobar que el material recuperado es una copia íntegra. El ensayo posterior `reminders.0019–0027` deberá realizarse solo sobre la copia restaurada.

Hasta ese momento:
```text
D1J_SNAPSHOT_VERIFIED=NO
D1J_RESTORE_VERIFIED=NO
D1K_DEV_DATA_MIGRATION_REHEARSAL=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
