# VENCIRA — G1 revisión por callsite runtime (01/11/2026)

La auditoría previa contabilizó 112 candidatos de escritura y 34 llamadas dinámicas en archivos etiquetados `RUNTIME_CANDIDATE`. Son etiquetas heurísticas, no rutas operativas confirmadas.

Se publicó `scripts/mb1_g1_runtime_review_ledger.py`, que genera un CSV con ruta relativa del repositorio, línea, función/clase contenedora, clase SQL/FS/ORM/dinámica y estado PENDING. No ejecuta ni importa el código que inspecciona. La detección SQL no analiza aún la sentencia: cualquier `execute` se clasifica como revisión pendiente y puede ser SELECT. Las funciones de acceso indirecto y los escritores no Python requieren auditoría separada.

Nuevo runner `scripts/validate_mb1_g1_runtime_review_ledger.sh`: tres tests unitarios y auditoría temporal del código de la rama, borrando el CSV al salir. No requiere Docker, acceso a DEV ni secretos. **NO EJECUTADO; no afirmar PASS**.

Para revisión humana posterior se deberá producir una matriz versionada de rutas operativas, criticidad, permisos, consumidores, procedimientos de bloqueo, evidencia de ejecución y responsable, sin subir a GitHub información sensible de infraestructura.

G1=OPEN; G2=OPEN; G3=OPEN; MB1_GLOBAL_FREEZE=NOT_VERIFIED; MB1_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1. Hitos formales 1/15 (6,7%).
