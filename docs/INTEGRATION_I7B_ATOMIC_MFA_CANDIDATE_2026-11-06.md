# I7-B — Composición MFA verificada y emisión atómica (solo laboratorio)

Fecha: 2026-11-06

## Modificación

En `backend/native_mobile_service/g14_e2_atomic_mfa_candidate.py` se ha añadido una composición **exclusivamente de prueba** que hace, sobre PostgreSQL17 temporal:

1. Admisión con presupuesto antiabuso y disponibilidad de auditoría obligatorios.
2. Bloqueo `SELECT FOR UPDATE` del usuario con comprobación de cuenta activa.
3. Verificación de contraseña real contra Django y código TOTP contra estado del servidor, con consumo antirrepetición bajo el mismo bloqueo y transacción.
4. Lectura de epoch MFA, generación de revocación, emisión del par opaco de laboratorio y creación de evento de auditoría en la **misma transacción**.
5. Si la auditoría de éxito falla, se revierte **también** el consumo MFA y la sesión. Si falla el código TOTP, se conserva el contador de intentos incorrectos y se registra la denegación para que no se pierda el bloqueo antiabuso.
6. El código TOTP usado una vez no puede emitir otra sesión. La rotación refresh previa conserva la revocación ante replay.

`test_i7b_atomic_mfa_candidate.py` aporta regresiones de contraseña errónea, MFA erróneo, repetición del código, cuarentena administrativa, clave inválida, auditoría duplicada con rollback y rotación con replay.

## Restricción fundamental

Este es **un candidato de composición**, NO un emisor de producción ni una API. Las claves TOTP y `timestamp` proceden de argumentos del llamador en un laboratorio aislado; esa confianza no es aceptable para producción. Un servicio real debe usar la custodia Fernet y el reloj exclusivamente del servidor, y un protocolo de reto MFA validado end-to-end. No existen rutas nuevas, adaptador HTTP Flutter, almacenamiento de secretos operativo, despliegue ni autorización de MFA.

Una prueba PG17 verde demuestra propiedades limitadas de atomicidad y bloqueo, no una autorización de seguridad externa. No mover el método a un view, middleware ni botón de producción.

**Workflow:** `.github/workflows/i7b-atomic-mfa-candidate.yml`; ejecutar con `VENCIRA_NATIVE_SERVICE_CANDIDATE=1` únicamente en PostgreSQL17 **desechable**, junto con pruebas históricas G14 y de ausencia de rutas de emisión.

`I7B_PRODUCTION_ISSUER=NO`
`MFA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

## Resultado confirmado — 06/11/2026

PR #31 fusionada por squash a `main` (`d29c2bfdbb94254d5ed208739388f29c5c7095d3`). En el HEAD validado `19ae61bb29aa33077d181372c8602b1257a45afd` los **7 workflows** resultaron `success`: I7B PostgreSQL17, I7A, I2E, I2B2, I3, I4 e I5 (incluida APK debug). El primer test incorrecto asumía que una clave Fernet inválida provocaría una excepción; se corrigió para exigir **denegación uniforme, sin sesión ni consumo de MFA**, que es la salida real del verificador. La nueva ejecución fue correcta.

Esto autoriza **integrar el código de laboratorio**, no publicar, migrar bases persistentes ni conceder sesiones reales. `I7B_PRODUCTION_ISSUER=NO`.
