# VENCIRA — B13A: frontera entre trabajador y backend

## Integración experimental

El trabajador existente:
- Lee cuarentena cifrada.
- Comprueba los bytes.
- Invoca un escáner.
- Firma únicamente el resultado limpio válido.

El receptor nuevo:
- No invoca ClamAV.
- No posee la función de firma.
- Verifica el resultado recibido.
- Comprueba la huella de metadatos.
- Persiste la evidencia bajo barrera PostgreSQL.
- No cambia el estado del documento.
- No autoriza descargas.

## Limitaciones

Las pruebas utilizan un escáner sintético inyectado.
El receptor todavía recibe una clave de verificación
HMAC que, por ser simétrica, también podría firmar.
Por tanto NO existe aislamiento criptográfico real
entre el backend y el firmante.

Antes de producción:
- Separar procesos y credenciales.
- Preferir firmas asimétricas para que el backend
  únicamente posea una clave pública.
- Autenticar el canal entre procesos.
- Validar ClamAV real y actualización de firmas.
- Comprobar autorización por workspace y renovación.
- Revisar RGPD, retención y custodia externa.
- Completar la captura consistente operativa.

No se modifica O5 ni PostgreSQL persistente.

B13A_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
