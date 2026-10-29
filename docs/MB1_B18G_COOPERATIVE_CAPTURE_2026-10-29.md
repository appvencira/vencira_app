# VENCIRA — B18G coordinador de captura cooperativa sintética

Fecha: 29/10/2026. No despliegue ni migración persistente.

## Alcance

B18C confirma que el advisory lock se puede ignorar; B18D/F ensayaron locks SQL que no congelan filesystem; B18E validó la integridad del contrato de captura (12/12). B18G **combina** la barrera B06B con el verificador B18E para probar con PG17 temporal que los escritores *que participan* en el bloqueo compartido esperan durante el corte exclusivo. Una lista explícita de cuatro caminos ensayados sirve como precondición; la falta de un escritor o la aparición de uno nuevo sin revisar impiden la captura sintética.

Artefactos: `offline_cooperative_capture_b18g.py`, `test_b18g_cooperative_cut_pg17.py` (6 tests) y modo `B18G_COORDINATOR_ONLY=1` de `scripts/rehearse_c_ficha_split_readonly.sh`.

## Advertencias

- El registro de cuatro writers **no es un inventario exhaustivo**: su coincidencia NO demuestra cobertura global. La señal `drained=True` sigue siendo externa y no verificada.
- El locking B06B es consultivo, de sesión y permitido **solo en test/PG17 aislado**. Un ORM directo, escritor externo o escritura de disco pueden ignorarlo.
- Los inventarios proceden de callbacks del llamador, no son instantáneas independientes autenticadas.
- No se genera backup persistente, `pg_dump` real ni copia a soporte externo, ni se prueba una restauración tras pérdida del VPS.
- Las autorizaciones operativas permanecen negadas, incluso si pasan los 6 tests.

## Gate focalizado en VPS

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
B18G_COORDINATOR_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "B18G_EXIT_CODE=$?"
```

Salidas esperadas, **todavía sin ejecutar**: `B18G_COOPERATIVE_CUT=OK`, `B18G_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED`, `C_FICHA_SPLIT_PG17_RESULT=0`, `B18G_EXIT_CODE=0`.

## Criterios restantes para cerrar MB1

Inventario completo y estático verificable de mutadores API, trabajadores, ORM, SQL, outbox, diario y objetos; mecanismo fail-closed para writers fuera de protocolo, incluida capacidad de suspender operaciones filesystem; corte inmutable y autenticado de DB+objetos+diario; restore PG17 externo tras falla; custodia externa real; autorización humana. No repetir gates B18C–F sin cambios relevantes.

```text
B18G_CODE=READY
B18G_PG17_TESTS=PENDING
MB1_GLOBAL_FREEZE=BLOCKED
MB1_EXTERNAL_CUSTODY=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
