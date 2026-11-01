# VENCIRA — Revisión G1 de llamadas críticas (01/11/2026)

La herramienta `scripts/mb1_g1_critical_callsite_audit.py` analiza únicamente AST del código Python candidato runtime y emite un CSV temporal con llamadas SQL, filesystem y ejecución dinámica. Distingue SQL literal candidato de mutación, SQL dinámico y SQL potencialmente de lectura, sin concluir que `WITH`/`SELECT` carezcan de efectos colaterales. Las operaciones de archivos y ejecución dinámica continúan como `PENDING`.

Se añadieron dos tests de clasificación en `scripts/test_mb1_g1_critical_callsite_audit.py` y se conectaron tanto tests como auditoría al workflow `.github/workflows/mb1-audit.yml`.

**Pendiente de confirmar ejecución satisfactoria en GitHub Actions.** No cambia DEV, no emplea secretos, no hace deploy ni cierra G1–G3. Los 146 callsites previos continúan pendientes de verificación humana y de accesibilidad en runtime. Deben inventariarse además shell, cron, procesos externos, privilegios de base de datos y acceso al filesystem.

`MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Cierre formal 1/15.
