# I2-E — Integración de seguridad nativa exclusivamente como laboratorios

**Fecha:** 2026-11-06

## Procedencia e integración
La rama parte de `main` en `32b174bc7855839ce1a6a189d392a460bc014a86`. Se han importado sin reescribir los 65 archivos versionados de `backend/native_mobile_service/` (45) y `backend/native_sessions_lab/` (20) desde `feature/m3-android-local-notifications` en `2b770626baa98deccbcde1c79e69679447d9a304`, con sus modelos, migraciones y tests. Esto **no** autoriza despliegue ni migración de las tablas.

El registro de cada app ya está condicionado en `backend/config/settings.py`: ambas precisan `VENCIRA_ENV=test` y su variable `VENCIRA_NATIVE_SERVICE_CANDIDATE=1` o `VENCIRA_NATIVE_SESSION_LAB=1`. Ninguna se registra por defecto en DEV/producción; `VENCIRA_NATIVE_BEARER_ENABLED=False` sigue en el flujo normal; no se crean rutas de emisión operativa ni se modifican servicios del VPS.

## Riesgos y alcance de evidencia
Los ensayos G14 de evaluación MFA no equivalen a un emisor seguro de credenciales reales. La evidencia booleana proporcionada por el llamante no sirve como prueba de verificación MFA; falta un flujo completo y autorizado de emisión, renovación y rotación de credenciales. Conservar la implementación de laboratorio en `main` no la activa.

`native_sessions_lab` es un harness sintético aislado y no un modo de inicio de sesión autorizado para clientes.

## Pruebas de CI
`.github/workflows/i2e-native-security-labs.yml` valida de modo separado:
1. Arranque de Django normal sin apps experimentales y comprobación de modelos.
2. Rechazo de ambas apps en producción por `ImproperlyConfigured`.
3. Ensayos de sesión nativa, con `VENCIRA_NATIVE_SESSION_LAB=1`, SQLite efímera.
4. Ensayos G4/G14 candidatos con `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`, SQLite efímera.
5. Variables de autorización de release en NO.

**No declarar PASS hasta recibir resultado CI del HEAD exacto; PR en borrador.** No ejecutar migraciones contra bases persistentes. Pruebas sobre PG17 y Android de laboratorio deben mantenerse como gates independientes, con dispositivos y fixtures aislados.

`MFA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
