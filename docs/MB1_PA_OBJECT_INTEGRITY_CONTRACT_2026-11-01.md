# VENCIRA — paquete A continuación, auditoría de objetos (01/11/2026)

## Evidencia heredada que NO se repite
- Contrato metadatos: 11/11 PASS.
- Gate PG17 split + HTTP middleware real y rol SQL limitado: `MB1_PA_RESULT=0`, `PHASE=DONE`.
- Coexistencia histórica: `NOT_RUN`; freeze global: `NOT_VERIFIED`; autorizaciones: NO.

## Cambio y motivación
Se inspeccionó `transition_object_audit.py`: el informe distinguía metadatos alineados de contadores de bytes corruptos o ilegibles, pero **no exponía una decisión explícita de integridad total de objetos**. Para impedir interpretar `metadata_aligned=True` como verificación de bytes, se agregó `objects_acceptable`, inicializado en False y calculado solo cuando coinciden recuentos y no existe ningún error de lectura/hash/tamaño. **No** se cambia `release_authorized=False`.

Nuevo comparador puro en `transition_object_contract.py`, pruebas adversariales en `test_transition_object_contract.py` y comando unitario `scripts/validate_mb1_pa_object_contract.sh`. Casos: inventarios vacíos/iguales, divergencias, objetos perdidos, ilegibles, hash y tamaño alterados, recuentos negativos, booleanos inesperados y alineación malformada. Sin DB, secretos ni disco de datos.

**Estado de las nuevas pruebas: NO EJECUTADAS.** No afirmar PASS antes de la salida del operador.

## Alcance pendiente esencial
El informe es asesor: no verifica todavía un objeto real, no asegura un snapshot coherente sin freeze y no prueba coexistencia de tablas históricas en PG17. La importación de `transition_reconciliation` exige el modelo Legacy registrado, ausente intencionalmente en el gate HTTP split anterior. No habilitar migración 0027 ni ejecutar `migrate` sin objetivo.

Para cerrar la transición de datos harán falta en clon aparte: fixtures históricos y nuevos + objeto cifrado, grafo de migraciones compatible y validación de rollback, con un único gate posterior. Si el histórico exige MFA 0019-0027, declarar bloqueo y no simular un camino de producción.

## Estado formal
M1-03 [ ]; M2-02 [ ]; M2-03 [ ]. Total 1/15 (6,7 %). `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
