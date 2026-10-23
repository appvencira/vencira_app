# VENCIRA O5 — Copias cifradas PostgreSQL en Google Drive

**Estado 23/10/2026:** O5 preflight superado. **Restic 0.16.4 y Rclone 1.60.1 ya instalados por APT**, pero `Restic 0.16.4` **NO admite `backup --stdin-from-command`**; por seguridad se detuvo el gate de compatibilidad con `RESULTADO_GLOBAL=5`, sin modificar Docker/DB ni conectar Google. Corrección **Restic oficial 0.19.1 con SHA-256 fijado** preparada en GitHub y pendiente de ejecutar en Ubuntu; no hay copias remotas ni OAuth. Cuenta de Google interna confirmada por usuario: `appvencira@gmail.com`; **no es una dirección de soporte público**. No se han recibido credenciales, ni se han instalado paquetes, ni se ha accedido a Drive. No usar información personal real.

## Objetivo y límites

Conservar copias de **`vencira_localcheck-db-1` únicamente** (stack `vencira_localcheck`, PostgreSQL 17, esquema actualmente `0014_renewal_outcomes`). No modificar ni detener la BD, API, Web u otros stacks del host. Restic cifra snapshots; Rclone gestiona la autenticación OAuth y transporte a Google Drive. **Google Drive recibe solo el repositorio cifrado**, jamás dumps `pg_dump` en claro.

Esta es una **segunda ubicación**, no un backup a prueba de borrado/ransomware: el servidor con un token Drive válido podría borrar copias. Antes de producción añadir otra ubicación con retención/inmutabilidad independiente y plan probado de recuperación completa.

## Herramientas y rutas planificadas

- `restic` (cifrado, deduplicación y snapshots) con backend `rclone:vencira_google:VENCIRA-Backups/PostgreSQL`.
- `rclone` para Drive usando **OAuth propio** con Google Drive API; 2026 se retira progresivamente el client ID compartido de Rclone. Propuesta de permisos OAuth restringidos: `drive.file`, suficiente para los archivos que cree Rclone, sujeto a una prueba de restauración real.
- Configuración final futura, archivos **solo root 0600**, carpeta **root 0700**:
  - `/etc/vencira-backup/config.env` (solo variables de rutas sin secretos)
  - `/etc/vencira-backup/rclone.conf` (token OAuth: **secreto**, nunca GitHub)
  - `/etc/vencira-backup/restic-password` (clave de cifrado: **secreto**, recuperación fuera del servidor)
- No confundir este futuro repositorio remoto con las copias **locales no cifradas** protegidas por permisos en `/home/vencira/vencira-db-backups/`. No subir jamás dicha carpeta a Drive mediante `rclone copy` o `sync` sin capa de cifrado.
- No guardar claves, token OAuth, client secret, JSON de rclone, contraseña de Restic, dumps, capturas de consentimiento ni enlaces de autorización en GitHub o en esta conversación. La contraseña de Restic y sus instrucciones de recuperación deben quedar también en un lugar externo seguro.

## Artefactos preparados (NO ejecutar backup todavía)

1. `scripts/o5_preflight_drive.sh`: diagnóstico de **solo lectura** del checkout, identidad/health del stack, migración 0014, presencia y versión de `restic`, `rclone` y herramientas, espacio en disco, existencia sin lectura de configuración root. No instala, no autentica Google ni crea copias. **Primer paso en Ubuntu**.
2. `scripts/o5_backup_to_drive.sh`: script para ejecución controlada como root **después** de conexión de Drive, inicialización de repositorio Restic cifrado y protección de secretos. Usa `restic backup --stdin-from-command -- docker exec ... pg_dump -Fc`, de modo que falla si falla `pg_dump`; no escribe un dump descifrado en almacenamiento del host. Bloqueo de concurrencia; verifica proyecto Docker `vencira_localcheck`, health DB y presencia de repositorio; ejecuta `restic check` tras copia. **No habilitado ni programado**.
3. `scripts/o5_restore_drill.sh`: verificación posterior a la primera subida; obtiene y descifra el último snapshot solo por tubería y restaura en un contenedor efímero `postgres:17-alpine --network none`, sin volumen persistente; verifica migración 0014 y BD original sin tocar. **No habilitado**.

## Diagnóstico real del servidor y fase de instalación (23/10/2026)

El usuario ejecutó `scripts/o5_preflight_drive.sh` sobre `integration/local-e2e-prep`, commit `fc42825547b1d6ed1b64aa8f1622eb25ca07851e`, sin cambios de Git. Resultado: `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, `IDENTIDAD_LOCALCHECK=OK`, última migración `0014_renewal_outcomes`; disco raíz `/dev/vda1` 232 GB de capacidad, **211 GB libres** (10 % usado). `rclone` y `restic` **NO instalados**, `openssl`, `curl`, `python3`, `flock` presentes; ficheros root de configuración y clave **no creados**. `RESULTADO_GLOBAL=0`, `SIN_INSTALACION_NI_ACCESO_GOOGLE=1`, `SIN_COPIAS_REMOTAS_NI_CAMBIOS_DB=1`.

**Script de la etapa siguiente:** `scripts/o5_install_backup_tools.sh`, commit de corrección `e8618a99224f8a163992dbcf3ade2cbbe6b6f2ca`, exclusivamente para **Ubuntu 24.04**. Verifica rama, checkout limpio, identidad y salud de `vencira_localcheck`. Ejecuta únicamente `apt-get update` e `apt-get install -y --no-install-recommends restic rclone` de repositorios **Ubuntu firmados** (sin `upgrade`, `dist-upgrade`, instalador `curl|bash`, Docker up/restart ni migraciones). Comprueba versiones, soporte `--stdin-from-command` de Restic y backend `rclone serve restic`, identidad/health e IDs intactos de API/DB/Web.

El repositorio Ubuntu 24.04 incluye Restic 0.16.4 y Rclone 1.60.1 (pueden existir actualizaciones de seguridad con sufijo de paquete diferente); se verificará la versión **real** tras instalar. Restic admite `--stdin-from-command`, que detecta el código de salida de `pg_dump` y evita snapshot de salida incompleta. Rclone usa credenciales OAuth **propias** de Google Drive porque su client ID compartido se retira en 2026.

**No se ha ejecutado aún esta instalación.** No crear `/etc/vencira-backup`, no solicitar contraseña/token, no iniciar OAuth, no subir nada a Drive en esta fase. Ejecutar una sola vez desde el usuario `vencira`:

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_install_backup_tools.sh || exit 1
  bash scripts/o5_install_backup_tools.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Solicitar salida `RESULTADO_GLOBAL=0`, `RCLONE_RESTIC_INSTALADOS_Y_PROBADOS=1`, versiones de ambos, `RESTIC_STDIN_FROM_COMMAND=OK`, `RCLONE_BACKEND_RESTIC=OK`, `CONTENEDORES_INTACTOS=1` y `HEALTH_api/db/web_preview=healthy`. Si falla, no repetir sin identificar la fase.

## Incidencia de compatibilidad Restic en Ubuntu 24.04 y solución (23/10/2026)

**Evidencia real del usuario:** sobre checkout `8eb4ef1336f76e069673e9bad5da071402a68e48`, script `scripts/o5_install_backup_tools.sh` con `SISTEMA=Ubuntu_24.04`, `LOCALCHECK_SERVICIOS=healthy`, `APT_UPDATE=OK`, `APT_INSTALL_RESTIC_RCLONE=OK` (paquetes disponibles, sin upgrade global), `RESTIC_VERSION=restic 0.16.4 compiled with go1.22.2 on linux/amd64`, `RCLONE_VERSION=rclone v1.60.1-DEV`. Falló en `VERSIONES` porque **falta `--stdin-from-command`**: `RESULTADO_GLOBAL=5`, `FASE_FALLIDA=VERSIONES`, `RESULTADO_EJECUCION=5`; log más reciente `/tmp/vencira-o5-tools.xXvCQM2W.log`. La primera salida también mostraba un intento 5 anterior. `GOOGLE_DRIVE_NO_CONECTADO=1`, `SIN_COPIAS_REMOTE_NI_MIGRACION=1`. **No repetir ese instalador antiguo ni cambiar O1–O4.**

**Causa exacta verificada contra documentación Restic:** `--stdin-from-command` **se añadió en Restic 0.17.0 (26/07/2024)**; no está en 0.16.4 de Ubuntu 24.04. Para O5 es importante: a diferencia de `restic backup --stdin`, captura código de salida del comando `pg_dump`, impidiendo considerar válido un snapshot truncado o vacío. Ubuntu puede mantener versiones antiguas por su política LTS. Fuentes: [Restic 0.17.0](https://restic.net/blog/2024-07-26/restic-0.17.0-released/), [Restic 0.16.4 stdin](https://restic.readthedocs.io/en/v0.16.4/040_backup.html). `rclone serve restic` ya es compatible según [documentación de Rclone](https://rclone.org/commands/rclone_serve_restic/).

**Corrección preparada en GitHub:** `scripts/o5_install_restic_official.sh`, versión oficial **Restic 0.19.1 para linux/amd64**, release estable fechado 05/07/2026; descarga exclusivamente desde `github.com/restic/restic/releases/download/v0.19.1/restic_0.19.1_linux_amd64.bz2`, compara antes de ejecutar con **SHA256 fijada** `f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c` (**contrastada con el campo `digest` del asset oficial** `restic_0.19.1_linux_amd64.bz2` en la API de [releases de restic](https://api.github.com/repos/restic/restic/releases/tags/v0.19.1), publicado el 05/07/2026), comprueba `backup --stdin-from-command`, `dump` y `rclone serve restic`. Prueba funcional cifrada y de restauración usando **repo temporal local**, con clave efímera, en `/tmp` (elimina al terminar). Solo tras prueba superada instala la versión oficial en `/usr/local/bin/restic`; conserva intacto paquete Ubuntu en `/usr/bin/restic`, sin `apt remove`, `upgrade` ni `dist-upgrade`. El checksum fijado verifica **integridad contra huella previamente elegida**, no equivale a declarar una verificación GPG de firma del publicador. No ejecuta la copia real, no configura Drive ni claves persistentes, no modifica ni reinicia Docker. `restic self-update` **no está disponible** en el paquete Ubuntu 0.16.4; no basar la instalación en ese comando. Fuente [restic issue #4798](https://github.com/restic/restic/issues/4798).

**Acción siguiente, única y segura (no reintentar instalador antiguo):**

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_install_restic_official.sh || exit 1
  bash scripts/o5_install_restic_official.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Esperar `SHA256_PINNED_RELEASE=OK`, `RESTIC_STDIN_FROM_COMMAND=OK`, `RCLONE_BACKEND_RESTIC=OK`, `PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK`, `RESTIC_ACTUAL=restic 0.19.1...`, `HEALTH_api/db/web_preview=healthy`, `CONTENEDORES_INTACTOS=1`, `O5_HERRAMIENTAS_COMPATIBLES=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. Si falla, revisar fase y no repetir ciegamente.

**Tras esta fase**: configurar OAuth Google Drive con autorización explícita del titular y cliente propio, custodiar Restic password fuera del servidor, inicializar repo cifrado, copiar PostgreSQL real y restaurar en PG17 temporal; luego systemd/monitorización. **O5 todavía NO operativa**. Tampoco se requiere actualizar Ubuntu 24.04 a 26.04.

## Dependencia interactiva: OAuth Google, usuario Android

Para permitir las copias habrá que crear, desde `appvencira@gmail.com`, un proyecto Google Cloud para la integración de respaldo, activar **Google Drive API**, configurar la pantalla de consentimiento para uso personal, crear credenciales **OAuth tipo Desktop** y aprobar el acceso desde navegador; rclone recomienda crear cliente propio porque su identificador compartido se retira en 2026. No se deben enviar al chat las credenciales ni códigos OAuth.

El servidor Ubuntu no tiene navegador. Rclone documenta dos métodos: autorización desde otro dispositivo con Rclone y navegador (`rclone authorize`), o **túnel de puerto SSH 53682** hasta `127.0.0.1` remoto para completar OAuth en el navegador local. En Android, el soporte del túnel dependerá del cliente SSH utilizado. No abrir este puerto al mundo ni exponer `rclone rc` sin autenticación. **La autenticación no está realizada.** Utilizar `drive.file` si el acceso a repositorio/restauración funciona; no conceder `drive` completo sin necesidad.

Documentación oficial:
- Rclone Drive/OAuth: https://rclone.org/drive/
- Rclone headless/OAuth SSH: https://rclone.org/remote_setup/
- Restic repositorio vía Rclone: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
- Restic streaming desde comando: https://restic.readthedocs.io/en/stable/040_backup.html

## Orden de ejecución previsto y estado

1. **Diagnóstico de solo lectura SUPERADO**: herramientas `rclone` y `restic` ausentes, stack healthy, 211 GB disponibles. **Siguiente:** instalación APT controlada de ambas y comprobación de capacidades con `scripts/o5_install_backup_tools.sh`, pendiente de ejecución en Ubuntu. Sin actualizar la versión del sistema operativo ni reiniciar servicios.
2. Configurar Google Cloud OAuth con autorización específica del titular (no introducir secreto en chat); crear remote Rclone dedicado bajo la identidad de respaldo.
3. Generar y proteger clave Restic, **guardar recuperación fuera del servidor**, crear repositorio remoto con `restic init`; comprobar que no hay dumps en claro y el Drive corresponde a la cuenta adecuada.
4. Ejecutar una copia manual encriptada y `scripts/o5_restore_drill.sh`; comparar esquema/recuento e integridad sin alterar base viva; verificar que el último snapshot efectivamente corresponde al equipo. Si hay errores, **no habilitar automatización**.
5. Solo tras esas pruebas, introducir servicio y temporizador `systemd` de copia diaria con registro de errores/monitorización y política inicial de retención (propuesta: 7 diarias, 4 semanales y 12 mensuales, validar capacidad y necesidades). No ejecutar `restic forget --prune` hasta confirmar recuperación y configuración de retención.
6. Para datos personales reales: completar cifrado externo, MFA del proveedor, procedimiento restauración sin acceso al host, autorización por usuarios y RGPD/LOPDGDD, y segunda copia independiente contra borrados.

**No marcar O5 como completada** por tener scripts en GitHub. Solo una ejecución que demuestre `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `O5_RESTAURACION_REMOTA_VERIFICADA=1` y automatización comprobada permite cierre. No volver a ejecutar O4 ni migración 0014.

## Incidencia de prerrequisitos del instalador oficial — 23/10/2026

- El usuario ejecutó `scripts/o5_install_restic_official.sh` con checkout `74eb5d947f1310573b72e2f70bd820242176d137` en Ubuntu 24.04 x86_64. Salida: `CONTENEDORES_PREVIOS=healthy`, **`RESULTADO_GLOBAL=1`**, `FASE_FALLIDA=PREREQUISITOS`, `RESTIC_OFICIAL_INSTALADO=0`, `RESTIC_PRUEBA_CIFRADA_LOCAL=0`, `GOOGLE_DRIVE_NO_CONECTADO=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`, `RESULTADO_EJECUCION=1`, log `/tmp/vencira-o5-restic-compat.WWBbs4SL.log`. **Abortó ANTES de descargar o instalar Restic 0.19.1.**
- El script original comprobaba en silencio `curl sha256sum bzip2 openssl restic rclone`; no indicaba qué comando faltaba. `bzip2` es un candidato probable en Ubuntu mínimo, pero **no se ha comprobado cuál faltaba**; no presentarlo como certeza.
- **Corrección GitHub `70145c2095659df3123e801f768a0886ccf0c60b`**: el script enumera cada requisito `REQUISITO_<comando>=OK/FALTA` antes de descargar; deja de depender de la utilidad externa `bzip2` y descomprime el binario oficial con módulos estándar `python3: bz2/shutil`. Mantiene intactas las puertas: descarga del release oficial, comparación con el SHA256 inmovilizado comprobado contra el digest del release de GitHub, validación de versión y `--stdin-from-command`, ensayo real de copia cifrada/restauración en directorio temporal, instalación en `/usr/local/bin/restic` solamente si supera pruebas; paquete APT `/usr/bin/restic` intacto, Docker/DB/Google no alterados. Si algún otro requisito falta, el nuevo script informa el nombre y termina sin instalar.
- **Siguiente paso:** sincronizar GitHub y ejecutar de nuevo **solo el script corregido** `scripts/o5_install_restic_official.sh` dentro de subshell, precededido de `bash -n`. Este reintento es seguro porque la primera ejecución terminó con `RESTIC_OFICIAL_INSTALADO=0`, sin descarga/instalación. No ejecutar otra vez el instalador APT `scripts/o5_install_backup_tools.sh`; no tocar O4, migraciones ni PostgreSQL.
- **Criterios de éxito aún pendientes**: `DESCOMPRESION_PYTHON_BZ2=OK`, `SHA256_PINNED_RELEASE=OK`, `RESTIC_STDIN_FROM_COMMAND=OK`, `PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK`, `RESTIC_ACTUAL=restic 0.19.1`, `CONTENEDORES_INTACTOS=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`. **OAuth, subida Drive y automatización siguen NO configurados.**
