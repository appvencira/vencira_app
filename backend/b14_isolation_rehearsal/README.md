# B14A — Separación de imágenes, solo ensayo

Dos imágenes Docker independientes:

- **signer**: firma evidencia sintética Ed25519 v3.
- **verifier**: valida evidencia y clave pública sin importar
  el código del firmante ni utilizar Django.

No es un servicio de antivirus y no autoriza ninguna
operación sobre archivos reales.

La clave privada se genera solo en memoria del firmante.
El intercambio contiene únicamente firma, metadatos
sintéticos y clave pública.

Contenedores sin red, con raíz de solo lectura, sin
capacidades adicionales y sin credenciales de base de datos.

Pendiente antes de cualquier despliegue:
- Integración del resultado real ClamAV, no sintético.
- Separación efectiva de escaneo y firma.
- Gestión de claves privadas y rotación operacional.
- Autenticación del transporte y protección contra repetición.
- Revisión de aislamiento, pruebas de intrusión y recuperación.
- Integración con el receptor Django sin permisos de descarga.

B14_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
