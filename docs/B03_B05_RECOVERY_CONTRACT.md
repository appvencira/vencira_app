# VENCIRA — B03–B05: contrato de recuperación v1

## Implementado

- Paquete cifrado con Fernet.
- Inventario y SHA-256 de objetos cifrados.
- Correspondencia estricta objeto/diario.
- Identificadores de versión de claves.
- Identificador de snapshot externo PostgreSQL.
- Verificación sin restaurar ni escribir archivos.
- Comparación con inventario externo de huellas.

## Limitaciones

Este código es experimental y no está conectado a DEV.

No implementa:
- captura consistente entre PostgreSQL y archivos;
- respaldo programado ni subida a Drive;
- retención ni purga de copias;
- custodia externa de claves;
- rotación efectiva de archivos anteriores;
- restauración operacional en servidor independiente;
- descifrado o verificación semántica del diario;
- reconciliación real con las tablas PostgreSQL.

El identificador de snapshot es un vínculo lógico: NO
certifica por sí solo que dos capturas sean consistentes.

Las huellas de BD comparadas son SHA-256 de los bytes
cifrados, no el SHA-256 del documento original.

## Requisitos antes de producción

1. Diseñar y probar una frontera de captura consistente.
2. Implantar custodia externa y versionado de claves.
3. Definir RPO/RTO y política de retención.
4. Ensayar restauración íntegra con PG17 y archivos.
5. Validar el diario y los metadatos realmente restaurados.
6. Completar permisos, antivirus operativo y revisión RGPD.
7. Obtener autorización expresa de publicación.

B035_CONTRACT_VERSION=1
B035_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
