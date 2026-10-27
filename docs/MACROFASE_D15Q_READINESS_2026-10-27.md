# D1.5q — Inventario operativo MFA (pendiente gate)

Se añade el comando **solo lectura** `python manage.py mfa_readiness` para inventariar, sin exposición de secretos:
- Estado del flag de alta de MFA (debe seguir apagado).
- Validez sintáctica del anillo `VENCIRA_MFA_FERNET_KEYS` (nunca imprimir claves ni derivados).
- Presencia de migraciones 0019, 0020 y 0021 aplicadas a la base consultada.
- Recuento de cuentas MFA activas, solo si el esquema existe.
- Línea fija `MFA_RELEASE_AUTHORIZED=NO`: el diagnóstico jamás equivale a autorización de activación.

El comando NO crea claves, NO accede a Google Drive/Restic, NO aplica migraciones, NO cambia flags, NO revoca sesiones y NO altera datos. Se añadieron pruebas de fallo cerrado y protección frente a divulgación de claves. **No ejecutar en entorno persistente hasta verificar y autorizar el plan concreto de revisión**, aunque el comando sea de solo lectura.

## Requisitos para liberar MFA (aún pendientes)
1. Claves Fernet en custodia externa cifrada, recuperación realizada en clon, custodia de al menos dos responsables, ensayo de rotación.
2. Procedimiento operativo autenticado, auditado y con doble aprobación para recuperación sin TOTP ni códigos, sin bypass público.
3. Asegurar que un rollback no restituya autenticación de un solo factor: versión anterior con enforcement preservado o bloqueo de acceso; comprobar en clon.
4. Verificación QR real en Android y escritorio, accesibilidad y ES/CA; pruebas de interrupción y reinicio.
5. IP/proxy rate limit y alertas, backup O5 vigente y prueba de restauración PostgreSQL, revisión de datos personales y RGPD.

El gate para este commit sigue siendo `scripts/validate_o7_o8_preflight.sh` aislado. Sin despliegue ni migración persistente.


## Gate D1.5q — APROBADO (27/10/2026)

Confirmación operador: `LOCALCHECK_HEALTH_PRE=OK`, `CONFIG_COMPOSE=OK`, `I18N_ES_CA=OK`, `BUILD_BACKEND_AISLADO=OK`, `DJANGO_CHECK_MIGRACION_SECA=OK`, `DJANGO_SQLITE_SUITE_COMPLETA=OK`, `PG17_TEMPORAL=OK`, `DJANGO_POSTGRES17_SUITE_COMPLETA=OK`, `FLUTTER_ANALYZE_TEST_BUILD=OK`, `LOCALCHECK_HEALTH_POST=OK`, `RESULTADO_GLOBAL=0`, `RESULTADO_D1_5Q=0`. Log `/tmp/vencira-o7-o8-preflight.2Zd2Z3hK.log`. Sin despliegue ni migración PostgreSQL persistente; sin cambios OAuth/Restic/Caddy. Fases funcionales anteriores no se repiten. Pendientes custodia/restauración de claves, recuperación sin factores, rollback seguro y comprobación visual Android/PC.
