# VENCIRA — Macrofase C: revisión de publicación

Fecha: 2026-10-28

## Componentes validados anteriormente

- Modelo independiente y migraciones en PostgreSQL 17 efímero.
- Ensayos aislados de ClamAV.
- Descarte con outbox persistente.
- Recuperación después de caída abrupta de un worker.
- Panel Flutter de documentos.
- Análisis, tests y compilación Flutter Web.

## Corrección adicional

- Distinguir ausencia de archivo individual y ausencia del
  directorio privado durante operaciones de descarte.
- Incorporar pruebas de regresión específicas.
- Pendiente confirmar ejecución efectiva de esas pruebas.

## Bloqueos de publicación

- Transición revisada entre esquema histórico e independiente.
- Auditoría completa de autorización HTTP y aislamiento por workspace.
- Revisión de almacenamiento, claves y permisos de producción.
- Confirmación de controles de subida, escaneo y descarga.
- Ensayo integral de recuperación y rollback.
- Autorización expresa de publicación.

## Decisión

MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1

No se permite activar operaciones con documentos reales.
