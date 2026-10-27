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
