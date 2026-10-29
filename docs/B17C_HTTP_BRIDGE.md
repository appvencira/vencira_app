# B17C1 — Adaptador HTTP del receptor B17

El adaptador HTTP no implementa firma, verificación de
evidencias, registro antirrepetición ni persistencia.

Delega estas operaciones al receptor transaccional B17.

Pruebas Django en PostgreSQL 17 temporal:
- petición válida y duplicado;
- autenticación y firma incorrectas;
- rollback y recuperación;
- rechazo de JSON malformado;
- rechazo de ruta inexistente;
- límite de tamaño de peticiones.

Limitaciones:
- El servidor de pruebas escucha solo en localhost.
- No existe integración de red entre dos contenedores.
- No hay registro operacional de claves.
- No hay custodia externa real ni TLS.
- Sin servicio público ni migraciones persistentes.

B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
