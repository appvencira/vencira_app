# B17C2 — Integración HTTP entre contenedores

## Resultado

B17C2_RESULT=0
B17C2_NETWORK_E2E=OK
B17C2_ATOMIC_PG17=OK
B17C2_INTEGRATION_GATE=OK
B17C2_DJANGO_EXIT_CODE=0

## Arquitectura ensayada

- Firmante independiente en contenedor Docker.
- Receptor Django B17 en otro contenedor.
- Comunicación HTTP en red Docker interna.
- PostgreSQL 17 temporal.
- Claves Ed25519 sintéticas.
- Clave privada no montada en Django.
- Sin puertos públicos ni archivos reales.

## Verificaciones superadas

- Recepción HTTP: 201.
- Repetición: 409.
- HMAC incorrecto: 403.
- Evidencia manipulada: 403.
- Firma falsificada: 403.
- Una evidencia persistida.
- Un nonce persistido.
- Cuarentena conservada.
- Base de pruebas eliminada correctamente.

## Límites de la validación

El ensayo no acredita TLS, custodia externa real
ni autorización operacional.

No se realizaron migraciones sobre la base persistente.

B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
