# VENCIRA B18B — cierre de hueco cooperativo D10 (29/10/2026)

Auditoría focalizada de B18A y pruebas existentes B06E/B06F: la captura exclusiva PG17 ya está ensayada para intake, rechazo y descartes. **No duplicar estos tests.**

Se identificó `record_recovery_offline` como escritor de `AttachmentRecoveryCase` que usaba `transaction.atomic` y `select_for_update`, pero no la barrera cooperativa B06B. Se añadió `advisory_barrier(capture=False)` **antes** de entrar en la transacción y un test de concurrencia `test_capture_blocks_recovery_write`, que retiene captura exclusiva en una conexión y demuestra que el otro hilo no puede crear el expediente hasta liberar la captura. Código de ensayo exclusivamente `VENCIRA_ENV=test`/PG17. Esta modificación **no** implementa una barrera operacional universal ni demuestra que todos los escritores estén censados.

**Commits:** `d9b58da` (corrección D10), `caac161c` (test PG17).

**Validación pendiente:** ejecutar el ensayo PG17 aislado ya existente `scripts/rehearse_c_ficha_split_readonly.sh` tras sincronizar la rama, ya que incluye suite `renewal_attachments`. Confirmar explícitamente que el test nuevo se descubre, además del exit 0. No emplear `validate_c_ficha_pg17_integrated.sh` para este cambio: ensaya la vía histórica 0027 y no cubre necesariamente la aplicación independiente en modo test. No usar scripts MFA que exigen la rama de integración.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18B_PG17_EXIT_CODE=$?"
```

**Estado:**
```text
B18B_D10_BARRIER_CODE=READY
B18B_D10_CONCURRENCY_TEST=NOT_RUN
B18B_OPERATIONAL_CAPTURE=BLOCKED
B18_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

Más adelante: inventario completo de todos los mutadores, simulación de caída entre transacción y filesystem, freeze efectivo y snapshot coherente DB+objetos+diario, y custodia externa de claves. Los resultados de ensayos no sustituyen autorización humana.
