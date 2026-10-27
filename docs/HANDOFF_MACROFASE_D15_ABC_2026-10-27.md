# VENCIRA — HANDOFF D1.5 / Cierre A-B-C — 27 octubre 2026

## Lectura rápida para nuevo chat
Proyecto VENCIRA, rama privada `appvencira/vencira_app` → `integration/local-e2e-prep`; ruta Ubuntu `/home/vencira/vencira-localcheck`. Django 5/PostgreSQL17/Flutter Web, dominio DEV `dev.vencira.es`. Objetivo: terminar MFA D1.5 con seguridad; **NO CRM**, no datos personales reales en pruebas. El usuario prioriza bloques grandes, diseño premium móvil, documentación y **no repetir gates o fases superados**.

**Estado incontrovertible a 27/10**: MFA D1.5a–r desarrollado con gates aislados exitosos; segundo bloque D1.5r rollback también OK. Gate integrado ABC `RESULTADO_GATE_ABC=0`, `RESULTADO_GUARD_ABC=0`, SHA de candidato entonces `242c5f2522e7d8731712528676e647e9139cb1f1`; `MFA_RUNTIME_DB_GUARD=PENDING` y `MFA_RELEASE_AUTHORIZED=NO`. El ensayo real O5 restaurando backup PostgreSQL 0018 a PG17 efímero y migrando 0019–0021 **ha pasado** (`RESULTADO_BLOQUE_B_CLON=0`, `LIVE_UNCHANGED=OK`), log local privado `/tmp/vencira-mfa-rehearsal.t8jOBFRC.log`. **No repetir este ensayo.** La BD persistente continúa en **0018**, sin despliegue MFA; DEV api/db/web_preview healthy. OAuth, Restic, Caddy intactos. Flutter asistente MFA oculto por flag de compilación `VENCIRA_MFA_UI_ENABLED=false`; API alta apagada `VENCIRA_MFA_ENROLLMENT_ENABLED=0`. No hay claves Fernet MFA operativas acreditadas en custodia, ni activación permitida.

## Completado / no repetir
- D1.5a–j: TOTP, cifrado Fernet con keyring independiente, recovery PBKDF2, tablas `UserMfaState` y `UserMfaRecoveryCode`, migraciones `0019_user_mfa_state`, `0020_mfa_attempt_limits`, `0021_mfa_prepared_at`; rate-limit de factores, middleware `RequireMfaSessionMiddleware`, login desafío segundo factor, CSRF, formularios ES/CA, fail-closed, seguridad y ensayos.
- D1.5k–m: API `/api/v1/me/mfa/setup/start/`, `setup/confirm/`, `recovery/ack/`; preparar contraseña → TOTP → entregar 10 códigos solo una vez (hashes en DB) → demostrar posesión de un código antes de habilitar MFA. Si se pierde entrega antes de ACK, se puede reiniciar con contraseña y rotar provisional. Tests SQLite+PG17 OK.
- D1.5n–p: Flutter `clients/flutter/lib/ui/mfa_setup_screen.dart`, API `clients/flutter/lib/api/vencira_api.dart`, Ajustes→Seguridad, clave manual, QR `qr_flutter` local sin proveedor remoto, ES/CA, lista de códigos, prueba de custodia. Gate Flutter analyze/test/build OK; **no revisión manual Android y PC**.
- D1.5o: reautenticación de alta bajo bucket compartido 5 fallos/15min/bloqueo 15min.
- D1.5q: `python manage.py mfa_readiness` solo lectura; no autoriza publicación.
- D1.5r: ensayo de restauración y rotación de claves sintéticas, `python manage.py mfa_rollback_guard` contra downgrade cuando existen MFA activas (comprobación DB), script `scripts/mfa_release_guard_readonly.sh <commit>` inspección estática del candidato, ambas pruebas exitosas; **el script aún NO está integrado obligatoriamente en todos los desplegadores y no equivale a comprobación semántica del artefacto**.
- A/B/C documentación `docs/MACROFASE_D15_CIERRE_ABC_2026-10-27.md` y otros `docs/MACROFASE_D15*.md`. Gate O7/O8 y guard estático completados.
- Bloque B O5 real: `scripts/rehearse_mfa_0019_0021_o5_clone.sh` restauración temporal completa OK. Snapshot Restic probado; no dump descifrado en disco anfitrión y contenedores temporales eliminados según diseño. No significa que Fernet real se haya restaurado.

## Faltante imprescindible antes de cerrar D1.5
**Bloque A**: integrar guard de rollback en el procedimiento REAL de deploy/reversión (bloqueo obligatorio de versiones sin middleware MFA; comprobar características del candidato y DB real). Diseñar, implementar y probar procedimiento de recuperación cuando se pierden TOTP + todos los recovery codes: identificación independiente robusta, doble aprobación, auditoría, revocación de sesiones, rotación/invalidez de factores; **sin bypass público ni modo contraseña sola**. Aún NO existe endpoint administrativo autorizado.
**Bloque B**: custodia externa segura del anillo Fernet, dos copias independientes cifradas y ensayo de recuperación criptográfica efectivo sobre clon controlado sin pegar secretos en chat/log/Git; no es lo mismo que el ensayo sintético. Validar QR/UX real en Android y PC, es/ca, interrupciones, reinicios, accesibilidad. Revisar rate limit IP/proxy.
**Bloque C**: nunca ejecutar despliegue sin cierre A/B y autorización explícita nueva. Preparar backup O5 reciente, versión candidata fija, prueba rollback, migraciones 0019–0021 persistentes exclusivamente tras autorización, deploy compatible con MFA y flags apagados, smoke y observabilidad. Para activar enrolamiento será necesaria una segunda autorización separada. No degradar la seguridad de cuentas MFA activas.

## Precauciones
- **No volver a pedir el log del ensayo O5 ni repetirlo.** Ya registrado `RESULTADO_BLOQUE_B_CLON=0`.
- **No revelar ni pedir claves/contraseñas** en chat. Nunca pegar salida de comandos con secretos. Github solo código, documentación y test sintético.
- No tocar OAuth/Caddy/Restic ni migrar DB persistente hasta que usuario apruebe bloque concreto. `MFA_RELEASE_AUTHORIZED=NO`.
- Trabajo directamente en GitHub mediante conector cuenta appvencira. Si se implementa código nuevo, preparar un gate aislado único, guardar resultados en docs, sin revalidar fases antiguas por separado.
- Antes de ejecutar comandos de clon/restauración, revisar que estén acotados a recursos efímeros y ofrezcan salida sin secretos.

## Próxima acción exacta para nuevo chat
Comenzar por **custodia de claves Fernet y recuperación administrativa segura**; revisar la implementación actual y crear entregable verificable con pruebas sintéticas, SIN introducir claves reales ni modificar cuentas. Integrar guard en flujo de despliegue dedicado, manteniendo el despliegue deshabilitado por defecto. Una vez validados controles A/B, proponer comprobación visual Android/PC y solicitar autorización de publicación C. **Nada de repetir O5 0018→0021.**

## Evidencias clave
- Gates D1.5a–r superados, `RESULTADO_D1_5R_ROLLBACK=0`.
- ABC `RESULTADO_GATE_ABC=0`, `RESULTADO_GUARD_ABC=0`; log `/tmp/vencira-o7-o8-preflight.GVNsfN4W.log`.
- O5 clon: `LIVE_0018_READONLY=OK`, `O5_SNAPSHOT_READABLE=OK`, `PG17_TEMPORAL=OK`, `O5_RESTORE_0018=OK`, `MFA_MIGRATION_CLONE=OK`, `LIVE_UNCHANGED=OK`, `RESULTADO_CLON_MFA=0`; log `/tmp/vencira-mfa-rehearsal.t8jOBFRC.log`.
