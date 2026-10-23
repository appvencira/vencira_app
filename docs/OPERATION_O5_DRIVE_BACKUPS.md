# VENCIRA O5 — Copias cifradas PostgreSQL en Google Drive

**Estado 23/10/2026:** O5 **DISEÑADA Y SCRIPTS VERSIONADOS, SIN CONEXIÓN NI COPIAS REMOTAS TODAVÍA**. Cuenta de Google interna confirmada por usuario: `appvencira@gmail.com`; **no es una dirección de soporte público**. No se han recibido credenciales, ni se han instalado paquetes, ni se ha accedido a Drive. No usar información personal real.

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

## Dependencia interactiva: OAuth Google, usuario Android

Para permitir las copias habrá que crear, desde `appvencira@gmail.com`, un proyecto Google Cloud para la integración de respaldo, activar **Google Drive API**, configurar la pantalla de consentimiento para uso personal, crear credenciales **OAuth tipo Desktop** y aprobar el acceso desde navegador; rclone recomienda crear cliente propio porque su identificador compartido se retira en 2026. No se deben enviar al chat las credenciales ni códigos OAuth.

El servidor Ubuntu no tiene navegador. Rclone documenta dos métodos: autorización desde otro dispositivo con Rclone y navegador (`rclone authorize`), o **túnel de puerto SSH 53682** hasta `127.0.0.1` remoto para completar OAuth en el navegador local. En Android, el soporte del túnel dependerá del cliente SSH utilizado. No abrir este puerto al mundo ni exponer `rclone rc` sin autenticación. **La autenticación no está realizada.** Utilizar `drive.file` si el acceso a repositorio/restauración funciona; no conceder `drive` completo sin necesidad.

Documentación oficial:
- Rclone Drive/OAuth: https://rclone.org/drive/
- Rclone headless/OAuth SSH: https://rclone.org/remote_setup/
- Restic repositorio vía Rclone: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html
- Restic streaming desde comando: https://restic.readthedocs.io/en/stable/040_backup.html

## Orden de ejecución previsto y estado

1. **Ahora**: ejecutar el diagnóstico de solo lectura. Si faltan herramientas, resolver instalación con paquetes verificados, sin actualizar el sistema operativo ni reiniciar servicios.
2. Configurar Google Cloud OAuth con autorización específica del titular (no introducir secreto en chat); crear remote Rclone dedicado bajo la identidad de respaldo.
3. Generar y proteger clave Restic, **guardar recuperación fuera del servidor**, crear repositorio remoto con `restic init`; comprobar que no hay dumps en claro y el Drive corresponde a la cuenta adecuada.
4. Ejecutar una copia manual encriptada y `scripts/o5_restore_drill.sh`; comparar esquema/recuento e integridad sin alterar base viva; verificar que el último snapshot efectivamente corresponde al equipo. Si hay errores, **no habilitar automatización**.
5. Solo tras esas pruebas, introducir servicio y temporizador `systemd` de copia diaria con registro de errores/monitorización y política inicial de retención (propuesta: 7 diarias, 4 semanales y 12 mensuales, validar capacidad y necesidades). No ejecutar `restic forget --prune` hasta confirmar recuperación y configuración de retención.
6. Para datos personales reales: completar cifrado externo, MFA del proveedor, procedimiento restauración sin acceso al host, autorización por usuarios y RGPD/LOPDGDD, y segunda copia independiente contra borrados.

**No marcar O5 como completada** por tener scripts en GitHub. Solo una ejecución que demuestre `GOOGLE_DRIVE_BACKUP_CIFRADO=OK`, `O5_RESTAURACION_REMOTA_VERIFICADA=1` y automatización comprobada permite cierre. No volver a ejecutar O4 ni migración 0014.
