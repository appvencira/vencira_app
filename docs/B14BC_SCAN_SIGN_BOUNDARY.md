# VENCIRA B14B + B14C

Contrato experimental de escaneo y firma Ed25519 v3.

El circuito utiliza los componentes existentes:
- lectura de cuarentena
- validación SHA-256 y tamaño
- preinspección estructural
- adaptador ClamAV con socket Unix
- firma Ed25519 v3 con key_id firmado

Solo CLEAN con metadatos invariables puede generar
evidencia. INFECTED y ERROR se bloquean.

Las pruebas usan un scanner inyectado de ensayo.
No demuestran un escaneo real mediante clamd.

El código del contrato sigue siendo importable en
el backend de desarrollo. No constituye una
separación operacional de la clave privada.

Pendientes:
1. Servicio real aislado, con permisos mínimos.
2. Custodia externa de clave privada Ed25519.
3. Canal autenticado y protección antirrepetición.
4. Identidad y frescura verificables de ClamAV.
5. Integración con PostgreSQL sin conceder acceso.
6. Pruebas operacionales fail-closed y recuperación.

No utilizar con documentos de clientes.

B14_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
