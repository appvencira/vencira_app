# I7-A — Contrato de autenticación nativa sin emisor (06/11/2026)

La aceptación I6 en Android físico está limitada al arranque de la APK y a la apertura del acceso Web. No autoriza crear sesiones nativas.

## Auditoría de la implementación existente

- `backend/native_mobile_service/g14_locked_verifier.py` verifica contraseña bajo bloqueo de la fila de usuario y rechaza las cuentas con MFA habilitado; devuelve **metadatos internos** y no tokens.
- `g14_issuance_contract.py` evalúa condiciones booleanas de seguridad, pero sus resultados **no prueban criptográficamente** que una contraseña ni un factor MFA hayan sido verificados por el servidor.
- La app de laboratorio `native_mobile_service` solo puede registrarse con `VENCIRA_ENV=test` y `VENCIRA_NATIVE_SERVICE_CANDIDATE=1`; en producción se rechaza el registro. `VENCIRA_NATIVE_BEARER_ENABLED=False` permanece fijo.
- `clients/flutter/lib/api/native_session_coordinator.dart` es un puerto abstracto con controles locales de credenciales y revocación, pero aún no existe un adaptador nativo HTTP operativo aprobado. No se debe inyectar en `main.dart`.
- La APK ordinaria continúa mostrando `AndroidWebAccessScreen` y el acceso mediante navegador.

## Nuevo gate I7-A

El workflow `.github/workflows/i7a-native-auth-contract.yml` ejecuta pruebas de contrato y del verificador G14 en PostgreSQL 17 **efímero**, y comprueba de forma negativa que no aparecen rutas de emisión, refresh, revocación ni bearer aunque se registre el candidato en test. Prueba además la denegación de registro fuera de test y mantiene el esquema sincronizado.

**No se cambia ninguna ruta de producción, middleware, serializer, modelo, migración ni permisos.** La PR permanecerá draft hasta CI verde.

## Trabajo real pendiente para I7-B

Diseñar e implementar un emisor servidor bajo una transacción de confianza, con validación real de contraseña, MFA TOTP desde estado del servidor y cuarentena de recuperación, resistencia a replay y revocación, auditoría y presupuesto antiabuso; validar emisión y refresh en laboratorio aislado y negativa de accesos indebidos. Solo después crear el adaptador HTTPS Flutter y repetir pruebas de dispositivo físico. Los tests de G14 con `mfa_verified=True` sintético jamás deben servir para autorizar emisión de sesiones de producción.

`I7_NATIVE_ISSUER_AUTHORIZED=NO`
`MFA_RELEASE_AUTHORIZED=NO`
`C_FICHA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
