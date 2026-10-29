# VENCIRA — MB1 / B18D: barrera impuesta por PostgreSQL (ensayo)

**Fecha:** 29/10/2026. Rama: `feature/c-ficha-independent-attachments`. No es un diseño de captura completo ni autoriza deploy.

## Problema confirmado

B18C demostró con PG17 efímero que un escritor ORM que ignora `pg_advisory_lock` puede modificar un expediente mientras otro proceso mantiene la barrera cooperativa. Los locks advisory no son obligatorios para escrituras SQL.

## Experimento B18D

Se añadió `backend/renewal_attachments/test_b18d_db_enforced_fence_pg17.py`, con dos pruebas aisladas:

1. Dentro de `transaction.atomic()`, `LOCK TABLE "renewal_attachments_attachmentrecoverycase" IN ACCESS EXCLUSIVE MODE` retiene un lock de tabla real. Una segunda conexión intenta `AttachmentRecoveryCase.objects.create()` sin solicitar ningún advisory lock. El test exige que no termine mientras dura el lock y que pueda completarse tras liberar la transacción.
2. Si la transacción de captura termina con excepción, debe liberar el lock automáticamente. Se verifica mediante inserción posterior de un expediente sintético.

Esto es un **prototipo de protección DB para una sola tabla**; no es un mecanismo de captura desplegable. Los locks exclusivos tienen impacto en disponibilidad, pueden bloquear lecturas y necesitan control de timeout, deadlocks y orden de tablas. Una consulta directa a otra tabla, escrituras de objetos cifrados, diario o colas externas no quedan protegidas. Ni `pg_dump` ni una lectura de inventario fuera de la transacción comparten automáticamente una frontera segura. Un freeze operacional necesita inventario completo, coordinación de servicios y prueba de restore end-to-end.

## Ejecución (solo PG17 efímero)

Script de ensayo compartido `scripts/rehearse_c_ficha_split_readonly.sh` admite ahora `B18D_DB_FENCE_ONLY=1`; mantiene los checks de esquema y solo ejecuta `test_b18d_db_enforced_fence_pg17`, **no toda la suite**.

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
B18D_DB_FENCE_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18D_DB_FENCE_EXIT_CODE=$?"
```

Esperado después de ejecutar: `B18D_DB_FENCE_TESTS=OK`, `B18D_OPERATIONAL_FULL_CAPTURE=BLOCKED`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18D_DB_FENCE_EXIT_CODE=0`. **No ejecutado aún por el operador**. No publicar `B18D_DB_FENCE_TESTS=OK` como hecho hasta recibir evidencia.

## Estado

```text
B18D_CODE=PREPARED
B18D_RUNTIME_TEST=PENDING
B18D_DB_ONLY_LOCK=EXPERIMENTAL
MB1_OPERATIONAL_CAPTURE=BLOCKED
MB1_FULL_DISASTER_RECOVERY=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Resultado del operador — 29/10/2026

Checkout `16ca51207ea13ccd0abcb17710ae843f80ab6afb`. Reporta `B18D_DB_FENCE_ONLY=1` con `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `B18B_RECOVERY_SCHEMA_READY=OK`, `B18D_DB_FENCE_TESTS=OK`, `B18D_OPERATIONAL_FULL_CAPTURE=BLOCKED`, `C_FICHA_FULL_SUITE=NOT_RUN`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18D_DB_FENCE_EXIT_CODE=0`. **Gate experimental focalizado validado según salida aportada**, no significa congelación global de escrituras. La próxima acción debe priorizar inventario completo, frontera SQL/objetos/diario y recuperación frente a fallo; no multiplicar tests de una sola tabla. Autorizaciones: `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
