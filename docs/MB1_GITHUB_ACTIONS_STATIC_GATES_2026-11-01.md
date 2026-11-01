# VENCIRA — GitHub Actions para auditorías MB1 (01/11/2026)

Workflow incorporado: `.github/workflows/mb1-audit.yml` en `feature/mb1-m104-transition-contract-batch`. Se activa por push en la rama de trabajo y main, PR y manual cuando el workflow esté disponible en la rama predeterminada. Ejecuta G1 inventario AST, clasificación de riesgo, ledger runtime con sus tests y contrato fail-closed G1-G3. Usa Ubuntu 24.04/Python 3.12. Sin credenciales del VPS, SSH, deploy, DB live ni migrations. Permisos `contents: read`, checkout sin credenciales persistentes, timeout 12 minutos y cancelación de runs obsoletos.

El workflow existente `.github/workflows/ci.yml` ya define pruebas Django/Flutter/PG17 para main/PR; **no se duplica ni modifica aquí**. Esta aportación cubre los nuevos gates estáticos en rama. Los scripts siguen marcando G1 semántico, exclusión universal y liberación como NOT_VERIFIED/NO. Se puede correr CI en repo público pero no se deduce que todo workflow sea ilimitado en capacidad, concurrencia ni cuota de almacenamiento.

**Estado inicial:** workflow publicado, ejecución de GitHub Actions pendiente de observar. No afirmar PASS ni cerrar hitos. Si fallase por configuración o políticas de Actions, revisar logs y reglas del repo antes de cambiar DEV.

MB1_GLOBAL_FREEZE=NOT_VERIFIED; MB1_RELEASE_AUTHORIZED=NO; MFA_RELEASE_AUTHORIZED=NO; C_FICHA_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1. Progreso 1/15.

## Revisión de callsites aprovechable en CI (01/11)

Ahora el workflow genera dos CSV: `runtime-review.csv` (ORM, SQL, filesystem y dinámicos) y `critical-review.csv` (SQL/FS/dinámicos), ambos con ruta relativa, línea y tipo, **sin fragmentos de código ni valores SQL**. Se guardan como artefacto `g1-review-<sha>` de GitHub Actions durante 7 días. En repositorio público, los artefactos de Actions pueden ser visibles según permisos del repositorio; no incluir datos internos ni secretos. No se suben a Git como archivos. Este cambio permite revisar los casos reales sin repetir auditorías localmente.

La consulta disponible de runs vinculados al commit `87629b9` devolvió lista vacía; esta consulta está limitada a ejecuciones asociadas a PR y **no acredita que el workflow no se ejecutase**. Ningún resultado CI se ha confirmado todavía. Los CSV son listas candidatas, no evidencias de revisión semántica terminada ni autorización de release.
