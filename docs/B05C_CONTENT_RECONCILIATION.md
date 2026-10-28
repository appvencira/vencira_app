# VENCIRA — B05C: conciliación completa de recuperación

La comprobación experimental contrasta tres fuentes:

1. Integridad criptográfica del paquete de backup.
2. Metadatos independientes atribuidos a PostgreSQL:
   SHA-256 y tamaño del documento original.
3. Contenido del diario: identidad y SHA-256.

La clave de backup y la de adjuntos son independientes.

## Condiciones pendientes

- El inventario externo debe provenir realmente de PostgreSQL
  bajo una captura temporalmente coherente.
- Deben comprobarse las relaciones de workspace, póliza,
  propietario y ciclo de vida con el esquema real.
- Debe existir custodia externa y versionado operativo.
- Deben verificarse respaldos y restauraciones remotos.
- El diseño actual modela diarios pendientes; no representa
  todos los estados futuros de un diario operativo.
- La prueba usa objetos sintéticos y no habilita documentos.

B05C_CONTENT_RECONCILIATION=EXPERIMENTAL
B05C_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
