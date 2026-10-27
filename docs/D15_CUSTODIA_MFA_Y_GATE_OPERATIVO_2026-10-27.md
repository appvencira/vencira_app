# D1.5 — Custodia MFA y puertas operativas (diseño de implementación, NO EJECUTADO)

Fecha: 2026-10-27. Fuente: HANDOFF_MACROFASE_D15_ABC_2026-10-27.md y whitepaper §12. Esta especificación no autoriza despliegue, migraciones ni claves reales en DEV.

## Evidencia ya validada — no repetir
Gate ABC 0; O5 snapshot cifrado restaurado en PG17 temporal con esquema 0018; migraciones 0019–0021 exclusivamente en clon; BD persistente intacta. Los ensayos anteriores prueban restauración de base, NO custodia/recuperación de claves.

## Custodia Fernet: contrato
- Secreto operacional: anillo VENCIRA_MFA_FERNET_KEYS; orden: primera clave cifra, anteriores solo descifran; nunca derivar de DJANGO_SECRET_KEY.
- No almacenar claves en Git, Drive sin cifrado independiente, logs, chat, ficheros públicos, imágenes Docker ni backups legibles con credenciales del servidor.
- Dos copias cifradas con custodia independiente del VPS y del acceso a Restic/O5. Registrar exclusivamente custodios, medio, fecha, versión/huella no reversible y procedimiento de acceso dual; no registrar claves ni URL privada.
- Verificar material con validador local sin imprimir valores, comprobar integridad de la copia y ensayar descifrado de datos **sintéticos** en clon aislado. Un segundo ensayo operacional solo con autorización y custodia presencial; no generar salida con secretos.
- Rotación: añadir nueva clave al principio; comprobar descifrado antiguo; re-cifrar progresivamente; retirar claves antiguas solo después de verificar que no queda ciphertext dependiente y que backups históricos conservan un procedimiento de recuperación de sus claves.
- Fallo de material o custodia: fail-closed. La pérdida del anillo no se corrige restaurando solo O5.

## Recuperación total sin TOTP ni códigos
- No crear bypass público, ni rebajar a password-only, ni permitir que un solo operador reactive MFA.
- Modelo administrativo de caso pendiente: solicitud comprobable por titular, canal externo preestablecido, doble revisión por personas distintas, enfriamiento/cuarentena, registro de motivos y pruebas sin adjuntar documentos sensibles sin aprobación RGPD, aviso independiente al titular, revocación de sesiones y tokens, invalidación de factores antiguos y alta MFA nueva antes de restaurar acceso pleno.
- Cubrir con tests: solicitante ajeno, reuso de aprobación, mismo aprobador dos veces, carrera entre cierre y reapertura, expiración, replay, accesos multi-tenant, indisponibilidad de correo y reversión.
- No habilitar endpoint de recuperación hasta tener validación operativa y de abuso.

## Reversión y publicación
- El script mfa_release_guard_readonly.sh es *solo estático*: inspecciona presencia de símbolos; no certifica enforcement runtime.
- mfa_rollback_guard comprueba tabla y cuentas activas cuando el esquema MFA está instalado. Antes de migrar 0019–0021, MFA_SCHEMA_NOT_READY es esperado; no interpretarlo como garantía de publicación.
- Todo nuevo despliegue/rollback que pueda reemplazar API/auth debe consultar el candidato inmutable, validar ejecución real y estado DB; ante error o estado desconocido BLOQUEAR. Integrar como puerta obligatoria en el procedimiento dedicado. No confiar en scripts antiguos como ruta MFA.
- C: backup fresco, clon, migración persistente solo tras aprobación explícita, smoke con cuentas ficticias, flags apagados; autorización **separada** para activar enrolamiento.

## Hallazgos de revisión de scripts (pendientes de corregir)
- rehearse_mfa_0019_0021_o5_clone.sh imprime BD_PERSISTENTE_INTACTA=1 desde EXIT incluso si falló antes del chequeo LIVE_POST. Cambiar por estado verificado, con valor DESCONOCIDO si no se pudo verificar.
- La limpieza de DB/red usa '|| true' y puede fallar sin notificar. Reportar CLEANUP_DB/CLEANUP_NET y bloquear cierre OK si no se destruyen; no imprimir secretos/log sensible.
- pubspec.lock existe localmente sin seguimiento; decidir versionado en una modificación separada tras revisar compatibilidad de dependencias, sin eliminarlo unilateralmente.

## Puertas pendientes
A: recuperación administrativa + protección anti-downgrade integrada.
B: custodia externa recuperable y validación manual QR/ES/CA Android y PC.
C: no autorizado. PostgreSQL persistente en 0018 según última evidencia. MFA desactivado.

## Restricciones
No tocar OAuth, Restic, Caddy, DB persistente ni flags MFA; usar datos sintéticos en DEV. Conservar evidencias existentes y no repetir ensayo O5 ya aprobado.

## Evidencia de ejecución — 27/10/2026
Operador ejecutó `sudo bash scripts/validate_mfa_custody_synthetic.sh` en commit `6854f5aef7ef16169785671bae61c6e89a005980`. Cuatro tests Django sobre SQLite temporal: OK; `MFA_CUSTODIA_CRIPTOGRAFICA_SINTETICA=OK`; `RESULTADO_D15_S1=0`; `SIN_RESTAURACION_O5=1`; `SIN_MIGRACIONES_PERSISTENTES=1`. El primer intento sin sudo terminó en denegación de acceso al socket Docker; segundo intento con sudo correcto. No equivale a custodia operativa independiente ni a recuperación administrativa. MFA_RELEASE_AUTHORIZED=NO.

## Evidencia D1.5-S1: política de recuperación (27/10/2026)
Operador informa ejecución aislada Django SQLite de `reminders.test_mfa_admin_recovery_policy` y `reminders.test_mfa_rollback_guard`: **8 tests OK**, `RESULTADO_D15_RECOVERY=0`, commit `8f386e171eb1435cd52ad19c6d3563ce17ca04b4`, `NO_DEPLOY_NO_MIGRACION=1`. Pruebas de política de doble revisión y rollback sobre BD temporal. **No** acreditan caso persistente, auditoría, revocación de sesiones ni recuperación efectiva; MFA sigue desactivado, publicación NO autorizada.

## Evidencia D1.5-S1B — 27/10/2026
Operador informa gate aislado sobre commit `1f589a49ea9c6457781a8abb69b93d71132df61d`: `RESULTADO_D15_S1B=0`, `NO_DEPLOY_NO_MIGRACION_PERSISTENTE=1`, Django `check`/`makemigrations --check --dry-run` y pruebas sobre SQLite temporal completadas sin error (salida final `OK`). Modelos de solicitud, aprobación única por revisor y evento de auditoría, migración 0022 preparada pero NO aplicada a DEV. Pendientes: enforcement transaccional, autorización de revisores, evidencias independientes, auditoría protegida, revocación de sesiones y factores, custodia externa y gate de despliegue. No considerar recuperación operativa disponible. MFA_RELEASE_AUTHORIZED=NO.

## Revalidación D1.5-S1C — 27/10/2026
Operador confirmó `RESULTADO_D15_S1C=0`, commit `d22a0b2ea6b4c586df1885fa1fee682246bf9906`, pruebas aisladas de `reminders.test_mfa_admin_recovery_service` OK, `NO_DEPLOY_NO_MIGRACION=1`. El fallo anterior de dos fixtures se corrigió ajustando la hora de referencia después del `auto_now_add`, sin modificar validaciones de producción. No prueba concurrencia en PG17 ni habilita recuperación.

**Hallazgo pendiente de diseño**: las aprobaciones del servicio tienen vigencia 1h, mientras la cuarentena mínima de la política es 24h; verificar secuencia de aprobaciones posterior a cuarentena, expiraciones y criterio de revisión dual. `is_staff` no es suficiente como autorización operativa de custodio independiente. No invocar restablecimiento hasta cerrar el protocolo y pruebas.

## Evidencia D1.5-S1D — 27/10/2026
Operador confirmó `RESULTADO_D15_S1D=0`, commit `8dfe52213917b04dc94d97c5cb68d0fa6a915040`, pruebas aisladas del servicio de revisión administrativa OK, `NO_DEPLOY_NO_MIGRACION=1`. La fixture de cuarentena se alineó con `created_at` persistido; se mantiene duración mínima estricta de 24 horas. Pendientes: concurrencia real PG17, autorización fiable de revisores (no aceptar lista arbitraria desde capa HTTP), idempotencia/colisiones, revocación y custodia operativa externa. MFA no autorizado.

## Evidencia D1.5-S1E — 27/10/2026
Operador confirmó `RESULTADO_D15_S1E=0`, commit `22f3cc0e66b24b93d514685f9c318f25d47e90c5`, suite SQLite aislada OK, `SIN_DESPLIEGUE_NI_MIGRACION=1`. El servicio ya no acepta roster por argumento: lo consulta desde settings del servidor y deniega por defecto si faltan dos revisores; las pruebas usan override_settings con identidades ficticias. **No equivale a autorización operativa ni valida origen seguro de esa configuración.** Pendientes: PG17 temporal bajo concurrencia, definición de custodios independientes, auditoría resistente a manipulación, custodia externa, revocación y despliegue protegido. MFA_RELEASE_AUTHORIZED=NO.

## Gate integral S1 — 27/10/2026
Operador reporta `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log privado en servidor (no compartir salvo fragmentos depurados). **Solo cierra validación del código cubierto por el gate**; no valida custodia operativa, revocación de sesiones/factores ni enforcement runtime en despliegue real. `MFA_RELEASE_AUTHORIZED=NO`. Evitar repetir el gate salvo cambios relevantes.

## Revalidación integral S1 con revocación de sesiones — 27/10/2026
Operador confirmó gate aislado posterior a la migración preparada 0023 y pruebas de session_epoch: `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log privado del gate disponible solo en el servidor. No se ha autorizado publicación: `MFA_RELEASE_AUTHORIZED=NO`. **Solo** demuestra el comportamiento cubierto por el gate; no prueba sustitución de factores, custodia Fernet independiente ni enforcement runtime en candidato desplegado. No repetir este gate sin cambios relevantes.

## Revalidación integral MFA tras corrección de ACK — 27/10/2026
Operador confirma `S1_SQLITE_SECURITY=OK`, `PG17_EPHEMERAL=OK`, `S1_POSTGRES_REVIEW_AND_RACE=OK`, `S1_STATIC_CANDIDATE_GUARD=OK`, `CLEANUP=OK`, `S1_PG17_GATE_RESULT=0` y `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Se corrigió falso positivo por `/api/v1/me/mfa/recovery/ack/` (acuse de custodia de códigos, no reset administrativo) y el session_epoch tras alta. Log privado /tmp/vencira-s1-pg17.ouuXeOAS.log. No equivale a custodia externa real ni autorización de activar MFA: `MFA_RELEASE_AUTHORIZED=NO`. No repetir este gate salvo cambios relevantes.
