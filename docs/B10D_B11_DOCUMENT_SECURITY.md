# VENCIRA — B10D/B11 seguridad documental

## Integrado experimentalmente

- Lectura desde almacén de cuarentena cifrado.
- Identidad del objeto tomada exclusivamente del ORM.
- Comprobación de tamaño y SHA-256.
- Escaneo mediante adaptador inyectable.
- Evidencia HMAC con barrera cooperativa PG17.
- Rechazo de objeto ausente, cifrado alterado,
  contenido discordante, amenaza o motor no disponible.
- Documento permanece en cuarentena tras resultado limpio.
- `may_download_attachment` mantiene denegación absoluta.

## Limitaciones

Los tests utilizan un escáner simulado.
La integración no supone un servicio real ClamAV,
ni firma aislada, ni permisos de descarga.

La lectura del almacén todavía ocurre antes de adquirir
una barrera cooperativa de captura que abarque todo
el ciclo de escaneo. La captura operacional no está
implementada y requiere diseño adicional.

El bloqueo HTTP existente no se modifica en esta fase.
La revisión funcional de Flutter queda pendiente.

Nunca utilizar documentos personales o claves reales.

B10D_STORE_SCAN=EXPERIMENTAL
B11_DOWNLOAD_ACCESS=DENIED
B10D_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
