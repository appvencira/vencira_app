# VENCIRA

Aplicación de gestión de vencimientos, anotaciones y seguimiento de seguros. No es un CRM genérico.

**Repositorio oficial:** `appvencira/vencira_app`. **Rama de integración:** `main`.

## Estado de desarrollo (8 de noviembre de 2026)

El proyecto tiene backend Django, PostgreSQL 17 y cliente Flutter web/Android. Se han validado múltiples módulos y ensayos de seguridad en entornos aislados, incluido el flujo candidato de autenticación y recuperación nativa I8-H–I8-L. **Esos PASS corresponden a los entornos y revisiones históricas que los ejecutaron; no acreditan una integración completa en `main`.**

`main` está en consolidación progresiva y conserva cambios propios que no deben sobrescribirse. El 08/11/2026 se incorporó directamente a `main` el cierre seguro de recuperación I8-L (obligación de nuevo MFA después de contraseña, también ante respuestas hostiles del adaptador) y su test de regresión. **Los tests de esa nueva integración aún requieren ejecución sobre `main`.**

El entorno DEV existente y sus copias operativas son distintos del estado de integración GitHub. Ni los cambios actuales ni el historial de pruebas autorizan la publicación o el uso de datos personales reales.

## Restricciones obligatorias

- `MFA_RELEASE_AUTHORIZED=NO`
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`
- No desplegar, no ejecutar migraciones sobre bases persistentes, no habilitar endpoints de emisión/recuperación nativa ni activar el cliente candidato desde `main.dart`.
- Pruebas de backend con PostgreSQL 17 desechable y secretos sintéticos. Conservar integridad de contenedores DEV y datos reales.
- Los cambios se incorporan en lotes pequeños y verificables directamente a `main`, sin ramas nuevas ni fusiones masivas.

## Próximos hitos

1. Consolidación de `main`: inventario de módulos, comparación de dependencias y gates sobre la revisión integrada.
2. I8-M: recuperación Flutter por HTTPS auténtico contra backend aislado PG17, con CA/hostname verificados.
3. Recuperación en Android físico con almacenamiento protegido y túnel Termius; después APK funcional y revisión visual.

## Documentación de continuidad

- [Preparación del despliegue DEV — D1, solo lectura](docs/D1_DEV_DEPLOY_PREPARATION_2026-11-08.md)
- [Continuidad maestra — 08/11/2026](docs/CONTINUITY_HANDOFF_2026-11-08.md)
- [Política de integración de main](docs/MAIN_INTEGRATION_POLICY_2026-11-08.md)
- [Auditoría de ramas y plan de cierre de main](docs/MAIN_BRANCH_AUDIT_2026-11-08.md)
- [Registro de consolidación](docs/MAIN_CONSOLIDATION_2026-11-08.md)

No confundir código integrado, test ejecutado, despliegue y autorización de publicación.
