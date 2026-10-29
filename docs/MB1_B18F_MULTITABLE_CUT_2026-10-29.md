# VENCIRA — Macrobloque 1 / B18F: frontera SQL multitabla y límite filesystem

**Fecha:** 29/10/2026. **Estado:** implementación y tests preparados; ejecución pendiente. Rama `feature/c-ficha-independent-attachments`.

## Propósito y alcance

B18C confirmó que los locks consultivos no detienen escritores ORM no cooperativos. B18D verificó un lock exclusivo sobre una tabla. B18E comprobó contratos de inventarios y diario con 12 tests sintéticos, pero no establece una barrera efectiva.

B18F añade `backend/renewal_attachments/test_b18f_multitable_cut_pg17.py`:
- Ensayo de bloqueo `ACCESS EXCLUSIVE` de **dos tablas** `renewal_attachments_renewalattachment` y `renewal_attachments_attachmentrecoverycase` dentro de una misma transacción. Una segunda conexión hace `UPDATE` directo sobre la primera y `INSERT` sobre la segunda: ambas deben terminar solo cuando se libera el bloqueo.
- Ensayo negativo: incluso manteniendo ambos locks SQL, una escritura sintética de diario en directorio temporal puede realizarse; **PostgreSQL por sí solo no detiene operaciones de filesystem**.

Los archivos privados reales, eventos, colas, objeto cifrado, workers de ClamAV y cualquier otra tabla no participan. Las transacciones con `ACCESS EXCLUSIVE` bloquean también lecturas, son intrusivas y **no son un procedimiento de captura operativa recomendado sin diseño completo**. Tampoco se demuestra `pg_dump` durante locks, una frontera durable de instantánea ni recuperación del servidor.

## Ejecución

Se agregó el modo explícito `B18F_CUT_ONLY=1` a `scripts/rehearse_c_ficha_split_readonly.sh`, que crea PG17 temporal en red interna, prepara esquema independiente 0006 y ejecuta solamente los dos tests B18F. La suite completa queda `NOT_RUN`.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
B18F_CUT_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18F_CUT_EXIT_CODE=$?"
```

Esperado si pasa: `B18F_MULTITABLE_DB_FENCE=OK`, `B18F_FILESYSTEM_FENCE=NOT_IMPLEMENTED`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18F_CUT_EXIT_CODE=0`. **No se han ejecutado aún estos tests.**

## Decisión de arquitectura pendiente

No seguir ampliando una tabla a la vez sin inventario de mutadores. La captura operativa requerirá un orquestador que impida nuevas entradas de API/worker/escritores, drene tareas en curso, controle acceso de escritura DB y al almacén/diario, establezca snapshot consistente e inmutable, compruebe integridad y permita restaurar en otro host con claves externas. Requiere gates de concurrencia, fallos y seguridad en PG17 efímero antes de habilitarlo.

```text
B18F_CODE=READY
B18F_TESTS=PENDING
MB1_UNIVERSAL_CAPTURE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Validación del operador — 29/10/2026

Checkout `d0da17989671193dac0959c1e878e2cac1385cc9`. Se comunica ejecución de `B18F_CUT_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh` con `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `B18B_RECOVERY_SCHEMA_READY=OK`, `B18F_MULTITABLE_DB_FENCE=OK`, `B18F_FILESYSTEM_FENCE=NOT_IMPLEMENTED`, `C_FICHA_FULL_SUITE=NOT_RUN`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18F_CUT_EXIT_CODE=0`. Se acredita únicamente el ensayo de dos tablas y la limitación filesystem. No existe orquestador integral ni autorización de producción. `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
