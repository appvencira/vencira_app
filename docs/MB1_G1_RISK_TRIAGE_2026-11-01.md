# VENCIRA — G1 clasificación de riesgo de escritores, 01/11/2026

Se registró la auditoría anterior: 330 archivos Python, 893 candidatos de escritura, 106 revisiones dinámicas, 0 errores. Esos recuentos no equivalen a escrituras operativas ni a los 131 P0 del otro clasificador.

Nuevo `scripts/mb1_g1_risk_triage.py`: usa el AST anterior y separa `RUNTIME_CANDIDATE`, `MIGRATION`, `LAB` y `TEST`; clasifica aparte llamadas SQL (`execute`, `executemany`, `commit`, `rollback`) y algunas operaciones filesystem. **Clasificación heurística por ruta y nombre, no análisis semántico concluyente.** Un módulo de pruebas mal situado puede aparecer como runtime; un escritor real dentro de un laboratorio puede estar mal etiquetado. La etiqueta runtime tampoco significa que un proceso lo cargue. Las llamadas SQL pueden ser consultas de lectura. Se imprimen contadores agregados y nunca contenido o rutas de credenciales.

Este instrumento está publicado, aún sin ejecución confirmada. No reejecutar tests previos. Después del conteo deberá hacerse revisión por callsite de los candidatos runtime, imports/callers reales y de las 106 llamadas dinámicas, más Bash, cron, systemd, SQL externos y permisos de Docker.

G1 sigue sin certificarse, G2/G3 bloqueados. MB1_GLOBAL_FREEZE=NOT_VERIFIED; MB1_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1. Progreso 1/15.
