# MB1 — Preparación Ubuntu x86_64 independiente

**Estado 30/10/2026: preflight publicado, sin ejecución en el segundo equipo.**

## Identidad y límites

Esta máquina debe ser **distinta del VPS IONOS** que ejecuta VENCIRA. No debe compartir sus contenedores, disco o cuenta de claves. El preflight de `scripts/preflight_mb1_ubuntu_x86_recovery.sh` únicamente lee versión Ubuntu y arquitectura, herramientas instaladas, disponibilidad de Docker, 2 GiB libres en `/tmp`, firmas típicas del VPS de origen y lista de contenedores existentes. **No instala software, abre puertos, descarga imágenes, crea contenedores ni modifica DEV**. La detección de firmas no prueba independencia física o administrativa; el operador debe confirmarla.

## En la terminal del Ubuntu x86_64 (NO en el VPS)

Si el repositorio es accesible desde el segundo equipo, ejecutar:

```bash
mkdir -p ~/vencira-recovery-lab
cd ~/vencira-recovery-lab
git clone --branch feature/c-ficha-independent-attachments --single-branch https://github.com/appvencira/vencira_app.git source
cd source
bash scripts/preflight_mb1_ubuntu_x86_recovery.sh
echo "MB1_X86_PREFLIGHT_EXIT_CODE=$?"
```

Si el repositorio es privado, usar una credencial de GitHub de **solo lectura** gestionada localmente, nunca pegar tokens en el chat o en la línea de comandos. Si `git clone` solicita autenticación, detenerse y resolverla mediante SSH previamente configurado o gestor de credenciales. No copiar claves de VENCIRA.

Si faltan herramientas o Docker no está instalado, **no ejecutar instaladores remotos ciegamente**: mostrar el indicador `MB1_HOST_MISSING_TOOL` o `MB1_HOST_DOCKER_UNAVAILABLE` y preparar la instalación específica de ese Ubuntu. Si el comando muestra firmas de origen, revisar si se ha usado accidentalmente el VPS existente antes de continuar.

## Secuencia posterior (NO ejecutar aún)

1. Aprovisionar el paquete sintético cifrado, y su inventario de huellas, por una vía autenticada.
2. Validar recepción con `scripts/verify_mb1_second_host_package_receipt.sh`; el inventario debe haberse autenticado por separado.
3. Transferir las **claves sintéticas** por canal independiente; no GitHub, chat o logs.
4. Crear o trasladar una imagen de backend fijada a esta misma revisión y compatible con x86_64; no depender de una imagen `latest` ni de la instalación del VPS. La restauración usa Docker temporal y PostgreSQL 17, sin conexión con el origen.
5. Ejecutar la prueba de segundo host. Los controles de integridad, consistencia ORM y limpieza final deberán auditarse antes de aceptar MB1.

La etapa actual **no acredita custodia externa ni bloqueo global de escritores**; sigue `MB1_RELEASE_AUTHORIZED=NO`.

## Registro

`MB1_X86_HOST_PREPARED=PENDING`, `MB1_X86_HOST_PREFLIGHT=PENDING`, `MB1_SECOND_HOST_RESTORE=NOT_RUN`, `MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`.
