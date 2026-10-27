# D1.5 — Cierre agrupado A/B/C (CONTROLADO, no ejecutado)

**Estado de entrada:** D1.5a–r con gates automatizados OK, incluido D1.5r rollback; DEV y PostgreSQL persistente permanecen en baseline anterior a migración 0019; MFA backend `VENCIRA_MFA_ENROLLMENT_ENABLED=0`, asistente Flutter `VENCIRA_MFA_UI_ENABLED=false`.

## Bloque A — Seguridad técnica

- Validado: criptografía TOTP, recuperación por códigos, prueba de posesión antes de activar MFA, rate-limit de reautenticación, middleware de sesión, gate D1.5r de downgrade.
- Nuevo `scripts/mfa_release_guard_readonly.sh <commit-sha>`: comprueba sobre **el commit candidato** existencia de módulos MFA y señales estáticas de enforcement en settings, login y desafío. Si falta cualquier parte, sale con error; nunca autoriza lanzamiento. **No prueba semántica ni consulta DB**: exige puerta complementaria runtime `python manage.py mfa_rollback_guard --candidate-enforces-mfa` sobre esquema accesible, solo cuando se haya comprobado explícitamente el código del candidato. Este script no se ha integrado aún en todos los desplegadores antiguos; utilizar exclusivamente flujo dedicado MFA cuando se complete.
- Recuperación total: **no se habilita bypass**. Solo diseño: solicitud firmada por titular, identificación por canal independiente preestablecido, dos revisores distintos, cuenta en cuarentena, revocación completa de sesiones, anotación auditable e información al titular. Falta modelo de caso y tests de abuso/reapertura; no abrir endpoint mientras falten controles.

## Bloque B — Custodia y ensayos

- Ejecutar `scripts/o5_backup_health.sh` y `scripts/o5_restore_drill.sh` con aprobación del responsable y entorno controlado, documentando solamente códigos/resultados, no configuraciones ni secretos. Las pruebas aisladas D1.5r NO acreditan restauración real O5.
- Obtener el anillo MFA Fernet solo de la custodia independiente, no Git ni chat ni backups accesibles desde servidor. Probar en clon aislado con material sintético primero, y de forma operacional con acceso controlado (sin imprimir tokens). Documentar responsables, soporte cifrado, rotación y recuperación; **sin cargar claves en DEV hasta completar autorización**.
- Verificación manual Android y escritorio del QR, ES/CA, abortar/reiniciar alta, interrupción de red y recuperación. No se ha efectuado todavía.

## Bloque C — Publicación (NO AUTORIZADA / NO EJECUTADA)

Secuencia prevista, nunca automática: 1) puerta A/B firmada 2) preflight aislado con commit SHA fijado 3) respaldo O5 fresco verificable + restauración en clon 4) ensayo migraciones 0019–0021 en clon PG17 y rollback de aplicación sin eliminar enforcement 5) autorización explícita de despliegue 6) mantenimiento restringido, aplicación migraciones en DB persistente y despliegue de versiones MFA-compatibles 7) smoke login+MFA con cuentas sintéticas y observabilidad 8) servicio público vuelve a normal con `VENCIRA_MFA_ENROLLMENT_ENABLED=0` y UI oculta 9) autorización específica adicional para activar enrolamiento.

**No ejecutar comandos de migración, deploy ni cambios de flags por este documento.**

## Gate de esta entrega

Aún pendiente: `scripts/validate_o7_o8_preflight.sh` y control estático explícito del script sobre candidato de prueba. Sin cambios de OAuth, Restic, Caddy ni bases persistentes.


## Gate ABC inicial — APROBADO (27/10/2026)

Operador confirma `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_GATE_ABC=0`, `RESULTADO_GUARD_ABC=0`, `MFA_CANDIDATE_STATIC_CHECK=OK`, candidato SHA `242c5f2522e7d8731712528676e647e9139cb1f1`. Log local `/tmp/vencira-o7-o8-preflight.GVNsfN4W.log`. `MFA_RUNTIME_DB_GUARD=PENDING`, `MFA_RELEASE_AUTHORIZED=NO`. Sin despliegue ni migración persistente, OAuth/Restic/Caddy intactos. La anterior salida fallida en CONTAINERS fue corregida por el operador, no persiste en este gate.
