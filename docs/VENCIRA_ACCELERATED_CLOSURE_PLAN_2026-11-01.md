# VENCIRA — Plan de aceleración por paquetes de cierre (01/11/2026)

## Baseline y reglas
Fuente: `docs/HANDOFF_VENCIRA_MB1_M103_2026-11-01.md` y `docs/VENCIRA_MASTER_COMPLETION_CHECKLIST_2026-10-30.md`. Evidencia última: contrato sintético de transición 11/11 PASS el 01/11, sin PG17/HTTP. Hitos 1/15, no equivale a avance lineal de implementación. Mantener `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

No tocar DEV, PostgreSQL persistente, O5 instalado, Caddy, cron, claves ni volúmenes operativos. Trabajar en rama aislada, sin merge/deploy. Ningún `migrate` global que incluya MFA. Probar con fixtures y PG17 efímero, nunca con datos reales. La comprobación de compatibilidad del grafo y de autoría de tablas es condición previa a cada fase.

## Paquete A — Transición + rol SQL + HTTP; una ejecución agrupada
**M1-03, soporte parcial M2-02/M2-03.** Integrar y probar contratos ya versionados sin repetir las 11 unitarias PASS.
1. Preflight estático: rutas de migración sin MFA, registrar exactamente qué modelo histórico existe; dos esquemas en clon separado solo cuando las migraciones de histórico sean reproducibles sin tocar persistente. No importar conciliación en modo que oculte Legacy; abortar ante incompatibilidad.
2. PG17 temporal: permisos mínimos no superuser y prohibiciones DDL/TRUNCATE/grants, transacción y rollback, cero/modos histórico/independiente, metadatos de 10 campos, colisiones/duplicados, inconsistencia, objeto ausente/no legible y tolerancia a escrituras concurrentes. El informe no puede autorizar despliegue ni migración.
3. Cliente HTTP real a través de Django middleware (no `APIRequestFactory`): autenticar, aislar tenants, verificar CSRF/sesión según ruta, listar solo metadatos y denegar upload/download/delete sin entregar bytes; documentar las rutas realmente cubiertas. No afirmar que MFA está activo.
4. Gate compuesto con limpieza de recursos temporales y reporte `PASS/FAIL/BLOCKED` por subprueba; fail-closed si no existe grafo compatible. Una única ejecución por operador para todas las novedades.
**Aceptación:** ausencia de mutación persistente, matriz observable, conflictos rechazados y recursos efímeros eliminados. No cerrar M1-03 por sí solo: censo universal de escritores sigue pendiente.

## Paquete B — Frontera de escritores + respaldo integral + reconciliación
**M1-02, M1-03, M1-04, M1-05.** Una batería sobre entorno efímero con PG17+objeto+diario, error/ACK ambiguo y captura coherente; enumerar procesos/roles y vías SQL/FS. Para probar exclusión de actores no cooperativos, usar frontera física/lógica verificable (revocación efectiva de acceso, permisos, red y mounts); abortar ante superusuario o actor host fuera de control. Ensayar restauración y generación antigua con ancla antirollback separada. No repetir tests puros ni O5 PG-only ya acreditados; solo delta de integración. **Bloqueo real:** exclusión universal no demostrada; no prometer cierre de los cuatro hitos automáticamente.

## Paquete C — Custodia y desastre fuera del origen
**M1-05, M1-06, M1-07, M2-01.** Necesita Ubuntu x86_64 independiente, custodio B distinto del VPS, claves y cabeza antirollback externas, recuperación integral PG17+objetos+diario y comprobación de controles MFA. No repetir el preflight de segundo host en el propio origen ni sortear `ORIGIN_CONTAINER_PRESENT`. Si no hay segundo host, marcar `BLOCKED_EXTERNAL_RESOURCE` y desarrollar paquetes A/D en paralelo, no simular evidencia operacional.

## Paquete D — Producto y aceptación V1
**M2-02, M2-03, M2-04, M3-01..M3-04.** Revisión de diferencias whitepaper/código, UX móvil, reglas de vencimiento, recordatorios y roles. Un solo conjunto de pruebas Flutter/Django/E2E/accesibilidad con fixtures. Clon y rollback de migraciones por ruta explícita, MFA/adjuntos separados y sin release si falta custodia. Preparar manual y plan de despliegue gradual, sin desplegar.

## Secuencia práctica para reducir ciclos
A (desarrollo y gate único) → B (reconciliación/freeze/backup integral) mientras se prepara externamente C → D (producto+E2E) → revisión final de C y gates de liberación independientes. B y D pueden desarrollarse sin esperar al segundo host, pero ninguna dependencia de seguridad se dará por satisfecha por adelantado.

## Registro obligatorio en cada paquete
Rama, commit, script, versión de código realmente ejecutada, prueba y resultado, recursos creados/eliminados, salud DEV solo si verificada sin cambios, límites, hito afectado y motivo explícito para [x] o [ ]. No se modifica el porcentaje con pruebas nuevas si el hito completo no ha cerrado.

## Estado inicial del plan
A=PLANNED; B=PLANNED; C=BLOCKED_EXTERNAL_RESOURCE; D=PLANNED. Ningún gate adicional ejecutado por crear este documento. Progreso oficial: 1/15 (6,7%).
