# VENCIRA O5 — Copias cifradas PostgreSQL en Google Drive

**Estado actualizado 24/10/2026:** O5 **PRIMER BACKUP REAL CIFRADO DE POSTGRESQL DEV Y RESTAURACIÓN AISLADA SUPERADOS**. Google Drive OAuth propio `drive.file` verificado; Restic 0.19.1 y Rclone 1.60.1; repositorio remoto cifrado iniciado y probado. Snapshot PostgreSQL `7a2f5018`, PostgreSQL 17 temporal restaurado, migración `0014_renewal_outcomes` y 21 tablas públicas comprobadas. **La copia manual ya funciona, pero O5 automática NO está habilitada**: falta confirmar durabilidad OAuth (si External/Testing, refresh tokens caducan a 7 días), retención, monitorización y alertas. No datos reales de clientes ni autorización de producción.

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


## Hito O5 — Restic actualizado y copia cifrada local validada (23/10/2026)

El usuario ejecutó `scripts/o5_install_restic_official.sh` en la rama `integration/local-e2e-prep`, checkout `5acbc27635dd9d5a2d135d08021b50f16ae613cf`. Todos los requisitos presentes (`curl`, `sha256sum`, `python3`, `openssl`, `restic`, `rclone`, `grep`, `awk`, `sed`; módulo `bz2` Python disponible). `RESTIC_ANTERIOR=restic 0.16.4`, `RCLONE_VERSION=rclone v1.60.1-DEV`.

Resultados de la última ejecución real:
- `DESCARGA=OK`, `SHA256_PINNED_RELEASE=OK`, `DESCOMPRESION_PYTHON_BZ2=OK`.
- `RESTIC_STDIN_FROM_COMMAND=OK`, `RCLONE_BACKEND_RESTIC=OK`.
- **`PRUEBA_CIFRADA_Y_RESTAURACION_LOCAL=OK`**: repositorio temporal Restic cifrado, prueba de lectura/restauración y check correctos; directorio temporal eliminado, no son copias de PostgreSQL ni Google.
- **`RESTIC_ACTUAL=restic 0.19.1 compiled with go1.26.4 on linux/amd64`**; versión APT anterior conservada en `/usr/bin/restic`, sin sustituir paquetes del sistema.
- `HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, `CONTENEDORES_INTACTOS=1`, `O5_HERRAMIENTAS_COMPATIBLES=OK`, `RESULTADO_GLOBAL=0`, `RESTIC_OFICIAL_INSTALADO=1`, `RESTIC_PRUEBA_CIFRADA_LOCAL=1`, `RESULTADO_EJECUCION=0`.
- `GOOGLE_DRIVE_NO_CONECTADO=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`. Log local: `/tmp/vencira-o5-restic-compat.9oygg9cL.log`.

**Hito de herramientas cerrado. No repetir ninguno de los instaladores O5.** Este hito NO satisface O5 completo, pues la copia cifrada fue local y sintética, no se ha autorizado Drive, probado restauración remota ni programado una copia.

### Siguiente dependencia — credenciales propias de OAuth para Drive

1. Entrar en [Google Cloud Console](https://console.cloud.google.com/) usando **`appvencira@gmail.com`**, crear/seleccionar proyecto separado `VENCIRA Backups` y habilitar [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com). No habilitar servicios extra innecesarios.
2. En [Google Auth Platform](https://console.cloud.google.com/auth/overview), configurar Branding: nombre `VENCIRA Internal Backups`; audiencia **External** para cuenta Gmail personal (la opción Internal suele reservarse a organizaciones Google Workspace); correo de contacto interno. En Data Access declarar **`https://www.googleapis.com/auth/drive.file`**, alcance no sensible recomendado y limitado a archivos creados/abiertos por la aplicación. 
3. Durante el estado Testing, añadir `appvencira@gmail.com` como usuario de prueba si Google lo solicita. Importante: **los refresh tokens de apps OAuth External en Testing caducan aproximadamente a los 7 días** con scopes Drive; **antes de automatizar copias** revisar que OAuth esté en estado **In Production** y las condiciones de verificación aplicables al `drive.file` concreto. `In Production` corresponde al **estado OAuth de este cliente administrativo**, no al lanzamiento de VENCIRA como producto ni a la autorización para datos reales.
4. En [Google Auth Platform > Clients](https://console.cloud.google.com/auth/clients) crear un cliente OAuth de tipo **Desktop app**, nombre `VENCIRA Backup Rclone`. Guardar Client ID/Client Secret en gestor de secretos personal, no pegarlos en chat ni en GitHub. **No descargar/subir archivos JSON de credenciales a repositorio**.
5. Solo después configurar el servidor con `rclone config` bajo configuración **root 0600** y una sesión OAuth mediante el procedimiento oficial `https://rclone.org/remote_setup/`; para Android se confirmará método seguro de navegador con túnel SSH al puerto local 53682 o autorización en equipo con Rclone. No abrir ese puerto a Internet ni entregar tokens al chat. El servidor necesitará un `rclone.conf` propio, distinto del de otros proyectos.
6. Una vez conectado, probar alcance `drive.file`, repo Restic cifrado y restablecimiento antes de automatizar; si `rclone 1.60.1` presenta incompatibilidades con APIs actuales, actualizarlo de manera aislada con comprobaciones y sin cambiar Docker.

Fuentes oficiales: [Rclone configuración Drive y cliente propio](https://rclone.org/drive/#making-your-own-client-id), [Rclone OAuth en servidor sin navegador](https://rclone.org/remote_setup/), [Google OAuth scopes Drive](https://developers.google.com/workspace/drive/api/guides/api-specific-auth), [Google OAuth ciclo de vida de refresh tokens](https://developers.google.com/identity/protocols/oauth2/#expiration).

## Actualización — OAuth Desktop creado por el usuario (23/10/2026)

**Nuevo dato confirmado:** el usuario informó literalmente **«OAuth creado»**. Se considera completada la **creación del cliente OAuth en Google Cloud** bajo la cuenta interna `appvencira@gmail.com`, **según declaración del titular**. Esto **NO acredita** todavía que Google Drive API esté habilitada, que el alcance realmente concedido sea `drive.file`, que Audience esté en *In production*, que haya un refresh token válido o que el servidor haya recibido permisos. **Google Drive aún NO está enlazado al servidor y no existe copia remota.** No volver a pedir al usuario que cree el cliente que ya creó.

**Siguiente fase Github preparada:** script `scripts/o5_configure_drive_oauth.sh`, commit de protección de ruta `165181d46cec86a3d4a553bac04b0a6d703531f1`, destinado a Ubuntu 24.04, proyecto `vencira_localcheck`, Restic 0.19.1 y Rclone instalado. No migra, no reinicia, no crea backups. Prepara `/etc/vencira-backup` root 0700 y `rclone.conf` root 0600, **sin sobrescribir un remoto existente**. Ejecuta `rclone config` de forma **interactiva** para que el titular introduzca su *Client ID* y *Client Secret* de Google Cloud **directamente en el terminal privado** sin enviarlos a ChatGPT/GitHub. Remoto fijo `vencira_google`, tipo `drive`, único scope `drive.file`; nunca seleccionar `drive` completo. Una vez terminado, valida permisos/configuración sin imprimir secretos y prueba `rclone lsd vencira_google:` descartando por completo el listado de archivos; éxito `OAUTH_PROPIO_SCOPE_DRIVE_FILE=OK`, `RCLONE_CONF_ROOT_PERMISOS=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_OAUTH_CONFIGURADO=1`, `RESULTADO_GLOBAL=0`.

**Acceso remoto desde navegador:** en el método recomendado de [Rclone Remote Setup](https://rclone.org/remote_setup/#configuring-using-ssh-tunnel), el cliente SSH conectado al servidor ofrece **reenvío de puerto local** `127.0.0.1:53682` hacia `127.0.0.1:53682` del servidor. Mantener el túnel activo; en `rclone config`, seleccionar **Y** en autorización automática, y abrir la URL `http://127.0.0.1:53682/auth?state=...` que salga en terminal en **el navegador del mismo dispositivo que mantiene el túnel**. Usar exclusivamente la cuenta Google interna. No exponer el puerto al público, usar capturas de secretos o pegar el enlace OAuth/estado/token en el chat. Para SSH desde ordenador: `ssh -L 127.0.0.1:53682:127.0.0.1:53682 vencira@<servidor>`. Para Android, habilitar equivalente en la aplicación SSH. Si ese cliente no permite túneles, **no ejecutar el flujo de navegador Y**: elegir **N** y usar `rclone authorize` desde otro dispositivo con Rclone y navegador siguiendo la documentación oficial (tampoco se transmitirá token al chat).

**Aviso de privacidad de terminal:** `rclone config` puede **mostrar** el Client Secret y el token de Google en su resumen interactivo, de modo que **no copiar la transcripción de esta fase**. Solo comunicar los indicadores finales del script o el nombre de la fase fallida (sin textos intermedios confidenciales). Desactivar la grabación de terminal. No enviar Client ID, Client Secret, `rclone.conf`, URL de autorización ni códigos OAuth a ChatGPT. El secreto Restic será distinto y se generará únicamente **después** de comprobar Drive, con custodia fuera del servidor.

**Procedimiento SSH de un bloque (después de establecer túnel local, o disponer de alternativa headless):**
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_configure_drive_oauth.sh || exit 1
  bash scripts/o5_configure_drive_oauth.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
**No se ha ejecutado aún.** No automatizar copias ni declarar O5 completada por la mera autenticación. Verificar política *In production* frente a caducidad de refresh token para `External/Testing` antes de habilitar cron/systemd. A continuación: repo Restic cifrado, copia PG real y recuperación aislada.

## Dependencia interactiva: OAuth Google, usuario Android

Para permitir las copias habrá que crear, desde `appvencira@gmail.com`, un proyecto Google Cloud para la integración de respaldo, activar **Google Drive API**, configurar la pantalla de consentimiento para uso personal, crear credenciales **OAuth tipo Desktop** y aprobar el acceso desde navegador; rclone recomienda crear cliente propio porque su identificador compartido se retira en 2026. No se deben enviar al chat las credenciales ni códigos OAuth.

El servidor Ubuntu no tiene navegador. Rclone documenta dos métodos: autorización desde otro dispositivo con Rclone y navegador (`rclone authorize`), o **túnel de puerto SSH 53682** hasta `127.0.0.1` remoto para completar OAuth en el navegador local. En Android, el soporte del túnel dependerá del cliente SSH utilizado. No abrir este puerto al mundo ni exponer `rclone rc` sin autenticación. **La autenticación no está realizada.** Utilizar `drive.file` si el acceso a repositorio/restauración funciona; no conceder `drive` completo sin necesidad.

Documentación oficial:
- Rclone Drive/OAuth: https://rclone.org/drive/
- Rclone headless/OAuth SSH: https://rclone.org/remote_setup/
- Restic repositorio vía Rclone: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
- Restic streaming desde comando: https://restic.readthedocs.io/en/stable/040_backup.html

## Orden de ejecución previsto y estado

1. **Herramientas SUPERADAS**: diagnóstico, Rclone APT `1.60.1-DEV`, Restic oficial `0.19.1`, SHA, `--stdin-from-command` y recuperación cifrada local probados. No repetir scripts de instalación. **Siguiente: cliente OAuth propio de Google Drive para la cuenta interna**, sin compartir credenciales.
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

## Incidencia 23/10/2026 23:31 — remoto existente y diagnóstico sin sobrescritura

El usuario ejecutó `scripts/o5_configure_drive_oauth.sh` desde checkout `27659dc5eec76a9652cee865385534418d60b7fd`. Se verificaron `RESTIC=0.19.1`, `RCLONE=DISPONIBLE` y `STACK_LOCALCHECK=healthy`. El script **se detuvo correctamente** en `PREPARAR_CONFIG_ROOT` porque **ya existía el remoto `vencira_google`** en el archivo Rclone privado:

- `ERROR: remoto vencira_google existente. No sobrescribir.`
- `RESULTADO_GLOBAL=3`, `FASE_FALLIDA=PREPARAR_CONFIG_ROOT`, `RESULTADO_EJECUCION=3`.
- `COPIA_DRIVE_NO_EJECUTADA=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`.
- Este resultado **no demuestra** ni que OAuth esté completo ni que esté averiado. Puede tratarse de un remoto configurado previamente. **No borrarlo, sobrescribirlo ni repetir el configurador interactivo sin diagnosticarlo.** No se hizo upload.

**Nuevo script GitHub `scripts/o5_probe_existing_drive.sh`, commit `bc8bf28bfe941c3fd5b35ef1e3da4211d565c70e`:**
verifica rama/Git limpio, Restic 0.19.1, proyecto Docker y salud, directorio `/etc/vencira-backup` root:700 y `rclone.conf` root:600, evitando symlinks; inspecciona con Python solo nombres de claves del remoto `vencira_google`, tipo `drive`, scope exacto `drive.file`, presencia de Client ID/Secret propio y token OAuth JSON con refresh token. **No imprime sus valores ni rutas de Google Drive.** Finalmente ejecuta **solo lectura de metadatos** `rclone lsd vencira_google:`, descartando stdout/stderr para no filtrar carpetas ni secretos. Puede renovar el token OAuth localmente en `rclone.conf`, pero no crea, elimina, sincroniza ni descarga archivos en Drive. Tampoco modifica la DB ni Docker. Solo después `O5_OAUTH_CONFIGURADO=1`.

**Próximo bloque de Ubuntu (único, sin copiar la sesión OAuth anterior):**
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_probe_existing_drive.sh || exit 1
  bash scripts/o5_probe_existing_drive.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Se pueden compartir **solo los indicadores sin secretos que genere el nuevo script**, especialmente `CONFIG_PRIVADA_ROOT_0700_0600`, `RCLONE_TIPO_DRIVE`, `RCLONE_SCOPE_DRIVE_FILE`, `RCLONE_CLIENTE_OAUTH_PROPIO`, `RCLONE_TOKEN_OAUTH`, `RCLONE_GOOGLE_DRIVE_ACCESO`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION`. Si falla, resolver el estado preciso sin revelar token/secret ni volver a empezar. Si resulta válido, **no volver a configurar OAuth**; continuar con clave Restic externa, repositorio cifrado, prueba de subida y restauración aislada. Rclone en sí no puede confirmar mediante esta prueba qué cuenta Google concreta se seleccionó; el usuario debe haber autorizado `appvencira@gmail.com`.


## Incidencia 23/10/2026 23:31 — token OAuth inválido en remoto existente

**Evidencia del usuario**: el diagnóstico de solo lectura `scripts/o5_probe_existing_drive.sh` se ejecutó en GitHub checkout `6e35ffb6e20e8bb7847959ce8ee9efa836b98d33` y confirmó:
`HEALTH_api=healthy`, `HEALTH_db=healthy`, `HEALTH_web_preview=healthy`, `CONFIG_PRIVADA_ROOT_0700_0600=OK`, `RCLONE_TIPO_DRIVE=OK`, `RCLONE_SCOPE_DRIVE_FILE=OK`, `RCLONE_CLIENTE_OAUTH_PROPIO=OK`. **Falló** `RCLONE_TOKEN_OAUTH=NO_VALIDO`: `RESULTADO_GLOBAL=5`, `FASE_FALLIDA=METADATOS`, `RCLONE_EXISTENTE_VALIDADO=0`, `RESULTADO_EJECUCION=5`. `CONFIG_NO_SOBRESCRITA=1`, `SIN_ARCHIVOS_CREADOS_EN_DRIVE=1`, `SIN_BACKUP_NI_MIGRACIONES=1`. El token no contiene JSON válido; **no se puede concluir que haya acceso a Drive**. No publicar el valor del campo ni enviar archivo de configuración al chat.

**Resolución preparada en GitHub (NO ejecutada):** `scripts/o5_reauthorize_existing_drive.sh` commit `a4a33e0ad5b0f2807e6ecedcc53960bf624d90f5`. Verifica checkout limpio, Restic 0.19.1, salud e identidad de los contenedores y permisos del archivo root 0600. Comprueba que el remoto existente usa `drive`, `drive.file` y contiene OAuth Client ID/Secret. Exige terminal interactivo y **túnel SSH local navegador hacia localhost:53682**; guarda temporalmente configuración anterior con permisos root 0700/0600 y ejecuta **`rclone config reconnect vencira_google:`**, sin eliminar ni recrear el remoto ni modificar ID/Secret. Si falla, restaura la configuración privada anterior y elimina la copia temporal; si funciona, valida JSON de token en local sin mostrar su contenido y comprueba `rclone lsd` descartando salida. El listado consulta solo metadatos, no crea archivos; una autenticación correcta puede reescribir el token del archivo privado. No realiza backup, migra ni reinicia Docker.

Rclone ofrece oficialmente `config reconnect` para reautenticar el remoto existente: https://rclone.org/commands/rclone_config_reconnect/ . Para servidores sin navegador recomienda el túnel SSH local `127.0.0.1:53682`: https://rclone.org/remote_setup/ . El dispositivo que abre la URL OAuth local debe ser **el mismo** que mantiene el túnel SSH. **Si no hay túnel, no ejecutar la fase interactiva**: habilitar el túnel en aplicación SSH antes (en Android requiere cliente que lo soporte; desde PC `ssh -L 127.0.0.1:53682:127.0.0.1:53682 vencira@dev.vencira.es`). No abrir puertos 53682 públicos. Si Rclone no puede reconectar con token malformado, revisar `FASE_FALLIDA` y preparar una edición del remoto conservando cliente propio, nunca publicar credenciales.

**Bloque SSH siguiente — solo con túnel activo:**

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_reauthorize_existing_drive.sh || exit 1
  bash scripts/o5_reauthorize_existing_drive.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

**No copiar transcripción ni capturas de OAuth**: Rclone puede imprimir URL de autorización con `state`, token u otra información privada. Compartir únicamente estos indicadores seguros: `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_SCOPE_DRIVE_FILE=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`, o `FASE_FALLIDA` si aborta. Luego iniciar preparación de Restic remoto cifrado, primera copia y recuperación aislada, siempre sin datos reales/producción.


## Incidencia 23/10/2026 — puerto local de autorización 53682 ocupado

**Evidencia de Ubuntu aportada por usuario**, con el último intento de `scripts/o5_reauthorize_existing_drive.sh`:
- Inició `rclone config reconnect vencira_google:` y respondió `y` a `Use auto config?`.
- Rclone informó `listen tcp 127.0.0.1:53682: bind: address already in use`, por lo que **no pudo iniciar el servidor OAuth local**. No afirma problema en Google, Client ID o Drive.
- `COPIA_CONFIG_PRIVADA_TEMPORAL=OK` y `CONFIG_ORIGINAL_RESTAURADA=1`, luego `RESULTADO_GLOBAL=1`, `FASE_FALLIDA=RCLONE_RECONNECT`, `O5_GOOGLE_OAUTH_VERIFICADO=0`, `SIN_ARCHIVOS_CREADOS_EN_DRIVE=1`, `SIN_COPIAS_NI_MIGRACIONES=1`, `RESULTADO_EJECUCION=1`. **La recuperación previa del archivo OAuth fue exitosa, y Drive aún no está autorizado/validado**.
- Causa de colisión **por identificar**, no asumir proceso culpable. Posibles procesos OAuth de Rclone anteriores o un túnel SSH mal orientado/arrancado en el propio Ubuntu. En configuración oficial el **túnel `ssh -L` se crea en el dispositivo con navegador**, no desde el servidor remoto, para reenviar su `localhost:53682` hacia `127.0.0.1:53682` de Ubuntu. Ni `sshd` ni otro servicio deben terminarse sin comprobar el dueño del puerto.

**Nuevo script de diagnóstico de SOLO LECTURA** `scripts/o5_diagnose_oauth_port.sh` (commit `718c12fca1b93de070fdeb188e3f0435555f84e9`): valida Git/identidad/health de `vencira_localcheck`, hace prueba de `bind` a `127.0.0.1:53682` sin escuchar, y, si ocupado, usa `ss -H -lntp` para mostrar únicamente nombre de proceso, PID, UID e interfaz. **No lee parámetros de procesos, token ni credenciales; no mata procesos; no modifica Google/DB; no elimina sockets ni reinicia contenedores**.

Bloque único siguiente en Ubuntu:

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_diagnose_oauth_port.sh || exit 1
  bash scripts/o5_diagnose_oauth_port.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

**Interpretación posterior:** si `PUERTO_53682=OCUPADO`, examinar `PUERTO_PROCESO` y `PUERTO_PID` antes de decidir liberar servicio/sesión, **nunca `kill -9` genérico, reinicios ni desactivar seguridad**. Si `PUERTO_53682=LIBRE`, verificar antes la orientación del túnel del lado navegador y solo entonces volver a `scripts/o5_reauthorize_existing_drive.sh`; si falla de nuevo con el mismo error, comprobar qué proceso aparece **durante** el intento. El script confirma únicamente el estado en el instante de la prueba. No usar `rclone authorize` en el mismo servidor si el puerto sigue ocupado. Fuente: https://rclone.org/remote_setup/#configuring-using-ssh-tunnel .

**Pendiente:** OAuth válido, primera copia PG17 cifrada a Drive, ensayo de restauración y calendarización. O5 no completada; no introducir datos personales reales.

## OAuth bloqueado por usuario de prueba ausente — 24/10/2026

**Nueva evidencia del usuario:** en el navegador del PC, tras liberar el puerto `127.0.0.1:53682` y continuar la autorización de `rclone config reconnect vencira_google:`, la pantalla Google mostró **«Acceso bloqueado: VENCIRA Internal Backups no ha completado el proceso de verificación ... la app se está probando y solo pueden acceder testers aprobados»**, cuenta `appvencira@gmail.com`, **`403: access_denied`**. Esto es compatible con que la app OAuth sea **External / Testing** y falte añadir la cuenta a **Google Auth Platform → Audience → Test users**. No demuestra un problema de Rclone, fallo de token/credenciales o de PostgreSQL. **No hay autorización Google terminada ni snapshots remotos; no declarar O5 funcional.**

**Acción del titular en navegador (sin compartir credenciales):**
1. Acceder a [Audience Google Auth Platform](https://console.cloud.google.com/auth/audience), seleccionar proyecto **VENCIRA Backups** correspondiente al Client ID OAuth existente.
2. Bajo **Test users / Usuarios de prueba**, pulsar **Add users / Añadir usuarios**, añadir la dirección interna **`appvencira@gmail.com`**, guardar. Comprobar que la cuenta aparece.
3. Continuar la autorización pendiente abriendo de nuevo el enlace localhost de la sesión OAuth **en el navegador del PC donde funciona el túnel SSH**. Si el navegador/sesión Rclone cerró o el enlace expiró, interrumpir con Ctrl+C, comprobar que el script restauró `rclone.conf`, y volver a ejecutar **únicamente** `scripts/o5_reauthorize_existing_drive.sh` desde checkout actualizado con túnel SSH local funcionando. No repetir scripts de instalación ni borrar remoto. No compartir token, URL OAuth completa ni logs interactivos.
4. Tras éxito, obtener **solo** indicadores `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`. Si la pantalla persiste, comprobar que el navegador ha elegido la misma cuenta y proyecto Client ID, la lista de test users y la persistencia del guardado.

**Duración de credenciales:** Google indica que en proyectos OAuth **External / Testing**, el refresh token expira a los **7 días** si incluye scope Google Drive. Permite completar la prueba actual; **no** activar copias desatendidas mientras dependa de ese token de siete días. Antes de automatizar, evaluar transición de consentimiento OAuth a *In production*, sus requisitos y su adecuación a uso administrativo personal con `drive.file`, sin confundirlo con habilitar VENCIRA para clientes reales ni elevar permisos. Fuentes oficiales: [Manage App Audience](https://support.google.com/cloud/answer/15549945), [OAuth 2.0 access](https://developers.google.com/identity/protocols/oauth2), [OAuth state overview](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview).

**Estado de cambios:** documentación solamente. No se han editado scripts, ni conectado Drive, ni instalado software nuevo, ni modificado BD por esta incidencia. Siguiente paso actual es **añadir tester**, luego reintentar consentimiento y verificar marcadores sin secretos.

## Consentimiento OAuth del navegador completado — 24/10/2026

El usuario comunicó que, tras añadir el usuario de pruebas de Google y autorizar desde el PC con túnel SSH local, la página OAuth mostró **«Success! All done. Please go back to rclone.»**. Es evidencia de que **el paso de consentimiento del navegador finalizó**, pero **todavía no confirma** que el script en Ubuntu validara un nuevo token ni que `rclone lsd vencira_google:` tenga acceso. No confundir éxito web con `O5_GOOGLE_OAUTH_VERIFICADO=1`, con repositorio Restic remoto creado ni con backup ejecutado.

Siguiente acción inmediata: volver a la terminal SSH sin cerrar el túnel, terminar `scripts/o5_reauthorize_existing_drive.sh` y compartir **solo los indicadores sin secretos**: `RCLONE_TOKEN_OAUTH_VALIDO`, `RCLONE_SCOPE_DRIVE_FILE`, `RCLONE_CONF_ROOT_PERMISOS`, `RCLONE_GOOGLE_DRIVE_ACCESO`, `O5_OAUTH_CONFIGURADO`, `O5_GOOGLE_OAUTH_VERIFICADO`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION`, o `FASE_FALLIDA`. **NO enviar la transcripción de Rclone OAuth, token, Client ID/secret ni URL localhost completa**. Si termina con error, el script intenta restaurar la configuración original protegida. Tras éxito verificable, iniciar fase separada de inicialización Restic cifrado y primera restauración remota. Tener presente que OAuth External en Testing puede caducar a siete días: no automatizar copias todavía.

## 24/10/2026 — Código OAuth recibido; solicitud de Shared Drive aún pendiente

El usuario mostró la salida del servidor tras la pantalla de éxito OAuth: `NOTICE: Waiting for code...` seguido de **`NOTICE: Got code`** (éxito del intercambio del código de navegador con Rclone), más dos avisos `channel 2: open failed: connect failed: Connection refused` del reenvío SSH después de recibir el código. Los avisos de túnel posteriores no demuestran por sí mismos fallo de OAuth; no interpretarlos como error si `rclone` sigue adelante.

**Punto interactivo vigente:** Rclone pregunta `Configure this as a Shared Drive (Team Drive)? [y/n]`. Para el Drive personal exclusivo `appvencira@gmail.com`, seleccionar **`n`** y pulsar Enter; no se utiliza unidad compartida Workspace. Esperar a que concluya `scripts/o5_reauthorize_existing_drive.sh` y **no asumir todavía éxito definitivo**: siguen pendientes `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`.

El enlace `localhost` OAuth compartido por error contiene parámetro `state`; **no reproducir ese valor en documentación**, ni registrar URL/token/secret de la sesión. Solicitar solo marcadores terminales sin credenciales. Todavía no hay evidencia de repositorio Restic remoto ni de copias cifradas subidas a Drive.

## 24/10/2026 — OAuth Google Drive VERIFICADO en Ubuntu

El usuario aportó salida final de `scripts/o5_reauthorize_existing_drive.sh` (tras `Got code`, elección **n** en Shared Drive y autorización para `appvencira@gmail.com`):

```text
RCLONE_TOKEN_OAUTH_VALIDO=OK
RCLONE_SCOPE_DRIVE_FILE=OK
RCLONE_CONF_ROOT_PERMISOS=OK
RCLONE_GOOGLE_DRIVE_ACCESO=OK
O5_OAUTH_CONFIGURADO=1
RESULTADO_GLOBAL=0
O5_GOOGLE_OAUTH_VERIFICADO=1
SIN_ARCHIVOS_CREADOS_EN_DRIVE=1
SIN_COPIAS_NI_MIGRACIONES=1
RESULTADO_EJECUCION=0
```

**Hito cerrado:** Rclone autentica y puede consultar Drive desde `vencira_localcheck`, con configuración root privada. **No repetir reconnect ni OAuth**, ni reinstalación de herramientas. No se ha creado copia ni repositorio Restic remoto todavía. Cualquier token o URL OAuth sensible mencionado durante el flujo no debe incluirse aquí ni repetirse. Se exige un repositorio cifrado Restic antes de subir cualquier información de PostgreSQL.

**Siguiente hito**: crear `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` mediante Restic con contraseña aleatoria protegida en `/etc/vencira-backup/restic-password`, backup de esa contraseña **fuera del servidor y de Google Drive**, y una copia/restauración de **datos ficticios**. Comprobar existencia previa, permisos root y acceso Drive antes de realizar cambios. La contraseña jamás en GitHub, logs ni chat; usuario debe custodiarla para recuperar las copias si se pierde el servidor. No crear todavía backup PostgreSQL ni schedule hasta recuperar contenido de prueba y realizar restauración PostgreSQL 17 aislada posteriormente.

Fuentes: [Restic con rclone](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html), [Rclone Drive scope drive.file](https://rclone.org/drive/#scopes), [Google OAuth Testing — refresh tokens](https://developers.google.com/identity/protocols/oauth2).

## 24/10/2026 — Alta segura del repositorio Restic cifrado (pendiente de ejecución)

**Estado de entrada contrastado:** el usuario ha verificado `RCLONE_TOKEN_OAUTH_VALIDO=OK`, `RCLONE_SCOPE_DRIVE_FILE=OK`, `RCLONE_CONF_ROOT_PERMISOS=OK`, `RCLONE_GOOGLE_DRIVE_ACCESO=OK`, `O5_OAUTH_CONFIGURADO=1`, `O5_GOOGLE_OAUTH_VERIFICADO=1`, `RESULTADO_GLOBAL=0` y `RESULTADO_EJECUCION=0`. La cuenta Google interna es `appvencira@gmail.com`. OAuth quedó conectado, pero **antes de ejecutar la nueva fase NO existía una prueba de carga, repositorio Restic remoto ni respaldo PostgreSQL remoto**.

**Nuevo script único**: `scripts/o5_init_restic_drive.sh` en GitHub, con correcciones de permisos Git `7e71728e9e61467f7f4eadb39a8e32d26d597d84`, export de la ruta Rclone y comprobaciones previas `cce8a9905259662de0bbc786a17f1ed3f3302c38`, y simplificación de la prueba de backend `1b2251b5ab5b9f7a9b36a4e6e3ca962b9e117f9c`. **Todavía NO ejecutado en Ubuntu**.

Contrato de seguridad:
- **Root + TTY privada** y lock `/run/lock/vencira-o5-backup.lock`, rama Git correcta, Git limpio, Restic 0.19.1, Rclone `serve restic`, tres servicios healthy con etiqueta exclusiva `vencira_localcheck`.
- `/etc/vencira-backup` directorio `root:700`, `rclone.conf` `root:600`, `vencira_google` limitado a `drive.file` con OAuth propio/token válido, comprobación de acceso remoto de sólo lectura. **No reautoriza ni sobrescribe el remoto existente**.
- Rechaza crear `/etc/vencira-backup/restic-password` o `config.env` si cualquiera ya existe; intenta impedir pisar un repo Restic con fichero `config` remoto ya creado. Nunca poner contraseña en GitHub, archivos en repositorio ni salida del chat.
- Genera clave cifrado Restic de **256 bits aleatorios** con Python `secrets`, **la muestra únicamente en TTY privado** (NO copiar transcripción completa), exige que el titular la copie fuera del servidor y de Drive, la vuelva a introducir con eco deshabilitado y confirme `GUARDADA`. Después crea `restic-password` `root:600` y `config.env` `root:600` con solo rutas públicas. El archivo root tiene la copia operativa: la clave fuera del host es vital ante desastre. **Si se pierde la clave, las copias no son recuperables.**
- Inicializa `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` con Restic, luego hace un backup/restauración de un archivo **SINTÉTICO** y `restic check`; imprime únicamente marcadores. Restic cifra antes de que Rclone suba; no se envían dumps PostgreSQL ni datos reales a Drive en esta fase.
- En fallo tras crear clave o repositorio, no repetir ciegamente el script; **los archivos de clave/config se preservan deliberadamente para recuperación**. No activar automatización todavía. Este script **no modifica Docker ni migra DB**, pero sí crea objetos cifrados de prueba en Drive si todo funciona.

Ejecución en Ubuntu (desde cuenta `vencira`; el script es de root por necesitar proteger la clave y config):

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_init_restic_drive.sh || exit 1
  sudo bash scripts/o5_init_restic_drive.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

**PRIVACIDAD DE LA SALIDA:** El script imprime UNA VEZ la clave de cifrado para que el usuario la guarde en un gestor de contraseñas independiente. **No enviar toda la transcripción SSH ni capturas al chat ni registrar la sesión en terminal.** Informar exclusivamente los marcadores finales seguros (sin la clave): `GOOGLE_DRIVE_ACCESIBLE`, `RESTIC_REPOSITORIO_REMOTO`, `PRUEBA_CIFRADA_DRIVE_RESTAURACION`, `RESTIC_CHECK`, `CLAVE_GUARDADA_FUERA_DEL_SERVIDOR`, `CLAVE_EN_ARCHIVO_PRIVADO_ROOT_0600`, `REPO_RESTIC_REMOTO_INICIALIZADO`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION`, o sólo `FASE_FALLIDA` si fracasa.

**No declarar éxito** antes de la salida del usuario. Siguiente hito después del backup de prueba: ejecutar `scripts/o5_backup_to_drive.sh` para base `vencira_localcheck-db-1`, y `scripts/o5_restore_drill.sh` a PostgreSQL efímero (probar ambos/adaptarlos a snapshots por tag). Tras comprobar recuperación real, habilitar copias automáticas con retención, monitorización y atención a la caducidad de refresh token Google External/Testing de siete días: cambiar estado OAuth cuando sea adecuado y reautorizar si el token sigue siendo de Testing. Ninguno de estos hitos autoriza datos personales reales/producción.

## Incidencia 24/10/2026 — lectura de TTY falla antes de custodiar la clave

**Evidencia real Ubuntu (usuario):** al ejecutar `scripts/o5_init_restic_drive.sh` en checkout `b2d0bf698ff208a2986aab24d9cc99563e3ebad7`, pasó gates `HEALTH_api/db/web_preview=healthy`, `RCLONE_PRIVADO_SCOPE_Y_TOKEN=OK` y `GOOGLE_DRIVE_ACCESIBLE=OK`. Luego, en `CUSTODIA_CLAVE`, Python terminó con `io.UnsupportedOperation: File or stream is not seekable.` antes de mostrar/confirmar y guardar la clave de recuperación. El usuario aportó el mismo fallo dos veces; **no confundirlo con ejecuciones parcialmente exitosas**.

Resultado certificado por script: `RESULTADO_GLOBAL=1`, `RESULTADO_EJECUCION=1`, `FASE_FALLIDA=CUSTODIA_CLAVE`, `CLAVE_PRIVADA_EN_SERVIDOR=0`, `REPO_RESTIC_REMOTO_INICIALIZADO=0`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA=0`, `POSTGRES_NO_RESPALDADO_AUN=1`, `SIN_MIGRACIONES_NI_REINICIOS=1`. **No se creó contraseña persistente, repositorio Restic ni backup PostgreSQL**; Drive OAuth continúa conectado. El script abortó ANTES de crear `restic-password` o `config.env`. No volver a entrar en OAuth ni reinstalar Restic.

**Causa en el script original:** Python empleaba `open("/dev/tty", "r+")` para leer y escribir un único stream. Al cambiar entre estas operaciones sobre un dispositivo no reposicionable, el buffer puede llamar `seek()` y generar `UnsupportedOperation`. No es problema de contraseñas, Rclone ni Google.

**Corrección GitHub:** `scripts/o5_init_restic_drive.sh` commit `48a95556d7cbd4c5cc026824a04cf734eb77508a`. Usa **`/dev/tty` abierto en dos flujos separados**: salida solo `"w"` con `flush`, entrada solo `"r"`; la segunda introducción oculta se sigue haciendo mediante `getpass.getpass(stream=tty_out)` y la confirmación `GUARDADA` mediante `tty_in.readline()`. Python recibe código por heredoc y por ello no debe usar `input()` sobre stdin. Mantiene `secrets.token_hex(32)`, comprobación constante de 256 bits, `O_CREAT|O_EXCL|O_NOFOLLOW` y permisos root:0600. **Prueba fuera del servidor:** se reprodujo el diálogo modificado en una **pseudo-tty local** con entrada oculta simulada, reintroducción de clave y `GUARDADA`: `TTY_EXIT_CODE=0`, `TTY_TEST_STAGES=2`, `TTY_COMMITMENT_WRITTEN=True`, `TTY_SUCCESS_OUTPUT=True`. Esta prueba NO equivale a la ejecución de creación de repositorio ni OAuth en Ubuntu del usuario.

**Próxima acción en Ubuntu, segura solo porque la salida anterior confirmó que no quedó ninguna clave/config persistente:** sincronizar rama y ejecutar **solo la versión corregida** con una subshell; el mismo script vuelve a rechazar si ya existen `/etc/vencira-backup/restic-password` o `config.env`, o si detecta repo ya inicializado.

```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_init_restic_drive.sh || exit 1
  sudo bash scripts/o5_init_restic_drive.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

**Privacidad extrema:** el programa mostrará una clave de recuperación que el usuario debe guardar en un **gestor de contraseñas externo a Ubuntu y Drive** y reintroducir sin eco; no capturar, copiar o pegar esa parte de la transcripción en ChatGPT ni registrar el terminal. Solo comunicar marcadores finales: `CLAVE_GUARDADA_FUERA_DEL_SERVIDOR`, `CLAVE_EN_ARCHIVO_PRIVADO_ROOT_0600`, `REPO_RESTIC_REMOTO_INICIALIZADO`, `PRUEBA_CIFRADA_DRIVE_RESTAURADA`, `RESTIC_CHECK`, `RESULTADO_GLOBAL`, `RESULTADO_EJECUCION` o `FASE_FALLIDA`. **Si sale fallo después de `CLAVE_PRIVADA_EN_SERVIDOR=1` o `REPO_RESTIC_REMOTO_INICIALIZADO=1`, NO reintentar**, evitar crear clave distinta/repo inconsistente; recuperar con un script específico según resultado. Sigue pendiente la primera copia cifrada PG17 y su recuperación aislada.

## 24/10/2026 — Repositorio Restic remoto inicializado; primera copia PostgreSQL pendiente

**Resultado real aportado por el usuario** tras corregir el TTY, sin copiar la clave privada:
```text
CLAVE_GUARDADA_FUERA_DEL_SERVIDOR=CONFIRMADA_POR_USUARIO
CLAVE_EN_ARCHIVO_PRIVADO_ROOT_0600=OK
RESTIC_REPOSITORIO_REMOTO=CREADO
PRUEBA_CIFRADA_DRIVE_RESTAURACION=OK
RESTIC_CHECK=OK
CLAVE_PRIVADA_EN_SERVIDOR=1
REPO_RESTIC_REMOTO_INICIALIZADO=1
PRUEBA_CIFRADA_DRIVE_RESTAURADA=1
POSTGRES_NO_RESPALDADO_AUN=1
SIN_MIGRACIONES_NI_REINICIOS=1
RESULTADO_GLOBAL=0
RESULTADO_EJECUCION=0
```

**Hito real confirmado:** acceso Rclone con OAuth propio y alcance `drive.file`, clave Restic protegida por root y declarada bajo custodia externa por el usuario, repositorio `rclone:vencira_google:VENCIRA-Backups/PostgreSQL` inicializado, snapshot sintético subido y leído/descifrado desde Drive y `restic check` correcto. **NO reejecutar `o5_init_restic_drive.sh`, no generar una segunda clave, ni repetir OAuth.** No hay aún copia real de la BD.

**Corrección preventiva del ensayo**: `scripts/o5_restore_drill.sh` deja de usar `restic dump latest vencira-postgres.dump` (podría elegir el snapshot sintético O5 u otro), y utiliza `restic dump --tag vencira-postgresql latest vencira-postgres.dump`. El filtro `--tag` sobre `latest` está documentado por Restic 0.19.1. Se añade confirmación de tablas públicas restauradas. El ensayo mantiene PostgreSQL 17 temporal sin red ni volumen persistente, limpia contenedor al terminar, verifica migración 0014 e identidad Docker original sin alteraciones.

**Siguiente operación, aún NO ejecutada por el usuario:** primera copia PostgreSQL del stack DEV + recuperación remota íntegra en contenedor efímero. Ejecutar como usuario `vencira`, desde SSH, una sola vez:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  echo "COMMIT=$(git rev-parse HEAD)"
  bash -n scripts/o5_backup_to_drive.sh || exit 1
  bash -n scripts/o5_restore_drill.sh || exit 1
  sudo bash scripts/o5_backup_to_drive.sh || exit 1
  sudo bash scripts/o5_restore_drill.sh || exit 1
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```

Éxito esperado **solo tras ejecutar**: en copia `DB_LOCALCHECK_HEALTHY=1`, `RESTIC_DRIVE_ACCESIBLE=1`, `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `RESTIC_INTEGRIDAD_METADATA=OK`, `RESULTADO_GLOBAL=0`; en ensayo `DRIVE_SNAPSHOT_ACCESIBLE=1`, `PG17_EFIMERO_SIN_RED=OK`, `RESTAURACION_PG17_DESDE_DRIVE=OK`, `ESQUEMA_O3_RESTAURADO=0014_renewal_outcomes`, `RESTIC_SNAPSHOT_TAG=vencira-postgresql`, `POSTGRES_ORIGINAL_INTACTO=1`, `O5_RESTAURACION_REMOTA_VERIFICADA=1`, `RESULTADO_GLOBAL=0`; al final `RESULTADO_EJECUCION=0`. La copia incluye **solo datos sintéticos del entorno DEV**, no permite subir datos de clientes ni habilitar producción.

Ante cualquier fallo: **no repetir todo el bloque** ni cambiar clave ni recrear repositorio; aportar solo marcadores seguros, `FASE_FALLIDA` y, si procede, errores acotados sin credenciales ni datos de clientes. No ejecutar restauración contra el PostgreSQL en uso.

**No activar backup diario todavía.** Google OAuth External/Testing con `drive.file` puede emitir refresh token caducable a los 7 días: revisar Audience/publishing status y autorización adecuada antes de systemd. Falta política de retención, alerta en fallo y defensa de segunda ubicación independiente ante borrado/ransomware. Estado OAuth `In production` no equivale a producto VENCIRA en producción. Fuente Google: https://developers.google.com/identity/protocols/oauth2 .

## 24/10/2026 — Primera copia PostgreSQL REAL cifrada y restauración aislada confirmadas

**Evidencia exclusiva de ejecución sobre Ubuntu aportada por el usuario**, tras sincronizar el commit `28830104fbbcf579b7ccbf32912c1053137b90d5` en `integration/local-e2e-prep`. Se ejecutaron por primera vez en esta fase `scripts/o5_backup_to_drive.sh` y `scripts/o5_restore_drill.sh` con sus comprobaciones de sintaxis Bash superadas; no se ejecutó el script de inicialización (que **NO debe repetirse**).

**Backup cifrado de PostgreSQL DEV a Drive:**
- `DB_LOCALCHECK_HEALTHY=1`, `RESTIC_DRIVE_ACCESIBLE=1`.
- `restic backup --tag vencira-postgresql --stdin-from-command` guardó el dump `pg_dump -Fc` como snapshot **`7a2f5018`** en repo cifrado previamente creado. 70,332 KiB procesados; 16,025 KiB almacenados según salida de Restic. La salida de `pg_dump` se transmitió hacia Restic sin persistir dump en claro en el host.
- `RESTIC_INTEGRIDAD_METADATA=OK`, `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `RESULTADO_GLOBAL=0`, `NO_SE_MIGRO_NI_REINICIO_POSTGRES=1`, `SIN_DUMP_EN_DISCO_LOCAL=1`.

**Recuperación real desde el remoto:**
- `DRIVE_SNAPSHOT_ACCESIBLE=1`, `PG17_EFIMERO_SIN_RED=OK`.
- `restic dump --tag vencira-postgresql latest vencira-postgres.dump | docker exec ... pg_restore` completó la restauración en contenedor PostgreSQL 17 **sin red**, **sin volumen persistente**, y distinto al original.
- `RESTAURACION_PG17_DESDE_DRIVE=OK`, `ESQUEMA_O3_RESTAURADO=0014_renewal_outcomes`, `TABLAS_PUBLIC_RESTAURADAS=21`, `RESTIC_SNAPSHOT_TAG=vencira-postgresql`, `POSTGRES_ORIGINAL_INTACTO=1`, `POSTGRES_LOCALCHECK_NO_MODIFICADO=1`.
- `RESULTADO_GLOBAL=0`, `O5_RESTAURACION_REMOTA_VERIFICADA=1`, `SIN_DUMP_DESCIFRADO_EN_DISCO=1`, **`RESULTADO_EJECUCION=0`**. Log local del ensayo en `/tmp/vencira-o5-restore.jxgcmHGS.log` (no copiar a repositorio ni publicar sin inspección).

**Veredicto:** primera copia real cifrada DEV y restauración funcional **verificadas**. Esto prueba que el dump es restaurable, pero no prueba integridad de todos los registros por comparación fila-a-fila, no es una prueba de reconstrucción completa del servicio, ni proporciona retención/inmutabilidad/automatización. `restic check` sin opción de lectura completa no prueba por sí solo todos los bloques de contenido; la restauración desde Drive aporta una validación complementaria del snapshot restaurado.

**Siguiente puerta, sin tocar Ubuntu aún**: abrir Google Cloud Console con el proyecto OAuth **VENCIRA Backups** y leer `Google Auth Platform → Audience → Publishing status` de la aplicación que generó el cliente OAuth Desktop usado por Rclone. Comunicar únicamente `Testing` o `In production`, sin Client ID, Client Secret, refresh token ni `rclone.conf`. Según Google, **External / Testing** genera refresh tokens de 7 días cuando se usa Drive. `drive.file` es un scope no sensible, pero la posibilidad de publicar y requisitos de verificación deben comprobarse en Google Auth Platform; no presuponer que el cliente ya está en In production. Fuentes: https://support.google.com/cloud/answer/15549945 y https://developers.google.com/identity/protocols/oauth2 y https://developers.google.com/workspace/drive/api/guides/api-specific-auth .

**No habilitar aún cron/systemd timer**. Después de asegurar credenciales duraderas y probar su renovación, planificar backup diario verificable, retención y poda segura, alertas de fallos/copias viejas, restauraciones periódicas, protección ante borrado/ransomware mediante otro destino independiente y guía de recuperación en otro servidor. No ejecutar `restic forget --prune` ni `rclone sync` improvisados. Mantener `vencira_localcheck` (DEV) sin datos personales reales; no autoriza producción.

## 24/10/2026 — Google OAuth sigue en Testing (confirmado); publicación pendiente

**Nueva confirmación del titular:** en Google Auth Platform → Audience, el proyecto **VENCIRA Backups** para `appvencira@gmail.com` figura como **External / Testing**. No inferir `In production` por el éxito actual de OAuth, ni programar tareas automáticas. La autorización del 24/10 con `drive.file` se obtuvo mientras la app seguía en Testing; por la regla de Google su refresh token puede caducar a los siete días y la conexión dejar de funcionar. Referencia oficial: https://support.google.com/cloud/answer/15549945 y https://developers.google.com/identity/protocols/oauth2 .

**Decisión técnica propuesta al titular:** pasar *únicamente la app administrativa OAuth para copias* al estado **In production** (no es publicar VENCIRA ni sus datos, código o API). Antes de pulsar `Publish app`, inspeccionar Google Auth Platform → Data Access y comprobar que **el único scope de Google Drive** es `https://www.googleapis.com/auth/drive.file` (no pedir `drive`, `drive.readonly` ni permisos amplios). Google clasifica `drive.file` como **non-sensitive**, sujeto a requisitos de verificación básica y posibles restricciones concretas del proyecto: https://developers.google.com/workspace/drive/api/guides/api-specific-auth . En `Google Auth Platform → Audience`, pulsar `Publish app` y comprobar estado `In production`. Si la interfaz solicita verificación, bloquea o exige cambios inesperados, **detenerse y evaluar el requisito, sin inventar URLs, permisos ni desactivar controles**.

**Advertencia de alcance:** publicar la app OAuth External permite que cualquier cuenta Google intente autorizar sus propios datos con ese cliente. No habilita el sitio web VENCIRA para clientes, no concede a terceros la clave Restic ni acceso a los archivos privados del titular. Mantener el cliente OAuth de tipo Desktop existente y la cuenta técnica exclusivamente interna. Google puede seguir mostrando avisos de app sin verificar conforme a su política de verificación.

**Una vez el titular confirme `In production` (NO ANTES)**: efectuar reconexión del **remoto existente** con `scripts/o5_reauthorize_existing_drive.sh` desde sesión SSH interactiva con túnel local `127.0.0.1:53682`, para solicitar nueva autorización bajo el estado publicado. El script ya validado realiza copia temporal privada `root:600` de `rclone.conf`, usa `rclone config reconnect vencira_google:`, verifica token y `rclone lsd`, intenta rollback de config en error y no toca Restic ni PostgreSQL. Antes de usarlo, sincronizar rama y revisar contexto/puerto; los códigos/enlaces OAuth son secretos de sesión y no se comparten. **No se ha ejecutado esta reconexión por el cambio de estado**. Una autorización antigua emitida en Testing no se considera duradera sin emisión nueva y prueba.

**Verificación posterior obligatoria**: con config `root:700/600`, comprobar acceso al repositorio Restic existente y al snapshot de PostgreSQL **`7a2f5018`**, sin mostrar ni restaurar los datos en pantalla, ni publicar rutas privadas/token. Debe comprobarse que la autorización nueva permite renovar credenciales posteriormente. No recrear repo, no ejecutar `restic init`, no regenerar clave ni modificar Docker; no cron/timer, retención/poda o migraciones hasta que esa fase sea OK.

**Estado actual:** snapshot cifrado real de PG17 `7a2f5018` y restauración sin red con 21 tablas y migración `0014_renewal_outcomes` ya verificados el 24/10; **OAuth Testing confirmado**, transición y renovación pendientes, política de copia automatizada no habilitada.

## 24/10/2026 — Diagnóstico confirmado del bloqueo «Publicar app» (HTML real Google Cloud)

**Evidencia aportada por el titular:** dos capturas HTML SingleFile de `Google Auth Platform → Público` (16:45:36 CEST) y `Información de la marca` (16:46:10 CEST), proyecto `vencira-backups`. No subir esos HTML completos a GitHub: contienen contenido de consola administrativa y podrían incluir datos de sesión.

**Error literal de la UI (Público):** «Se requieren un nombre de app, un correo electrónico de asistencia, una URL de página principal y una URL de política de privacidad válidos para cambiar la app al modo de producción externo. Debes ingresar la información faltante ... Visita la página de desarrollo de la marca para terminar de configurar tu app». `Publicar app` aparece en Testing, sin completar branding.

**Verificación precisa del formulario Branding por valores de INPUT del HTML (no solo etiquetas):**
- Nombre de aplicación **ya establecido**: `VENCIRA Internal Backups`.
- Correo de asistencia y del desarrollador **ya establecido**: `appvencira@gmail.com`, mantener **interno** y no añadirlo gratuitamente como email público de la web. Google ya lo puede mostrar en la pantalla de consentimiento, en función de sus reglas.
- Dominio autorizado **ya añadido**: `vencira.es`, pero su presencia en consola no demuestra por sí sola dominio verificado en Google Search Console ni sitio público accesible.
- Campos **vacíos**: `Página principal de la aplicación`, `Vínculo a la Política de Privacidad`, `Vínculo a las Condiciones del Servicio`. Los dos primeros son los bloqueantes declarados por Google; términos son opcionales en esta pantalla.
- Logo no aportado, **no necesario** para la corrección; añadirlo puede desencadenar revisión de marca.
- Tipo de usuario `External`; cuenta de pruebas registrada, 1/100. No es un error de límite de testers, Rclone, Restic ni permisos de PostgreSQL.

**Plan de corrección, sin cambios aún en hosting:**
1. Antes de inventar URLs, comprobar si `https://vencira.es/` tiene un sitio funcional y accesible públicamente sin credenciales. La comprobación web desde esta sesión no pudo validar el host; no afirmar que exista/funcione o que el dominio raíz apunte ya al VPS. `dev.vencira.es` es privado/entorno DEV, no usar como página principal OAuth.
2. Proponer rutas a crear en el dominio controlado: `https://vencira.es/oauth-backups/` (explica que se trata de una integración administrativa interna de copias cifradas de VENCIRA a Google Drive vía Restic/Rclone, no un servicio público) y `https://vencira.es/oauth-backups/privacidad/` (política transparente y exacta sobre accesos `drive.file`, tipo de datos, cifrado, custodia, almacenamiento, terceros, retención y contacto responsable; revisar jurídicamente y no inventar identidades o buzones no configurados). Son URLs **futuras propuestas, no publicadas**.
3. Publicar los dos recursos estáticos exclusivamente después de determinar la configuración DNS/web actual y el destino Nginx adecuado; no tocar `vencira_localcheck`, `vencira_preview`, los contenedores ni Docker/postgres. Garantizar HTTPS válido y que ambas páginas son públicas sin autenticación y se enlazan entre sí. Verificar propiedad de `vencira.es` en Google Search Console si Google lo exige.
4. En Google Auth Platform → Branding guardar URL pública de la página principal y de la privacidad (términos opcionales). Luego Audience → `Publish app`; detenerse si hay nueva exigencia de verificación y revisarla. Los cambios en branding no requieren recrear el cliente OAuth Desktop ni ampliar scope.
5. Tras estado `In production` verificado, renovación controlada del **remoto existente** con script ya documentado, y lectura segura del snapshot `7a2f5018` antes de systemd. No iniciar `restic init`, cambiar clave, reautorizar antes de solucionar branding ni activar backups desatendidos.

**Normativa oficial:** https://support.google.com/cloud/answer/15549049 ; https://support.google.com/cloud/answer/13807376 ; https://developers.google.com/identity/protocols/oauth2/policies ; `drive.file` no sensible https://developers.google.com/workspace/drive/api/guides/api-specific-auth .

**Estado al cierre del diagnóstico:** causa del bloqueo **identificada de forma directa en HTML**; sitio público y política **pendientes de crear/publicar**, OAuth sigue Testing y backups automáticos desactivados; backup cifrado manual y restauración aislada válidos.

## 24/10/2026 — Retirada de Basic Auth de DEV COMPLETADA Y VERIFICADA

**Evidencia reportada del script en Ubuntu por el titular** (última ejecución):
```text
CADDY_SERVICIO_PUEDE_LEER_CONFIG=OK
CADDY_ACTIVO=1
CONFIG_ESTRUCTURA_L1_L19=PREVALIDACION
CONFIG_CADDY_COPIA_PRIVADA=OK
BACKUP_PRIVADO_LOCAL=/etc/caddy/.vencira-dev-auth-rollback.kpXvFpJX
CAMBIO_LIMITADO_A_L2_L4=OK
CADDY_CANDIDATO_VALIDADO=OK
CADDY_RELOAD_INICIAL=OK
DEV_RAIZ_HTTP=200
DEV_ME_ANONIMO_HTTP=403
DEV_ADMIN_ANONIMO_HTTP=404
INICIO_SESION_APP_Y_ADMIN_PROTEGIDOS=OK
BASIC_AUTH_DEV_RETIRADA=OK
CADDY_RECARGADO=OK
NO_DOCKER_NI_POSTGRES_NI_RESTIC_MODIFICADOS=1
RESULTADO_GLOBAL=0
RESULTADO_EJECUCION=0
```

**Estado definitivo probado en VPS**: `dev.vencira.es` se sirve públicamente por HTTPS sin Basic Auth (GET anónimo / devuelve 200). El endpoint de identidad `GET /api/v1/me/` rechaza acceso anónimo (403); `/admin/` permanece oculto (404). Caddy validado y recargado, sin cambios de Docker, PG ni Restic. La protección por sesión Django/CSRF permanece según código y tests anteriores, pero no sustituye a una auditoría de seguridad de producción. El único contenido admisible en DEV continúa siendo sintético. Guardar la copia privada de reversión bajo `/etc/caddy/.vencira-dev-auth-rollback.kpXvFpJX` sin poner hashes en el repositorio. No repetir el script de retirada: el bloque Basic Auth ya no está en la config activa y su guard lo rechazará.

**Siguiente objetivo Google OAuth:** no confundir apertura de `dev.vencira.es` con disponer de página pública de marca/política. El dominio raíz `vencira.es` sigue con el último DNS confirmado `213.186.33.5` y HTTPS no operativo; no se ha publicado `https://vencira.es/oauth-backups/` ni `.../privacidad/`. Resolver sitio público, propiedad de dominio, contenido real y HTTPS antes de rellenar Branding y pasar OAuth External/Testing a In production. Token OAuth actual puede caducar a los siete días, por ello automación de respaldos **deshabilitada**. Tras publicación, reautorizar remoto existente sin cambiar clave Restic ni repo y verificar snapshot remoto PG `7a2f5018`. No usar datos de clientes.

## 24/10/2026 — Publicación OAuth O5: páginas estáticas y despliegue Caddy preparados (NO EJECUTADOS)

**Objetivo:** desbloquear publicación `External / Testing` del cliente OAuth **VENCIRA Internal Backups** (de Restic/Rclone), no desplegar la app comercial VENCIRA. Los HTML de Google Cloud aportados identificaron como bloqueantes la URL pública de homepage y de privacidad; el dominio autorizado `vencira.es` y nombre de app ya existían en Branding.

**Decisión de infraestructura sin interrumpir lo existente:** un **subdominio independiente** `oauth.vencira.es`, NO alterar el registro raíz `vencira.es` que resuelve a `213.186.33.5`, NI `www`, NI `dev.vencira.es`, MX o correo. El nuevo DNS **A** `oauth` debe resolver exclusivamente a IP IPv4 del VPS de VENCIRA `93.93.112.172`. No publicar AAAA hasta disponer de una dirección IPv6 validada. La modificación de DNS en el proveedor es una acción pendiente del titular, no hay acceso a su panel desde GitHub. No afirmar DNS listo ni webs públicas todavía.

**Sitio contenido en GitHub y únicamente informativo (pendiente de despliegue):**
- `public/oauth-backups/index.html`: descripción inequívoca de integración técnica y cuentas administrativas, uso de Restic/Rclone con copias cifradas, alcance `drive.file`, sin acceso a la app VENCIRA comercial; enlace a privacidad.
- `public/oauth-backups/privacidad/index.html`: alcance OAuth, datos de Google, finalidad, retención actualmente manual sin falsos plazos automáticos, seguridad, revocación y contacto referenciado al correo de soporte que Google presenta en pantalla de consentimiento. Evita publicar el correo Gmail administrativo en el sitio; debe verificarse suficiencia jurídica si Google exige identificación adicional del responsable.
- `public/oauth-backups/condiciones/index.html`: condiciones técnicas del servicio interno.
- `public/oauth-backups/assets/site.css` y `robots.txt`; HTML estático sin JS, cookies de analítica, trackers ni credenciales.

**URLs a incorporar en Google Auth Platform → Branding** únicamente cuando HTTPS responda 200 sin credenciales:
- `https://oauth.vencira.es/` — página principal
- `https://oauth.vencira.es/privacidad/` — política de privacidad
- `https://oauth.vencira.es/condiciones/` — condiciones de servicio (opcional en UI)
Dominio autorizado debe seguir siendo `vencira.es` conforme a Google (dominio registrable), no añadir `oauth.vencira.es` como otro dominio autorizado sin que lo solicite la consola. Cuando Google lo requiera, verificar propiedad de `vencira.es` en Search Console, usando cuenta propietaria del proyecto OAuth y un registro TXT indicado por Google; no inventar el TXT.

**Despliegue preparado:** `scripts/o5_publish_oauth_pages.sh` commit `863c22b38871d968064349130e25a25e0d759053`. Requiere DNS correcto, rama `integration/local-e2e-prep`, archivo `/etc/caddy/Caddyfile` original root:caddy 0640 y servicio Caddy activo/legible. Verifica previo DEV 200/403/404, crea respaldo privado root:0700/0600, copia documentos a `/srv/vencira-oauth-site` (estáticos legibles por caddy), añade SOLO sitio independiente `oauth.vencira.es` al Caddyfile, valida candidato con usuario caddy, `systemctl reload caddy`, verifica HTTPS público 200 en las tres páginas y que DEV continúa 200/403/404. Ante fallo después de cambiar Caddyfile intenta rollback del archivo y recarga Caddy. Puede dejar archivos estáticos locales inertes si falla para inspección, sin secretos. No ejecuta restic, DB, Docker ni amplía alcance Google.

**Ejecución UNA VEZ después de configurar DNS**:
```bash
(
  cd /home/vencira/vencira-localcheck || exit 1
  git fetch origin integration/local-e2e-prep || exit 1
  git merge --ff-only FETCH_HEAD || exit 1
  bash -n scripts/o5_publish_oauth_pages.sh || exit 1
  sudo bash scripts/o5_publish_oauth_pages.sh
)
echo "RESULTADO_EJECUCION=$?"
echo "CONSOLA_ABIERTA"
```
Si falla `DNS_OAUTH_NO_LISTO=1`, no tocar Caddy; esperar propagación o revisar A/AAAA. Si falla `CADDY_REVERSION=REVISION_MANUAL_NECESARIA`, detenerse y revisar antes de repetir. No usar `caddy restart` ni `docker compose down`. Verificar `SITIO_OAUTH_PUBLICADO=OK`, `HTTPS_OAUTH_PUBLICO=OK`, `DEV_SIN_REGRESIONES=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_EJECUCION=0`.

**Paso posterior:** en `https://console.cloud.google.com/auth/branding?project=vencira-backups` configurar URL de página principal, privacidad y condiciones; guardar. En `https://console.cloud.google.com/auth/audience?project=vencira-backups` publicar app / In production, atender requisitos adicionales reales si aparecen, no inventar aprobación. En Google Search Console verificar dominio si exigido. Solo tras In production reautorizar remoto rclone existente con script ya guardado, leer snapshot cifrado PG real `7a2f5018` y posteriormente diseñar timer diario. No inicializar otro repositorio, regenerar contraseña o dar por terminada publicación OAuth antes del cambio real de estado.

**Fuentes Google actualizadas**: https://support.google.com/cloud/answer/15549049 , https://developers.google.com/identity/verification/authentication-policy-compliance , https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification .

## 24/10/2026 — DNS para host publico OAuth confirmado

Tras `DNS_OAUTH_NO_LISTO=1` en el primer preflight, usuario comprobó que `oauth.vencira.es` resuelve como `A=93.93.112.172` desde Ubuntu, 1.1.1.1 y 8.8.8.8. No aparece AAAA ni CNAME en las consultas aportadas. **Bloqueo de DNS corregido**; el script `scripts/o5_publish_oauth_pages.sh` queda listo para una nueva ejecución controlada tras sincronizar rama. **No afirmar** todavía páginas publicadas, Caddy modificado o HTTPS 200, porque no se ha aportado nuevo resultado de despliegue. Si el preflight ahora supera DNS y el despliegue valida `OAUTH_HOME_HTTP=200`, `OAUTH_PRIVACIDAD_HTTP=200`, `OAUTH_CONDICIONES_HTTP=200`, proceder a Branding y Audience de Google. Credenciales OAuth, contraseña de Restic y snapshot existentes permanecen sin cambios; no activar timer mientras siga Testing.
