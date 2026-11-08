# Plan de integración selectiva a main — VENCIRA (08/11/2026)

## Resultado del preflight de GitHub

- Rama de destino: `main`.
- Rama de transición actual: `feature/mb1-m104-transition-contract-batch`.
- Rama de trabajo Android/MFA: `feature/m3-android-local-notifications`.
- Pull request #17: **OPEN, DRAFT**, base transición, head Android/MFA, sin fusionar.
- `compare main...feature/m3-android-local-notifications`: **diverged**, 3945 commits ahead y 19 behind; comparador devuelve 300 archivos (límite/recorte del listado).
- `compare main...feature/mb1-m104-transition-contract-batch`: **diverged**, 2573 commits ahead y 19 behind.
- **No fusionar PR #17 ni hacer merge general en main**: arrastraría múltiples fases, contratos de prueba y dependencias aún sin revisión de integración.
- No se ha realizado merge, despliegue ni migración operativa durante este preflight.

## Política de promoción

1. Tomar la última `main` como base fresca para cada PR de promoción (nunca crear una PR de miles de commits por dependencia accidental).
2. Identificar dependencias **de cada bloque de código** mediante diffs y el árbol de imports/migraciones; no copiar archivos aislados cuya configuración dependa de macros no promovidas.
3. Separar las promociones por contrato y riesgo:
   - A. Documentación, scripts de prueba sin efectos y gates preflight verificables.
   - B. Código de backend candidato cerrado por flags y ausencia explícita en `config.urls`, con pruebas aisladas PG17.
   - C. Cliente nativo Flutter no conectado a `main.dart`, con análisis/test/build y negative paths.
   - D. Interfaz/funcionalidades operativas: solo con autorización específica de release, pruebas E2E y rollback.
4. Exigir los gates pertinentes **contra el commit de la PR construido desde main**, no reutilizar ciegamente un PASS obtenido en la rama antigua.
5. Verificar que `VENCIRA_NATIVE_BEARER_ENABLED=0`, `VENCIRA_NATIVE_SERVICE_CANDIDATE` permanece test-only, `MFA_RELEASE_AUTHORIZED=NO`; migraciones MFA/nativo no pasan a aplicación operativa automáticamente.
6. Reconciliar los 19 commits propios de `main` y no eliminar hotfixes por error; documentar conflictos. No fusionar ante conflictos sin revisión.
7. No ejecutar `docker compose up`, migraciones DEV/live, `git push` a servidor de despliegue o publicación APK como parte de una PR.
8. Una fusión controlada de un PR a `main` **no implica despliegue**. Mantener explícito `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Estado de promoción

**PENDIENTE.** Antes de abrir el primer PR selectivo hay que preparar una rama basada en la `main` actual, trasladar un conjunto autocontenido de cambios y ejecutar los gates en esa base. Los resultados I8-H/I8-I/I8-J/I8-K/I8-L en laboratorio validan sus ámbitos pero no prueban compatibilidad de la rama total con `main`.

Próximos pasos: elaborar inventario de dependencias por archivos y gates, seleccionar primer lote que no toque la superficie operativa, preparar rama de promoción, validar y abrir PR pequeña de revisión.
