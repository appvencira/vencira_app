# B13E + preparación B13F

## B13E: identidad de firmante verificable

- Contrato Ed25519 v3 separado de v2 y HMAC.
- `key_id` está dentro de la carga firmada.
- Identificador y firma se conservan en la evidencia.
- Se utiliza el registro público de confianza B13D.
- Rechazo de claves desconocidas, revocadas y firmas
  de otro firmante.
- PostgreSQL 17 temporal, transacción, bloqueo de fila
  y barrera cooperativa.
- Sin nuevas migraciones: se utiliza JSONField existente.
- No cambia el estado del documento ni habilita descargas.

## B13F: diseño de aislamiento operacional

Pendiente de implementación y pruebas reales:

1. Firmante en servicio independiente, sin acceso a
   credenciales de Django ni escritura en PostgreSQL.
2. Clave privada custodiada fuera del contenedor API.
3. API verificadora con claves públicas exclusivamente.
4. Canal de entrada autenticado, sin aceptar evidencias
   de remitentes no autorizados.
5. Escaneo ClamAV real y evidencia de cadena de custodia.
6. Protección contra repetición y rotación de confianza.
7. Validación de backups, recuperación y auditoría.

Los contratos HMAC y Ed25519 v2 se conservan como
caminos de ensayo históricos, sin habilitar producción.

B13E_OPERATIONAL_RELEASE=NO
B13F_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
