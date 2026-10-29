# VENCIRA — MB1 / B18C: diagnóstico de escritor no cooperativo

Fecha 29/10/2026. No confundir con validación de recuperación operativa.

## Reutilización de evidencia

B09E ya acredita en ensayo anterior dos PG17 desechables, `pg_dump`, cifrado, manifiesto HMAC, segundo `pg_restore`, conciliación ORM/objeto/diario y negativos de mezcla de paquetes. Ver [B09E](B09E_INTEGRAL_RESTORE.md). La batería de 41 contratos sintéticos de MB1 fue validada por el operador. **No repetir el gate B09E para declarar progreso ficticio**.

## Diagnóstico nuevo

El código `offline_write_barrier_b06b.py` usa locks consultivos PG17: únicamente bloquean a otros participantes del mismo protocolo. Se añadió `test_b18c_noncooperative_writer_pg17.py` (commit `73ee7ee`) que, mientras una conexión retiene el lock exclusivo de captura, ejecuta **en otra conexión al PG17 temporal** una escritura ORM directa a un expediente sintético sin pedir lock compartido. El test comprueba que la escritura acaba aun durante el lock. Esto confirma el **bloqueo pendiente de seguridad**, no un éxito de protección.

El script existente de PG17 efímero incorpora `B18C_GAP_ONLY=1` (commit `90f983a`): ejecuta ese único diagnóstico tras preparar el esquema hasta 0006, indica explícitamente `B18C_NONCOOPERATIVE_WRITER_BYPASS=CONFIRMED`, `B18C_OPERATIONAL_CAPTURE=BLOCKED` y `C_FICHA_FULL_SUITE=NOT_RUN`. En ningún caso levanta puertos ni utiliza la BD persistente. Una ejecución exitosa **no concede autorización**.

## Validación en Ubuntu

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
B18C_GAP_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18C_GAP_EXIT_CODE=$?"
```

Esperado: `B18C_NONCOOPERATIVE_WRITER_BYPASS=CONFIRMED`, `B18C_OPERATIONAL_CAPTURE=BLOCKED`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18C_GAP_EXIT_CODE=0`. **Pendiente ejecutar**.

## Diseño requerido antes del gate positivo

Enumerar todos los mutadores operativos (ORM, SQL directo, tareas, API, scan, outbox, filesystem, diario), prohibir caminos que ignoren la captura, coordinar corte de nuevas escrituras y operaciones pendientes, crear frontera durable SQL+objetos+diario y ensayar fallos reales en un clon. Sin esto, B09E/B18C no demuestra snapshot consistente en producción.

```text
MB1_B18C_NONCOOPERATIVE_DIAGNOSTIC=PENDING
MB1_UNIVERSAL_CAPTURE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_OPERATIONAL_RECOVERY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
