# VENCIRA — M1-06: recuperación O5 desde equipo realmente independiente

Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## Estado y alcance

**Intento ejecutado: ABORT preventivo en preflight; recuperación desde host independiente aún NO ejecutada.** Runner `scripts/rehearse_mb1_o5_independent_host_dr.sh` (commits `21ffa6f` y `2fa8061`). Está pensado para ejecutarse **solo** en un segundo ordenador con Ubuntu, Docker, Restic, Rclone y Python 3 que NO sea el VPS de VENCIRA. No requiere que el VPS original esté disponible. Lee el backup PostgreSQL existente de Restic/Google Drive, levanta PostgreSQL 17 en contenedor efímero `--network none`, restaura el dump cifrado en tránsito y comprueba las migraciones y tablas mínimas con el validador ya probado `scripts/o5_restore_schema_contract.py`.

El script no copia secretos desde GitHub ni desde el VPS, no conecta al origen, no envía modificaciones a Drive, no crea respaldos, no publica puertos, no realiza migraciones sobre DEV ni despliega código. Solo consume el repositorio cifrado existente. Detecta firmas conocidas de los contenedores de origen y la ruta de origen; esta detección es **un bloqueo adicional, no una prueba definitiva de independencia**.

## Prerrequisitos de custodia — responsabilidad del operador, no automatizados

1. Haber confirmado fuera del chat que el equipo receptor C es físicamente/administrativamente distinto del VPS, preferiblemente con disco cifrado para contener la copia restaurada de datos reales.
2. Acceso a la cuenta de Google Drive y contraseña Restic obtenidos desde el **custodio B externo al VPS**, no de una sesión ni exportación del servidor de origen. En el segundo equipo, el custodio deja los archivos bajo control root:
   - `/etc/vencira-recovery/restic-password` (0600, root; contenido confidencial).
   - `/etc/vencira-recovery/rclone.conf` (0600, root; contiene autorizaciones, no compartir).
   - Directorio `/etc/vencira-recovery` (0700, root).
3. El remoto de Rclone en el segundo equipo se denomina `vencira_google` y accede, desde una identidad recuperada independientemente, al repositorio Restic cifrado `VENCIRA-Backups/PostgreSQL`. El origen de estas credenciales exige constancia externa; no basta trasladarlas desde el VPS.
4. No pegar valores de secretos en chat, GitHub, comando, captura ni logs. No colocar contraseñas en ficheros del repositorio.
5. Revisar el script firmado/versionado antes de ejecutar con `sudo`. El equipo debe tener suficiente espacio para almacenar temporalmente PostgreSQL con datos reales. No ejecutar en máquinas compartidas o sin protección de disco.

**No se instala automáticamente Restic, Rclone ni Docker.** Para preparación de segundo host, ver `docs/MB1_UBUNTU_X86_INDEPENDENT_HOST_SETUP_2026-10-30.md` y `scripts/preflight_mb1_ubuntu_x86_recovery.sh`.

## Un único gate cuando los prerrequisitos sean reales — pendiente

Ejecutar **EN EL SEGUNDO EQUIPO** (no en VENCIRA):

```bash
cd ~/vencira-recovery-lab/source
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_o5_independent_host_dr.sh
sudo env MB1_SECOND_HOST_O5_RECOVERY=YES_INDEPENDENT_HOST \
  bash scripts/rehearse_mb1_o5_independent_host_dr.sh
echo "MB1_DR_SECOND_HOST_EXIT_CODE=$?"
```

Esperados (no afirmarlos antes de ejecución): `MB1_DR_NO_KNOWN_SOURCE_SIGNATURE=OK`, `MB1_DR_OFFHOST_CREDENTIAL_FILES_PRESENT=OK`, `MB1_DR_INDEPENDENT_RESTIC_ACCESS=OK`, `MB1_DR_INDEPENDENT_PG17_ISOLATED=OK`, `MB1_DR_INDEPENDENT_DRIVE_PG17_RESTORE=OK`, `MB1_DR_INDEPENDENT_BASELINE_SCHEMA=OK`, `MB1_DR_INDEPENDENT_RECOVERY_DRILL=OK`, `MB1_DR_SECOND_HOST_PHASE=DONE`, `MB1_DR_SECOND_HOST_RESULT=0`, `MB1_DR_SECOND_HOST_EXIT_CODE=0`.

El operador debe documentar **sin compartir credenciales** cómo se obtuvo el acceso externo (atestación del custodio B), identidad real del segundo equipo C, ruta de restauración independiente, política de recuperación de cuenta y borrado del entorno temporal. No basta la presencia de dos archivos en esa máquina. Si falta custodia independiente, no marcar `MB1_DR_EXTERNAL_CUSTODY=VERIFIED`.

## Límites que NO permite cerrar M1-06

- El respaldo O5 actual es **solo PostgreSQL**: no cubre objetos ni diario de adjuntos.
- No incorpora recibo anti-rollback independiente ni retención monotónica comprobada.
- El PG17 temporal almacena durante la recuperación datos reales en el disco local del segundo equipo, aun con `--network none`; el cierre del contenedor no constituye borrado criptográfico de bloques. Usar disco cifrado y políticas de eliminación adecuadas.
- Verificar esquema mínimo no prueba integridad completa de negocio, antigüedad del snapshot, ausencia de omisiones ni recuperación de archivos.
- No se ha probado aún pérdida total del VPS durante una recuperación operativa ni exclusión global de escritores.

```text
MB1_DR_SECOND_HOST_RESULT=2 (último intento; preflight abortado)
MB1_DR_RECOVERY_INDEPENDENCE=REQUIRES_MANUAL_ATTESTATION
MB1_DR_EXTERNAL_CUSTODY=REQUIRES_MANUAL_ATTESTATION
MB1_DR_PACKAGE_SCOPE=PG17_ONLY
MB1_DR_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## Intento del operador — rechazo de equipo de origen (31/10/2026)

Salida entregada: `MB1_DR_ORIGIN_CONTAINER_PRESENT=ABORT`, `MB1_DR_SECOND_HOST_PHASE=PRECHECK`, `MB1_DR_SECOND_HOST_RESULT=2`. El equipo sobre el que se ejecutó contenía al menos uno de los contenedores de nombre reservado de origen (`vencira_localcheck-db-1` o `vencira_preview-db-1`). **No se puede acreditar con esta salida la identidad física del equipo**, pero sí que cumple la condición de rechazo programada. El guard detectó la firma de origen **antes** de abrir archivos de credenciales, consultar Restic o levantar PostgreSQL de recuperación. No es un fallo del backup ni demuestra que Drive o los secretos sean inaccesibles.

Marcadores de bloqueo reportados, sin alteración: `MB1_DR_RECOVERY_INDEPENDENCE=REQUIRES_MANUAL_ATTESTATION`, `MB1_DR_EXTERNAL_CUSTODY=REQUIRES_MANUAL_ATTESTATION`, `MB1_DR_PACKAGE_SCOPE=PG17_ONLY`, `MB1_DR_OPERATIONAL_ANTIROLLBACK=NOT_INTEGRATED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Decisión:** mantener `M1-06 [ ]` y el código de rechazo. **Prohibido sortear el control renombrando contenedores de DEV, suprimiendo la comprobación o falseando etiquetas.**

Siguiente ejecución diferenciada: preparar un Ubuntu x86_64 en **otro equipo/servidor** con fallo independiente del VPS IONOS. Allí, antes de proporcionar claves, usar únicamente el preflight de lectura:

```bash
cd ~/vencira-recovery-lab/source
bash scripts/preflight_mb1_ubuntu_x86_recovery.sh
echo "MB1_X86_PREFLIGHT_EXIT_CODE=$?"
```

Si el preflight de ese segundo equipo es PASS, preparar custodia B de claves y cuenta Drive mediante canales externos **sin copiarlas desde el VPS**, y solo entonces ejecutar el ensayo O5 independiente del procedimiento anterior. No hay necesidad de volver a ejecutar M1-02, la restauración O5 en el VPS ni los otros gates completados.
