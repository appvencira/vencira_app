# VENCIRA

Aplicación de gestión de vencimientos, anotaciones y seguimiento de seguros. No es un CRM genérico.

**Repositorio oficial:** `appvencira/vencira_app`. **Rama de integración:** `main`.

## Estado de desarrollo (8 de noviembre de 2026)

VENCIRA utiliza Django 5, PostgreSQL 17 y Flutter web/Android. En `main` están documentados y validados los ensayos de seguridad **I8-M a I8-Q**, con límites diferentes: HTTPS Flutter–Django y MFA sintético sobre PG17 temporal; Keystore Android y persistencia tras reinicio físico; fallos sintéticos del almacenamiento; integración física Android por HTTPS, recuperación MFA y revocación; y matriz de regresión Flutter 30/30 PASS. Estos resultados **no equivalen** a autorización de MFA operativo, acceso normal integrado o despliegue.

El entorno DEV sigue separado y no modificado. D1-A confirmó 24 migraciones del código no registradas en DEV (9 de `reminders` por ensayar; 15 de aplicaciones laboratorio excluidas de DEV). La restauración O5, el ensayo de migraciones compatibles, el rollback y la validación operativa siguen pendientes.

El trabajo restante se agrupa en [cuatro bloques de cierre](docs/REMAINING_WORK_GROUPED_2026-11-08.md): I8-R interrupciones controladas reales, integración funcional/visual de APK, D1 backup+schema+rollback y autorización/despliegue escalonado.

## Restricciones obligatorias

- `MFA_RELEASE_AUTHORIZED=NO`
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`
- No desplegar, no ejecutar migraciones sobre bases persistentes, no habilitar endpoints de emisión/recuperación nativa ni activar el cliente candidato desde `main.dart`.
- Pruebas de backend con PostgreSQL 17 desechable y secretos sintéticos. Conservar integridad de contenedores DEV y datos reales.
- Los cambios se incorporan en lotes pequeños y verificables directamente a `main`, sin ramas nuevas ni fusiones masivas.

## Próximos hitos

1. I8-R, resiliencia Android con pérdida controlada de respuestas HTTPS en laboratorio y conciliación PG17.
2. Integración de la APK funcional y validación visual de clientes, vencimientos, calendario y notificaciones.
3. D1 backup/restore, ensayo de migraciones y rollback; checklist de despliegue cuando corresponda.

## Documentación de continuidad

- [Plan agrupado de trabajo restante — I8-R a despliegue](docs/REMAINING_WORK_GROUPED_2026-11-08.md)

- [Preparación del despliegue DEV — D1, solo lectura](docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md)
- [Continuidad maestra — 08/11/2026](docs/CONTINUITY_HANDOFF_2026-11-08.md)
- [Política de integración de main](docs/MAIN_INTEGRATION_POLICY_2026-11-08.md)
- [Auditoría de ramas y plan de cierre de main](docs/MAIN_BRANCH_AUDIT_2026-11-08.md)
- [Registro de consolidación](docs/MAIN_CONSOLIDATION_2026-11-08.md)

No confundir código integrado, test ejecutado, despliegue y autorización de publicación.
