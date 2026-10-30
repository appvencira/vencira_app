# VENCIRA — MB1 FREEZE multiproceso cooperativo (30/10/2026)

Nuevo componente `offline_multiprocess_fence_mb1.py`: usa `flock` de Linux sobre un fichero privado de un directorio privado para compartir `LOCK_SH` entre escritores participantes y adquirir `LOCK_EX` para la captura. Comprueba permisos básicos y rechaza por timeout. Se implementaron seis pruebas con **subprocesos Python reales**, que examinan exclusión escritor/captura, admisión simultánea de lectores del lock, cierre tras excepción y permisos inseguros. Código en rama `feature/c-ficha-independent-attachments`. **Pruebas aún pendientes de ejecución de operador**.

Gate único:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/validate_mb1_multiprocess_fence.sh
echo "MB1_PROCESS_EXIT_CODE=$?"
```

Un resultado verde acredita solamente **coordinación voluntaria entre procesos en el mismo filesystem/lock inode**. No es un bloqueo obligatorio de escritura; un proceso ajeno que no use el mismo lock puede escribir durante la captura. No demuestra congelación DB PG17, bloqueo de filesystem, sincronización entre contenedores en mounts diferentes, ausencia de handles, captura durable ni restauración B09E. No hay integración operativa ni exposición de endpoints.

### Cierre todavía pendiente

Para cerrar MB1 es preciso: censo completo de mutadores; control efectivo de entradas/procesos no cooperativos; freeze que cubra SQL, objeto cifrado y diario; snapshot consistente autenticado; restauración desde soporte separado en otro PG17; ensayo de fallo y custodia real externa de claves. Mantener todo en clones efímeros y sin claves reales antes de autorización.

```text
MB1_PROCESS_TESTS=PENDING
MB1_GLOBAL_WRITER_FREEZE=BLOCKED
MB1_INTEGRAL_RESTORE_AFTER_FREEZE=NOT_RUN
MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
