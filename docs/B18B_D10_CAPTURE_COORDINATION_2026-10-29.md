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


## Incidencia de ejecución — esquema PG17 incompleto (29/10)

Operador comunica `C_FICHA_SPLIT_PG17_RESULT=1`, `B18B_PG17_EXIT_CODE=1`, con `ProgrammingError: relation "renewal_attachments_attachmentrecoverycase" does not exist`. El script `rehearse_c_ficha_split_readonly.sh` aplicaba explícitamente hasta `renewal_attachments.0004_attachmentdiscardjob` antes de pruebas D10; la tabla `AttachmentRecoveryCase` se crea en `0005_recoverycase`, y el head independiente actual es `0006_ed25519_signature_length`. Esto es una **brecha verificable de preparación del esquema de ensayo**; no se infiere que la prueba de bloqueo B06B haya fallado o pasado.

Corrección publicada en `scripts/rehearse_c_ficha_split_readonly.sh`: después de las verificaciones históricas que intencionadamente se realizan sobre 0004, migrar **solo PG17 desechable** a 0006 y exigir tanto 0005/0006 aplicadas como tabla `renewal_attachments_attachmentrecoverycase` existente antes de arrancar la suite. Commit `227cec5`. Se conserva la fase de ensayo histórico de 0004 sin alterar sus aserciones. **Corrección pendiente de revalidar**: no declarar OK por haber actualizado el script.

Al reejecutar, comunicar `B18B_RECOVERY_SCHEMA_READY=OK`, `C_FICHA_SPLIT_PG17_RESULT=0` y `B18B_PG17_EXIT_CODE=0`; en caso de fallo, compartir `FAILED_PHASE` y traza depurada, no logs con secretos. Las etiquetas de suite general por sí solas no prueban que se ejecutara el nuevo test; comprobar resultado Django o instrumentar cobertura exacta después de resolver el esquema.

`B18_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Segundo fallo y orden definitivo de esquema (29/10)

Operador informa ejecución commit `2743bb9` con `FAILED_PHASE=TRANSITION_SYNTHETIC`: al eliminar una fila Django consultó la tabla relacionada `renewal_attachments_attachmentrecoverycase`, aún inexistente. La verificación añadida anteriormente **estaba situada después** de la fase de transición, por tanto no podía prevenir ese fallo. No es fallo de la nueva prueba de concurrencia, que no llegó a ejecutarse.

Se corrigió el **orden** en `scripts/rehearse_c_ficha_split_readonly.sh` (commit `7106ff1`): mantener primero las verificaciones históricas intencionales sobre esquema independiente 0004 y coexistencia, y **antes de `TRANSITION_SYNTHETIC`** aplicar `renewal_attachments.0006_ed25519_signature_length` en PG17 efímero, con comprobación explícita de 0005/0006 y la tabla de expedientes. La prueba sigue pendiente de revalidación. No se cambiaron migraciones ni producción.


## Tercer intento — falló suite amplia por requisitos de infraestructura específicos

El operador confirmó sobre `f487b2c`: `B18B_RECOVERY_SCHEMA_READY=OK`, `C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK`, `C_FICHA_SPLIT_RECONCILIATION_READONLY=OK` y después `FAILED_PHASE=INDEPENDENT_APP_TESTS`, `C_FICHA_SPLIT_PG17_RESULT=1`. Django ejecutó 424 tests y reportó **14 errores**, entre ellos `VENCIRA_B14_CLAMD_SOCKET` ausente para B14EF y `/run/keys/public.hex` ausente para B17C2. Son dependencias de ensayos especializados (ClamAV real / red multiservicio), no evidencia de fallo de la barrera D10.

**Corrección de alcance, sin ocultar errores:** desde commit `4285961`, el script conserva por defecto `test renewal_attachments` completo; solo con `B18B_FOCUSED=1` ejecuta exclusivamente `renewal_attachments.test_recovery_persistence_d10`, y emite `B18B_D10_PG17_TESTS=OK`, `B18B_FOCUSED_ONLY=1` y `C_FICHA_FULL_SUITE=NOT_RUN`. El resultado positivo de B18B **nunca sustituye** los gates independientes B14EF y B17C2 ni acredita suite completa. No se usan parámetros para omitir tests individuales dentro de una supuesta suite completa.

Comando de ensayo focalizado, PostgreSQL 17 **solo efímero**:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
B18B_FOCUSED=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18B_FOCUSED_EXIT_CODE=$?"
```

Esperado si pasa: `B18B_RECOVERY_SCHEMA_READY=OK`, `B18B_D10_PG17_TESTS=OK`, `C_FICHA_FULL_SUITE=NOT_RUN`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18B_FOCUSED_EXIT_CODE=0`. Resultado pendiente. Persisten `B18_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
