# VENCIRA — O5: programación de copias cifradas DEV (24/10/2026)

**Estado:** artefactos versionados en GitHub; **NO activados en Ubuntu**. OAuth de copias `In production` según confirmación del titular, pero **el remoto existente necesita nueva autorización** porque obtuvo su token durante `Testing`. Trabajar solo con PostgreSQL **DEV sintético**. No extender a clientes reales: ubicación UE en Drive no verificada ni superados los controles RGPD/cifrado en reposo necesarios.

## Política aprobada por el promotor

- **DEV:** copia completa cifrada de PostgreSQL cada día a las **03:00 Europe/Madrid**.
- **Producción futura:** propuesta aprobada de **cada 6 horas**, más copia específica anterior a migraciones; **NO desplegar** la cadencia de producción en DEV ni declarar producción lista.
- **Retención propuesta:** todas las copias de los últimos 7 días; una diaria hasta 30 días; 8 semanales; 12 mensuales. **Aún no se aplica**, no hay `restic forget` ni `prune` automático para evitar borrado prematuro y revisar protección del snapshot original. Si se implanta, probar primero `restic forget --dry-run` en selección explícita de etiquetas, grupos y repositorio, seguida de ensayo de recuperación.
- La retención del **Archivo de anotaciones** del whitepaper (2 años por defecto y avisos antes del borrado) es una política completamente distinta de las copias y no queda activada por estos timers.
- Se conserva la decisión funcional del titular de permitir recuperar anotaciones «Conseguido» además de «Descartar».

## Modelo técnico

Se reutiliza el script **existente y probado** `scripts/o5_backup_to_drive.sh`, que realiza `pg_dump -Fc` desde `vencira_localcheck-db-1` con `restic backup --stdin-from-command` y `restic check`; no hay dump en claro persistido en el host. Respeta bloqueo `flock`, privilegios de root y rutas privadas de `/etc/vencira-backup`.

Los nuevos ficheros son:
- `scripts/o5_verify_existing_drive.sh` verifica configuración root:700/600, repo Restic existente y snapshot PostgreSQL original `7a2f5018` por lectura de metadatos. **No ejecuta `restic init`**.
- `scripts/o5_reauthorize_existing_drive.sh` ampliado: tras la reconexión protegida, verifica también Restic/snapshot y crea el marcador root:600 `/var/lib/vencira-o5/oauth-postproduction.epoch` solo cuando se supera. El marcador no prueba por sí solo el estado de Google (confirmado por titular).
- `scripts/o5_scheduled_backup.sh` copia sin salir del entorno DEV; deja fecha de último éxito y, en caso de fallo, marca el error en `/var/lib/vencira-o5` root:700.
- `scripts/o5_backup_health.sh` verifica copia local menor de 36 horas y ausencia de fallos recientes o estado failed de la unidad systemd.
- `deploy/o5/vencira-o5-backup.service/.timer`: programación diaria a las 03:00 zona Madrid, Persistent=true (si el VPS estuvo apagado, intenta recuperar ejecuciones perdidas).
- `deploy/o5/vencira-o5-health.service/.timer`: vigilancia diaria a las 08:00 zona Madrid. La unidad backup tiene OnFailure que activa el servicio health para fallos, y los errores quedan visibles en el journal.
- `scripts/o5_install_daily_schedule.sh`: instala scripts root-only en `/usr/local/libexec/vencira` (no ejecuta código mutable de Git durante el timer), unidades bajo `/etc/systemd/system` y hace una **copia cifrada inmediata de ensayo**, valida frescura y solo en éxito habilita los dos timers. Si falla la instalación, intenta revertir exclusivamente los ficheros de unidades/scripts instalados; **nunca borra un snapshot remoto**. Instalación deliberadamente de un solo uso, no idempotente.

**Límite crucial de notificación:** existe **alarma LOCAL en systemd/journal**, pero todavía NO hay email, push ni supervisión externa. No presentar esto como una notificación enviada. Se exige escoger/cablear canal de alerta externo antes de la entrada en producción de VENCIRA.

## 1. Reautorizar Google Drive con OAuth en producción

En el **ordenador o Android que mantenga el túnel SSH**, asegurar reenvío **LOCAL** de `127.0.0.1:53682` hacia `127.0.0.1:53682` del VPS. Ejemplo desde un ordenador: `ssh -L 127.0.0.1:53682:127.0.0.1:53682 vencira@93.93.112.172`. En Android usar cliente SSH que soporte port forwarding. **No iniciar túnel desde el propio VPS**, ni abrir puerto 53682 en firewall. Si el puerto está ocupado, diagnosticar, no matar procesos al azar.

En la SSH interactiva de Ubuntu (terminal real, sin transcript/log) ejecutar:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/o5_reauthorize_existing_drive.sh || exit 1
  bash -n scripts/o5_verify_existing_drive.sh || exit 1
  bash scripts/o5_reauthorize_existing_drive.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Rclone abre el flujo OAuth y se autoriza con la cuenta administrativa ya configurada; no compartir URL, código, Client ID, Secret, token, salida completa de navegador o archivo rclone.conf. Comunicable solo **marcadores de fase no secretos**, especialmente `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `RESTIC_SNAPSHOT_ORIGINAL=OK`, `O5_POSTPRODUCTION_RECONNECT_REGISTRADO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0`. Si falla, no ejecutar el instalador.

## 2. Instalar y probar programa diario (SOLO con fase 1 OK)

Desde SSH:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_install_daily_schedule.sh || exit 1
  sudo bash scripts/o5_install_daily_schedule.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Deberá devolver `PREFLIGHT_O5=OK`, `REPOSITORIO_PREEXISTENTE_VERIFICADO=OK`, `UNIDADES_SYSTEMD_VALIDAS=OK`, `PRIMERA_COPIA_AUTOMATIZABLE=OK`, `O5_FRESCURA_COPIA=OK`, `O5_BACKUP_DIARIO_03_MADRID=ACTIVO`, `O5_CHECK_DIARIO_08_MADRID=ACTIVO`, `RESULTADO_GLOBAL=0`. El primer ensayo añade **un snapshot nuevo** al repositorio existente; `Persistent=true` podría disparar otra copia de recuperación al habilitarse el timer después de las 03:00, lo cual no es pérdida de datos. No repetir el instalador si marca éxito.

## Inspección posterior sin secretos

```bash
sudo systemctl is-active vencira-o5-backup.timer vencira-o5-health.timer
sudo systemctl list-timers --all vencira-o5-backup.timer vencira-o5-health.timer
sudo systemctl status --no-pager vencira-o5-backup.service vencira-o5-health.service
```

Ante `RESULTADO_GLOBAL!=0` o `FASE_FALLIDA`, revisar `sudo journalctl -u vencira-o5-backup.service -u vencira-o5-health.service --no-pager -n 60`, **filtrar cualquier posible dato o credential antes de adjuntar**; remitir marcadores y fase sin secrets. Detener un timer (si fuera necesario) sin eliminar datos: `sudo systemctl disable --now vencira-o5-backup.timer vencira-o5-health.timer`. No manipular `restic forget`, `prune`, `init` ni borrar `/var/lib/vencira-o5` de forma improvisada.

## Pendientes de seguridad/operación

Residencia UE verificable para copias reales; segundo destino independiente (proteger frente a borrados y cuenta comprometida); alertas **externas** de copia fallida o desactualizada; política formal de restauración y retención; periodicidad mensual de ensayos de restauración; pruebas de autenticación OAuth tras renovación real de access token y vigilancia de caducidad/revocación; permisos de claves y RGPD. Copia PostgreSQL no incluye necesariamente documentos adjuntos y otros recursos futuros: ampliar plan de backup con inventario completo antes de producción.

## 24/10/2026 — OAuth reconectado correctamente; instalador detenido en preflight

Resultado real proporcionado por el titular: RCLONE_TOKEN_OAUTH_VALIDO=OK, RCLONE_SCOPE_DRIVE_FILE=OK, RCLONE_CONF_ROOT_PERMISOS=OK, RCLONE_GOOGLE_DRIVE_ACCESO=OK, RESTIC_SNAPSHOT_ORIGINAL=OK, RESTIC_REPOSITORIO_EXISTENTE=OK, O5_POSTPRODUCTION_RECONNECT_REGISTRADO=OK, O5_GOOGLE_OAUTH_VERIFICADO=1 y RESULTADO_GLOBAL=0. No se generaron copias durante esa reconexión. No reautorizar OAuth otra vez.

En la segunda fase, scripts/o5_install_daily_schedule.sh llegó hasta COMMIT=82cf438bbdd9ce194929b2f4b0c018ab7c22b504, pero terminó FASE_FALLIDA=RESTRICCIONES, RESULTADO_GLOBAL=1, RESULTADO_EJECUCION=1. No hubo PRELIGHT_O5=OK, no se alcanzó STACK_DEV, RESTIC, instalación de unidades ni copia de prueba. No declarar timers activos. Es una comprobación fallida de existencia/permisos/fuentes/calendarios; todavía no está identificado cuál.

Se creó scripts/o5_diagnose_daily_schedule.sh, diagnóstico exclusivamente de lectura, con indicadores individuales para destino /usr/local/libexec/vencira libre, cuatro unidades existentes/ausentes, fuentes del repo, sintaxis Bash, directorio marcador root 700, token postproducción root 600 y calendarios systemd Madrid. No modifica servidor, no imprime secretos, no instala servicio, no realiza copia. Ejecutar tras git fetch + merge --ff-only y `sudo bash scripts/o5_diagnose_daily_schedule.sh`, publicar solo marcadores OK/FALLO. Si el destino o unidad ya existía, NO borrar de forma improvisada: primero identificar su origen.

## 24/10/2026 — Preflight detallado: cinco recursos existentes, origen todavía desconocido

Después de reautorizar OAuth con éxito, el instalador abortó de forma preventiva en RESTRICCIONES y no creó copias ni activó timer. Diagnóstico de solo lectura aportado: ROOT_ACTUAL=OK, RAMA_ESPERADA=OK, GIT_TRACKED_LIMPIO=OK, MARCADOR_OAUTH_ROOT_600=OK, DIRECTORIO_ESTADO_ROOT_700=OK, calendarios backup 03 y salud 08 OK, fuentes y sintaxis de cuatro scripts OK; DIAGNOSTICO_PRECHECK_FALLAS=5.

Las cinco comprobaciones que fallaron son DESTINO_INSTALACION_LIBRE=FALLO (ya existe /usr/local/libexec/vencira) y UNIDAD_LIBRE_{BACKUP_SERVICE,BACKUP_TIMER,HEALTH_SERVICE,HEALTH_TIMER}=FALLO (ya existen cuatro unidades de nombre O5 bajo /etc/systemd/system). Como el instalador abortó antes de INSTALAR_SCRIPTS y CREATED=0, NO se puede atribuir la existencia de estos objetos a esa ejecución. Podrían ser artefactos antiguos, coincidencias legítimas o configuración distinta. NO borrar ni reemplazar a ciegas y NO afirmar temporizadores activos sin inspección.

Se creó scripts/o5_audit_existing_units.sh, comprobación de solo lectura que evita volcar secretos o contenido de unidades y, para cada script/unidad, señala si el contenido coincide byte a byte con GitHub y permisos root esperados, ubicación cargada por systemd, estado active/inactive/failed de servicios, habilitación de timers y marcador de última copia. No instala, edita, habilita, detiene ni inicia nada.

Próximo comando en Ubuntu: git fetch+merge --ff-only de integration/local-e2e-prep; sudo bash scripts/o5_audit_existing_units.sh. Traer salida de marcadores sin credenciales. Si los archivos/unit files NO coinciden con la versión GitHub, diseñar migración controlada con respaldo privado y rollback; no sobreescribir. Si son idénticos, distinguir si timer ya está activo y si hay copias útiles, antes de considerar adopción segura, copia de prueba y activación. OAuth postproducción ya OK; NO reautorizar de nuevo.

## 24/10/2026 — Auditoría de instalación preexistente: TIMERS ACTIVOS Y ARCHIVOS IDÉNTICOS

El titular aportó la auditoría de solo lectura scripts/o5_audit_existing_units.sh, con RESULTADO_AUDITORIA=0 y RESULTADO_GLOBAL=0. DIRECTORIO_INSTALADO=EXISTE, DIRECTORIO_ROOT_700=OK, ENTRADAS_NIVEL_1=3. Los tres scripts del directorio /usr/local/libexec/vencira y las cuatro unidades en /etc/systemd/system son IDENTICO_A_GITHUB, cargadas desde RUTA_ESPERADA. BACKUP_TIMER=active/enabled y HEALTH_TIMER=active/enabled; los servicios oneshot BACKUP_SERVICE y HEALTH_SERVICE están inactive (normal fuera de ejecución). DIRECTORIO_ESTADO=ROOT_700, ULTIMO_EXITO=MENOS_DE_36_HORAS y ULTIMO_FALLO=NO_REGISTRADO. No hubo cambios en archivos, timers ni repositorio remoto durante la auditoría.

Conclusión técnica: el gate RESTRICCIONES del instalador fallaba porque el destino y las unidades YA EXISTÍAN y el instalador es de único uso. No reejecutar instalación ni reautorizar OAuth. Los temporizadores están registrados, habilitados y activos; el marcador de éxito es reciente. Sin embargo el log de auditoría no prueba todavía por sí solo la fecha del snapshot remoto ni si el éxito sucedió después de la reautorización; evitar afirmarlo como restauración nueva sin comprobación.

Nuevo script GitHub scripts/o5_verify_active_schedule.sh (SOLO LECTURA): comprueba active/enabled, unidades no failed, marcadores privados, compara último éxito frente a fecha de OAuth postproduction, lee metadata de snapshots PostgreSQL cifrados via Restic y muestra próximos disparos systemd. No imprime secretos, no crea snapshots, no borra ni modifica. Ejecutar después de git fetch/merge --ff-only, con sudo bash scripts/o5_verify_active_schedule.sh; comunicar exclusivamente marcadores. Si COPIA_TRAS_REAUTORIZACION=NO o ULTIMO_SNAPSHOT_MENOS_36H=NO, evaluar un único arranque manual controlado de vencira-o5-backup.service y revalidación antes de dar el gate por cerrado.

Alerta local journal activa, no se ha configurado notificación externa por email/push, ni retención/poda automática; Google Drive no acredita residencia en la UE para datos reales. Persisten los límites DEV sintético.

## 24/10/2026 — Verificación final timers y snapshot OK; nueva copia tras OAuth pendiente

Salida REAL aportada del script scripts/o5_verify_active_schedule.sh:
```text
TIMERS_ACTIVOS_Y_HABILITADOS=OK
SERVICIOS_SIN_ESTADO_FAILED=OK
MARCADOR_EXITO_MENOS_36H=OK
COPIA_TRAS_REAUTORIZACION=NO
SNAPSHOTS_POSTGRES_EN_RESTIC=OK
ULTIMO_SNAPSHOT_ANTIGUEDAD_SEGUNDOS=5475
ULTIMO_SNAPSHOT_MENOS_36H=SI
ACCESO_RESTIC_READ_ONLY=OK
Sun 2026-10-25 02:00:00 UTC ... vencira-o5-backup.timer
Sun 2026-10-25 07:00:00 UTC ... vencira-o5-health.timer
AUDITORIA_FINAL_O5=OK
RESULTADO_GLOBAL=0
RESULTADO_VERIFICACION=0
```
**Interpretación:** programados y activos con último snapshot real reciente (5475 s, aprox. 91 min) y sin estado de fallo. El marcador de último éxito es ANTERIOR al nuevo token OAuth: hace falta una copia completa con la autorización renovada. Los horarios se traducen a **03:00 y 08:00 hora de Madrid el 25/10/2026** porque justo esa noche cambia CEST a CET (UTC+1). No es un desfase de una hora.

**Siguiente acción sugerida:** iniciar ONESHOT una vez `sudo systemctl start vencira-o5-backup.service` (no modificar ni reinstalar timer) y después ejecutar `sudo bash scripts/o5_verify_active_schedule.sh` para exigir COPIA_TRAS_REAUTORIZACION=SI, snapshot fresco y timers activos. Si el servicio falla, no imprimir secretos y no reintentar a ciegas; revisar estado y diagnóstico filtrados. No usar `restic init/forget/prune` ni alterar la DB. Confirmar estado con salida real antes de declarar O5 cerrado. Alertas siguen solo locales y Google Drive UE no verificado.
