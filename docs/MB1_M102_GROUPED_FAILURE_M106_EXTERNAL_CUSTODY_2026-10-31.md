# VENCIRA - Bloque agrupado M1-02 y requisitos externos M1-06

Fecha: 31/10/2026. Rama: feature/c-ficha-independent-attachments.

## M1-02 - Nuevas pruebas de fallos fisicos en almacenamiento sintetico

Implementacion: backend/renewal_attachments/test_mb1_partial_io_failclosed.py, commit 67f5de1. Ocho pruebas sobre PrivateQuarantineStore (Fernet), IntakeJournal y clasificador conservador en directorios efimeros privados.

Los casos comprueban: ciphertext truncado; JSON de diario incompleto; hash de diario incongruente con objeto valido; pareja intencion+objeto sin metadatos; error fsync sobre objeto cifrado y limpieza del objeto inacabado; fallo fsync de diario sin asumir confirmacion; diario que aparece bajo UUID equivocado; y objeto sin diario. Los ocho casos deben fallar cerrados, no publicar ni reparar/borrar automaticamente inventarios de recuperacion.

Ejecutor: scripts/validate_mb1_m102_grouped_failclosed.sh, commit d9fa85f. Construye una sola imagen y ejecuta 22 casos en Django sin red: seis contratos de fallo de intake ya existentes, ocho contratos read-only B18L existentes y ocho nuevos de archivos/diario reales de laboratorio. Se reutiliza el PASS previo de SIGKILL PostgreSQL 17 (codigo 137) sin repetirlo.

**Bloque ejecutado: PASS comunicado por el operador el 31/10/2026 (ver evidencia final).**

Comando:

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    bash -n scripts/validate_mb1_m102_grouped_failclosed.sh
    sudo env MB1_M102_GROUPED_LAB=YES bash scripts/validate_mb1_m102_grouped_failclosed.sh
    echo "MB1_M102_GROUP_EXIT_CODE=$?"

Esperado: Ran 22 tests, OK, MB1_M102_GROUP_INTAKE_CONTRACTS=OK, MB1_M102_GROUP_READONLY_RECONCILIATION=OK, MB1_M102_GROUP_PARTIAL_IO_FAIL_CLOSED=OK, MB1_M102_GROUP_NO_AUTOMATIC_DELETE_OR_PUBLISH=OK, MB1_M102_GROUP_DONE=OK, MB1_M102_GROUP_RESULT=0, MB1_M102_GROUP_EXIT_CODE=0.

**Limitaciones M1-02:** una simulacion de archivo parcialmente escrito no equivale a perdida de energia real; faltan commit ambiguo y procedimiento operativo de conciliacion autorizada. No cerrar M1-02 todavia.

## M1-06 - Custodia y recuperacion totalmente externa

Ya se verifico la recuperacion PostgreSQL real cifrada desde Restic/Google Drive en un contenedor temporal del VPS. Esto no equivale a recuperacion si el VPS desaparece. Requisitos que no puede probar un test local:

1. Destino A: paquete cifrado fuera del VPS, con retencion/versionado y recuperacion de la cuenta aunque desaparezca el servidor. Drive puede ser candidato sin implicar inmutabilidad demostrada.
2. Custodio B: material de recuperacion protegido fuera del VPS y de A: password Restic, acceso rclone/OAuth o recuperacion de cuenta, clave de adjuntos, clave de manifiesto y cabeza monotona antirollback. Nunca reutilizar claves MFA, ni subir claves a GitHub, logs o chat.
3. Restaurador C: segundo ordenador sin acceso al VPS original, que desde A+B pueda restaurar y verificar version, huellas y datos, incluso frente a paquete viejo autenticado.
4. Validacion fail-closed: sin B, sin cabeza de confianza, con datos manipulados o ante paquete antiguo se aborta; la destruccion del origen no debe impedir recuperar desde A+B.
5. Aprobacion de custodio, medios, responsabilidades y politicas de rotacion y revocacion por el operador; no se crean ni exportan secretos en este ensayo.

**M1-06 sigue pendiente** hasta acreditacion externa real. Tampoco se marca M1-05 como completo.

## Gates

    MB1_M102_ACTUAL_POWERLOSS=NOT_VERIFIED
    MB1_M102_AMBIGUOUS_COMMIT_RECOVERY=NOT_VERIFIED
    MB1_M102_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED
    MB1_M106_EXTERNAL_CUSTODY=NOT_VERIFIED
    MB1_GLOBAL_FREEZE=NOT_VERIFIED
    MB1_RELEASE_AUTHORIZED=NO
    NO_DEPLOY_NO_LIVE_MIGRATION=1

No instalar, migrar, reiniciar ni tocar O5 o la base persistente DEV.


## Evidencia del operador — 22/22 PASS (31/10/2026)

`Ran 22 tests in 0.037s`, `OK`, `MB1_M102_GROUP_INTAKE_CONTRACTS=OK`, `MB1_M102_GROUP_READONLY_RECONCILIATION=OK`, `MB1_M102_GROUP_PARTIAL_IO_FAIL_CLOSED=OK`, `MB1_M102_GROUP_NO_AUTOMATIC_DELETE_OR_PUBLISH=OK`, `MB1_M102_GROUP_DONE=OK`, `MB1_M102_GROUP_PHASE=DONE`, `MB1_M102_GROUP_RESULT=0`, `MB1_M102_GROUP_EXIT_CODE=0`. Verificados los 6 contratos históricos, 8 clasificaciones B18L y 8 fallos físicos de archivos cifrados/diario de laboratorio. No repetiremos esta batería por mera acumulación de pruebas.

Los límites reportados permanecen: `MB1_M102_ACTUAL_POWERLOSS=NOT_VERIFIED`, `MB1_M102_AMBIGUOUS_COMMIT_RECOVERY=NOT_VERIFIED`, `MB1_M102_OPERATIONAL_RECONCILIATION=NOT_IMPLEMENTED`, `MB1_M106_EXTERNAL_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **M1-02 sigue abierto**. Siguiente hueco crítico: decidir qué ocurre si `create_metadata` confirma la transacción PG17 pero falla la respuesta al proceso de intake; evitar que la limpieza del objeto cifrado destruya datos referenciados por metadata ya confirmada.

## Correccion de perdida de ACK tras commit SQL — NUEVO GATE DE 30 CASOS (31/10)

Tras el PASS del bloque de 22 pruebas se ha identificado un **riesgo de perdida de datos** en la funcion offline `stage_private_attachment`: antes, una excepcion del callback `create_metadata` ejecutaba `discard_quarantine`, aunque el callback pudiera haber confirmado su transaccion SQL y perder unicamente el ACK. Esto podia dejar metadatos PG17 referenciando un archivo cifrado eliminado.

Cambio del flujo en `backend/reminders/attachment_quarantine_intake.py` (commit `05bea57`): despues de escribir el objeto cifrado, **no se asume rollback a partir de una excepcion ni un resultado None**. El objeto se conserva en cuarentena privada y queda pendiente de comprobacion externa de metadata, intencion e integridad. Una excepcion mantiene su tipo; no se autoriza descarga ni publicacion. El objeto anterior no se limpia automaticamente en un error ambiguo. Esta decision puede producir objetos huerfanos; deben clasificarse y revisarse, no eliminarse sin evidencia.

Tests adaptados `backend/reminders/test_mb1_intake_failure_contract.py` (`eadcb5c`) y `backend/reminders/test_attachment_quarantine_intake.py` (`1f6c011`). Se agregan 4 pruebas con Fernet y diario de verdad sobre ficheros temporales, callback de metadata simulado: commit seguido de timeout, error previo al commit, falta de diario y ausencia de ACK (`backend/renewal_attachments/test_mb1_ambiguous_metadata_commit.py`, `99c9114`). **No son una simulacion de commit real de PG17**; falta probar la condicion con PG17 efimero y confirmar mecanismo de conciliacion operativo.

El script `scripts/validate_mb1_m102_grouped_failclosed.sh` (commit `1299887`) ahora agrupa 6+4+8+8+4 = **30 tests**, incluido el retest de los comportamientos modificados. No se han ejecutado aun desde el VPS, asi que **el PASS de 22 pruebas anterior no se extrapola a este codigo corregido**.

Comando unico:

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    bash -n scripts/validate_mb1_m102_grouped_failclosed.sh
    sudo env MB1_M102_GROUPED_LAB=YES bash scripts/validate_mb1_m102_grouped_failclosed.sh
    echo "MB1_M102_GROUP_EXIT_CODE=$?"

Esperado: `Ran 30 tests`, `OK`, `MB1_M102_AMBIGUOUS_COMMIT_CIPHERTEXT_PRESERVED=OK`, `MB1_M102_GROUP_EXPECTED_TESTS=30`, `MB1_M102_GROUP_RESULT=0`, `MB1_M102_GROUP_EXIT_CODE=0`. El ensayador solo usa Docker sin red, datos de prueba y bases SQLite de tests; no modifica DEV ni O5.

**Limites M1-02:** rollback/ACK real en PG17 aun sin validar; caida real de energia no ejecutada; conciliacion operativa de objetos pendientes no implantada. M1-02 y M1-06 siguen abiertos y `MB1_RELEASE_AUTHORIZED=NO`.
