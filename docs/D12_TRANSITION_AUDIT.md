# D12 — Conciliación histórica

Auditoría estricta en PostgreSQL 17 efímero.

Compara identificadores, renovaciones, usuarios,
nombres, tipos MIME, tamaños, huellas, claves,
estados y fechas entre ambos esquemas.

Usa una transacción READ ONLY / REPEATABLE READ.
No escribe, copia ni borra registros.

D12B_TEST_RESULT=0

Límites:
- Las pruebas utilizan registros sintéticos.
- No se ha conciliado ningún registro real.
- No se han verificado objetos cifrados ni claves reales.
- No se ha restaurado todavía una copia O5.
- Un resultado coincidente no autoriza despliegue.

C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
