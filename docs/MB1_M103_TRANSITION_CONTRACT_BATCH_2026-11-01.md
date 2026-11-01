# VENCIRA — continuación M103: contrato de transición (01/11/2026)

## Alcance y procedencia
Base: `docs/HANDOFF_VENCIRA_MB1_M103_2026-11-01.md` y `docs/VENCIRA_MASTER_COMPLETION_CHECKLIST_2026-10-30.md`, leídos en GitHub. Rama de trabajo **aislada** `feature/mb1-m104-transition-contract-batch`, creada desde `feature/c-ficha-independent-attachments`. No se despliega ni modifica DEV o PostgreSQL persistente.

## Trabajo añadido
- `backend/renewal_attachments/transition_contract.py`: comparación pura, sin Django, SQL, FS ni secretos. Compara 10 campos incluidos `created_at`, rechaza inventarios malformados, IDs duplicados y claves de almacenamiento duplicadas dentro de cada lado; cuantifica ausencias, divergencias y uso cruzado de clave.
- `backend/renewal_attachments/test_transition_contract_batch.py`: 11 escenarios sintéticos, incluyendo vacíos, igualdad, ambos sentidos de ausencia, cambio de timestamp/hash, reutilización cruzada, duplicados y registros malformados.
- `scripts/validate_mb1_transition_contract_batch.sh`: único runner de ese subgrupo, sin servicios ni operaciones persistentes.

## Advertencia importante
**La comparación nueva todavía NO está integrada en `transition_reconciliation.py`.** El intento de reemplazar ese archivo devolvió CONFLICT 409 del conector; no se forzó la escritura. Por ello NO afirmar que la ruta de reconciliación existente detecta estos casos, ni que hay un gate PG17/HTTP listo. Es desarrollo parcial de defensa y especificación; falta integración y ensayo conjunto.

## Validación
Estado: **NO EJECUTADO por el operador**. No hay PASS ni exit code conocido. No se reejecutaron M103, MFA, HBA, O5, ClamAV ni DR.

Para comprobar únicamente el subgrupo nuevo sobre una copia local de esta rama:
```bash
bash scripts/validate_mb1_transition_contract_batch.sh
```

## Siguiente integración necesaria
1. Integrar comparador en `transition_reconciliation.py` con protección de concurrencia explícita y comprobar esquema histórico, especialmente `created_at`, en clon; un conflicto de escritura debe resolverse sin sobrescribir.
2. Componer un **solo** gate PG17 sintético con coexistencia histórica test-only, grafo sin MFA para el split, prueba HTTP mediante cliente real y middleware, rol no superusuario y fallos de objetos, con datos exclusivamente sintéticos.
3. Mantener historial/objetos cifrados intactos en cualquier fallo; no declarar transición completa sin reconciliación/verificación cruzada, freeze universal y custodia externa.
4. Publicar evidencia real, actualizar checklist solo tras PASS efectivo; no marcar hito cerrado por tests unitarios.

## Estado de liberación
```text
MB1_RELEASE_AUTHORIZED=NO
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```
Hitos principales formalmente cerrados: 1/15 (6,7 %), **sin cambios**.
