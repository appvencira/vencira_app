# D1.5r — Ensayo aislado de recuperación criptográfica (gate pendiente)

La primera entrega de D1.5r añade `backend/reminders/test_mfa_disaster_recovery.py`: ensaya preparación, TOTP, entrega de códigos, demostración de posesión, activación, recuperación del secreto desde ciphertext + clave externa simulada y recifrado con clave nueva. Comprueba que la clave retirada ya no descifra tras la rotación. También prueba que un ciphertext con clave desconocida falla cerrado. Solo utiliza usuarios y claves sintéticas en DB de pruebas efímera (SQLite y PostgreSQL17); NO contacta servicios externos ni consulta/restaura datos reales.

## Restricciones imprescindibles

- **No confundir prueba sintética con restauración operacional.** Para certificar recuperación real hará falta prueba offline sobre clon desde respaldo O5, recuperar el anillo Fernet con la custodia independiente, y evidenciar descifrado y acceso MFA sin divulgar secretos.
- **Recuperación de acceso sin factores: pendiente, NO habilitada.** Diseñar doble aprobación, verificación fuera de banda, auditoría inmutable, bloqueo temporal e invalidación de sesiones antes de desarrollar endpoint administrativo. Nunca bypass público por contraseña sola.
- **Rollback protegido: pendiente de ensayo.** Si hay cuentas `UserMfaState.enabled=True`, una versión sin middleware/flujo MFA sería un downgrade inseguro. Política operativa obligatoria: bloquear despliegue de versiones previas a MFA si existe al menos una cuenta activa, salvo modo mantenimiento bloqueando todos los accesos; no permitir que el rollback desactive MFA.
- **Claves:** custodia offline separada del servidor, nunca subir a Git, chats, logs o backups legibles. Doble copia cifrada independiente y ensayo de recuperación solo con responsables autorizados.
- **Estado:** feature flags de alta y UI apagados. Sin migraciones persistentes 0019–0021 ni despliegue.
- **Gate:** `scripts/validate_o7_o8_preflight.sh`, completo y sin efectos sobre DEV.

La prueba criptográfica aislada no autoriza la activación pública de MFA.


## Gate primera entrega D1.5r — APROBADO (27/10/2026)

Operador confirma `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5R=0`. Log `/tmp/vencira-o7-o8-preflight.g3r99w5r.log`. No desplegado ni migrada BD persistente, OAuth/Restic/Caddy intactos. Esta aprobación solo cubre ensayo criptográfico aislado; no certifica restauración operacional O5 ni rollback protegido ni recuperación administrativa.


## Segundo bloque D1.5r — Guardia de reversión (PENDIENTE DE GATE)

Se añaden `backend/reminders/management/commands/mfa_rollback_guard.py` y `backend/reminders/test_mfa_rollback_guard.py`. El comando lee exclusivamente el esquema y la presencia de cuentas MFA activas. **Rechaza** candidatos que declaren ausencia de enforcement cuando existe al menos una cuenta MFA activa; también rechaza si no puede verificar el estado o faltan migraciones. `python manage.py mfa_rollback_guard --candidate-lacks-mfa` es una comprobación de solo lectura que devuelve error y salida no sensible ante un downgrade peligroso. `--candidate-enforces-mfa` exige evidencia independiente de que el artefacto candidato incluye middleware y flujo MFA; **el parámetro por sí solo no verifica binarios ni integra todavía el gate en el proceso de despliegue**. No permite bypass, no desactiva MFA ni accede a secretos.

La recuperación de cuentas que perdieron todos sus factores continúa **SIN implementación de endpoint ni procedimiento automatizado**. Diseño previo obligatorio: identidad fuera de banda comprobada por dos personas autorizadas, evidencia en expediente auditado, cuarentena de cuenta, revocación de sesiones, invalidación de códigos y secreto antiguos, notificación por canal preexistente y ventana de seguridad antes de registrar un nuevo factor. Evitar recuperar solo con contraseña o correo sin segunda prueba de identidad. El procedimiento debe aprobarse antes de programar acciones sobre cuentas reales.

Este segundo bloque está pendiente del gate O7/O8 aislado; no desplegar ni migrar la base persistente.
