# D1-L — Evidencia real de Restic O5, sin restauración (09/11/2026)

**Situación:** B2 Flutter UI/navegación 7/7 PASS; D1-I migraciones PG17 sobre base sintética PASS. El backup efectivo O5 del VPS y su restauración a un clon histórico **no están acreditados**. Los scripts de systemd están protegidos y no deben copiarse a GitHub ni mostrar secretos. D1-J y D1-K eran clasificadores estáticos, no verificaciones reales de Restic.

## Alcance del gate

`scripts/main_d1l_o5_restic_metadata_gate.py` ejecuta de verdad dos comandos de **solo lectura** sobre un repositorio Restic explícitamente configurado por el operador:
- `restic --no-lock snapshots --json`: comprueba que existen snapshots, cuenta registros y calcula la antigüedad del último.
- `restic --no-lock check`: comprueba **metadatos y estructura del repositorio**, no lee íntegramente el contenido de todos los datos respaldados.

El programa no ejecuta `backup`, `restore`, `forget`, `prune`, `unlock` ni operaciones SQL y no imprime paths, etiquetas, nombres de repositorio, líneas de error de Restic, contraseñas ni contenido recuperado. Se aborta ante ausencia de credenciales externas, repositorio no configurado o falta de confirmación de que se trata de O5-DEV.

**Advertencias importantes:** `D1L_RESULT=0` no demuestra que el snapshot contenga la base de DEV, ni que el snapshot sea restaurable, ni que todos los bloques remotos estén íntegros. La identidad DEV la confirma el operador: el código no puede verificarla de forma independiente. El proceso puede consumir tiempo/red en función del tamaño del repositorio. No mostrar en chat la salida de `env`, contenido de archivos de password, rutas sensibles ni IDs que identifiquen datos privados.

## Ejecución protegida cuando se conozca el entorno Restic

No hay en `main` una fuente verificada de `RESTIC_REPOSITORY` o `RESTIC_PASSWORD_FILE`. **No ejecutar una conjetura** sobre la ruta del repositorio. No ejecutar los wrappers de backup manualmente. La persona que custodia O5 debe identificar y cargar el entorno Restic original en una sesión privada, con `RESTIC_PASSWORD_FILE` (o `RESTIC_PASSWORD_COMMAND`) y `RESTIC_REPOSITORY`, sin imprimir sus valores.

Comprobar de forma local con root que `restic` existe y que la configuración corresponde al destino **O5 de DEV**. El procedimiento existente puede usar también `RCLONE_CONFIG`, helper de acceso u otras variables de autenticación. No modificar unidades systemd ni permisos de DEV para cumplir el gate.

Con las variables de autenticación **ya disponibles en la sesión donde se ejecutará Python**, usar:

```bash
cd ~/vencira-main-check-20261108
git fetch origin main && git merge --ff-only FETCH_HEAD
python3 -m py_compile scripts/main_d1l_o5_restic_metadata_gate.py

D1L_CONFIRM_REPOSITORY_IS_DEV=YES \
  python3 scripts/main_d1l_o5_restic_metadata_gate.py
echo "D1L_SHELL_RESULT=$?"
```

Si el acceso efectivo al repositorio requiere root, usar una sesión root privada ya autenticada y cargar ahí las variables *sin publicarlas*. **No ejecutar mediante un simple `sudo python3` esperando que `sudo` preserve el entorno:** puede eliminar variables necesarias. No proporcionar secretos ni rutas a `sudo` por línea de comandos.

### Evidencia esperada

```text
D1L_READ_ONLY=YES
D1L_SNAPSHOT_COUNT=<n positivo>
D1L_NEWEST_SNAPSHOT_AGE_HOURS=<horas>
D1L_SNAPSHOT_FRESHNESS_48H=YES
D1L_RESTIC_METADATA_CHECK=PASS
D1L_BACKUP_SCOPE=OPERATOR_CONFIRMED_NOT_INDEPENDENTLY_VERIFIED
D1L_SNAPSHOT_PAYLOAD_FULL_READ=NOT_RUN
D1L_RESTORE_VERIFIED=NO
D1L_RESULT=0
D1L_SHELL_RESULT=0
```

Si el snapshot supera las 48 horas, el comando **puede** devolver `D1L_RESULT=0` porque la integridad de metadatos y la frescura son puertas distintas. No considerar el gate de actualidad satisfecho si `D1L_SNAPSHOT_FRESHNESS_48H=NO`. Si aparece `D1L_RESULT=1`, documentar la clase de error y resolver el acceso al repositorio con el custodio de O5; no usar otro repositorio sin confirmar su identidad.

## D1-M posterior (aún NO ejecutado)

Con un snapshot O5 válido e identificado: aislar un destino **nuevo y vacío** y restaurar mediante el procedimiento histórico O5 ya auditado, comprobar que el dump corresponde al esquema DEV y arrancar una instancia PG17 efímera sin puertos host ni persistencia. Solo sobre esa copia ensayar migraciones `reminders.0018→0027`, regresión y una ruta de rollback. Nunca restaurar sobre `/opt/vencira`, el volumen persistente Docker ni el PostgreSQL de DEV.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
D1_DEPLOY_EXECUTED=NO
```

## Actualización 09/11/2026 — contrato real O5 descubierto

El operador ha inspeccionado localmente `/usr/local/libexec/vencira/o5_backup_to_drive.sh` sin ejecutarlo: utiliza `/etc/vencira-backup/config.env` con permisos `root:600`, requiere variables `RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE` y `RCLONE_CONFIG`, y valida sus valores frente al repositorio O5 de PostgreSQL y ficheros de contraseña/configuración ubicados en `/etc/vencira-backup/`. El backup inserta un dump `pg_dump -Fc` cifrado con Restic mediante `--stdin-from-command`, y aplica la etiqueta `vencira-postgresql` al fichero `vencira-postgres.dump`.

**La instrucción genérica anterior de cargar variables manualmente se sustituye por un ejecutor restringido**: `scripts/main_d1l_o5_authenticated_readonly.sh` (commit `c0e888a4`). Este wrapper, ejecutado como root, valida permisos y valores esperados **sin imprimirlos**, importa el entorno igual que el servicio O5 e invoca el comprobador D1-L. **No inicia la copia programada**, no modifica el repo y no restaura datos.

El gate Python fue corregido (commit `2b97e82d`): usa `restic snapshots --tag vencira-postgresql --json`, exige etiqueta y nombre esperado `vencira-postgres.dump` en cada snapshot seleccionado, e informa la edad del último de estos snapshots, no la de cualquier otro backup.

### Ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin main && git merge --ff-only FETCH_HEAD
python3 -m py_compile scripts/main_d1l_o5_restic_metadata_gate.py
bash -n scripts/main_d1l_o5_authenticated_readonly.sh
sudo bash scripts/main_d1l_o5_authenticated_readonly.sh
echo "D1L_SHELL_RESULT=$?"
```

Esperar `D1L_SECURE_CONFIG=PASS`, `D1L_O5_CONFIG_MATCH=PASS`, `D1L_CREDENTIAL_FILE_PERMISSIONS=PASS`, `D1L_POSTGRESQL_TAGGED_SNAPSHOT_COUNT` positivo, `D1L_SNAPSHOT_FRESHNESS_48H=YES`, `D1L_RESTIC_METADATA_CHECK=PASS`, `D1L_RESULT=0`, `D1L_SHELL_RESULT=0`. `D1L_RESTORE_VERIFIED=NO` permanece correcto. El proceso puede consumir red/tiempo y omite los mensajes no redactados de Restic por seguridad. Si falla, no compartir archivos config.env, contraseñas, repositorio ni salida sin censurar.

**NO declarar restauración PASS:** para recuperación completa todavía falta un ensayo explícito sobre destino aislado, comprobar dump y restaurarlo en PostgreSQL 17 efímero, sin modificar DB persistente de DEV.
