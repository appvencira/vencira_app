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
