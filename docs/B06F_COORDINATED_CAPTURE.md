# VENCIRA — B06F: captura sintética coordinada

## Cobertura

Se ensayan conjuntamente:

- Bloqueo exclusivo de captura.
- Lectura real del modelo RenewalAttachment en PG17.
- Inventario sintético de objetos cifrados.
- Diario sintético.
- Validación B06A de los marcadores.
- Empaquetado cifrado B03/B05.
- Conciliación B05C de los bytes originales.
- Bloqueo de un escritor cooperativo.
- Liberación ante un error.

## Limitaciones

El inventario externo de ciphertext se prepara en el
propio ensayo. No constituye una prueba independiente
de que el almacenamiento real y la BD sean atómicos.

Los marcadores de captura son sintéticos.
No existe todavía un coordinador duradero ni un epoch
gestionado transaccionalmente.

La recuperación valida los datos en memoria; B06F
no ejecuta pg_dump/pg_restore con el esquema real.

B06F no verifica otros escritores externos al protocolo,
ni introduce backup operativo, rotación de claves,
descarga, eliminación pública o autorización.

Siguiente gate: restauración en un segundo PG17 aislado
desde dump con esquema real, junto al contenido cifrado
y diario capturados bajo un protocolo coordinado.

B06F_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
