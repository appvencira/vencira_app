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


## Bloque B — Nuevo ensayo O5→clon 0018→0021 (PENDIENTE DE EJECUCIÓN)

Se añade `scripts/rehearse_mfa_0019_0021_o5_clone.sh`: exige root y variable explícita `MFA_O5_CLONE_CONFIRM=RESTORE_ONLY_EPHEMERAL_CLONE`; comprueba rama y base viva en migración 0018; usa bloqueo O5, backup Restic cifrado actual, PostgreSQL17 efímero en red Docker interna, `restic dump` por tubería directa a `pg_restore` sin dump descifrado en disco. Verifica el esquema 0018 restaurado, aplica 0019–0021 exclusivamente al clon, verifica tablas MFA y comprueba que la base persistente sigue en 0018 y con igual contador de migraciones. Elimina contenedor/red efímeros al salir. **No ejecutado aún; contiene datos restaurados reales en la memoria/almacenamiento efímero de contenedor hasta su eliminación: ejecución autorizada únicamente por custodio.** No usa el script antiguo O5 que exigía migración 0014.

**Secuencia**: gate estático del script (revisión de sintaxis), ensayo O5 en clon, revisión QR Android/PC, custodia externa de claves y procedimiento de recuperación administrativa auditado. El bloque C no tiene aprobación para deploy. Si faltan claves MFA o no existe recuperación administrativa segura, mantener flag desactivado incluso tras una eventual migración autorizada.


## Bloque B — Revisión estática aprobada (27/10/2026)

Operador reporta `SINTAXIS_MFA_CLON=0` para `scripts/rehearse_mfa_0019_0021_o5_clone.sh`, y contenedores `vencira_localcheck-api-1`, `-db-1`, `-web_preview-1` todos `healthy`. `RESTAURACION_NO_EJECUTADA=1`, `MIGRACIONES_PERSISTENTES_NO_APLICADAS=1`. Preparación verificada; **el ensayo de restauración O5 todavía no ha sido ejecutado ni aprobado como completado**.


## Verificación previa de script O5→clon — OK (27/10/2026)

Operador informa `SINTAXIS_MFA_CLON=0`, `RESTAURACION_NO_EJECUTADA=1`, `MIGRACIONES_PERSISTENTES_NO_APLICADAS=1`; contenedores `vencira_localcheck-api-1`, `vencira_localcheck-db-1`, `vencira_localcheck-web_preview-1` en estado `healthy`. **No equivale a ensayo O5 restaurado ni autoriza despliegue o activación MFA.** Siguiente paso: ejecutar de forma expresamente controlada el clon efímero, revisar salida y confirmar destrucción de recursos.
