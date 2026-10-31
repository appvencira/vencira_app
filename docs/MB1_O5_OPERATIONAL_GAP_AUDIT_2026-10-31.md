# VENCIRA - Auditoria de brechas O5 para cerrar MB1 (31/10/2026)

Estado: revision estatica de codigo versionado en feature/c-ficha-independent-attachments. No se han consultado credenciales, archivos remotos ni servicios vivos.

## O5 existente segun scripts versionados

- scripts/o5_backup_to_drive.sh: captura PostgreSQL mediante pg_dump -Fc, canaliza hacia restic cifrado sobre rclone/Google Drive. No incorpora objetos cifrados, diarios ni recibos anti-rollback.
- scripts/o5_scheduled_backup.sh: invoca la copia O5 instalada en /usr/local/libexec y registra ultimo exito o fallo local en /var/lib/vencira-o5.
- scripts/o5_backup_health.sh: comprueba frescura de marcador local (36 horas), no restaurabilidad efectiva ni custodia externa.
- scripts/o5_restore_drill.sh: extrae snapshot PostgreSQL etiquetado, restaura en PG17 temporal sin red y exige que la ultima migracion de reminders sea exactamente 0014_renewal_outcomes. Este pin puede haber quedado anticuado respecto de DEV actual; verificar con SELECT read-only antes de concluir nada sobre el entorno.
- Configuracion O5: la contrasena restic y credenciales rclone se encuentran previstas en ficheros root 0600 bajo /etc/vencira-backup. Estar fuera de Git NO acredita custodia independiente del VPS.

## Bloqueos operativos comprobables

1. La copia diaria O5 que figura en Git es PG-only, no captura el conjunto PG17 + Fernet + IntakeJournal del laboratorio. En DEV no existen adjuntos activos, segun inventario previo; evitar inventar un volumen de objetos operativo.
2. La prueba de anti-rollback fisica y de restauracion de dos generaciones fue PASS en laboratorio (MB1_ANTIROLLBACK_E2E_EXIT_CODE=0), pero O5 no impone esa comprobacion antes del pg_restore.
3. Para detectar un paquete viejo autentico se requiere una cabeza de confianza independiente con avance monotono e integridad protegida; el experimento solo simulo esa cabeza dentro del host.
4. El pin fijo a la migracion 0014 en o5_restore_drill.sh puede producir fallos falsos en restauraciones correctas cuando evoluciona el esquema. No sustituirlo a ciegas por 0018: el contrato de compatibilidad se debe definir por identidad y contenido real de la copia.
5. O5 actualmente da continuidad de PostgreSQL; NO detener timers, cambiar secretos, reemplazar script O5 ni ejecutar migraciones mientras persistan estos bloqueos.

## Orden de cierre acelerado

- Ejecutar una unica auditoria de solo lectura del esquema PG17 DEV frente al pin de O5 y de los marcadores locales de exito; la salida no contendra datos ni secretos.
- Elaborar contrato del backup integral futuro con catalogo exacto de recursos, permisos reales de escritor y punto de captura.
- Custodiar por un tercero/medio independiente los secretos y el recibo monotono, con separacion del rol emisor y del rol restaurador; probar restauracion y rechazo de copia obsoleta en segundo host.
- Conservar M1-04, M1-05 y M1-06 abiertos hasta demostrar exclusiones de escritor, respaldo integral y custodia operativa.

MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_OPERATIONAL_BACKUP_INTEGRATION=NOT_VERIFIED
MB1_EXTERNAL_HEAD_CUSTODY=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1


## Una sola auditoria O5 de lectura — PENDIENTE EN VPS

Se ha publicado `scripts/audit_mb1_o5_restore_contract_readonly.sh` (`50d809d`, correccion de SQL heredoc `781a1b1`). Solo consulta en lectura `django_migrations` de `vencira_localcheck-db-1` tras verificar la etiqueta del proyecto; contrasta con el pin estatico `o5_restore_drill.sh`, comprueba la marca local de exito sin imprimir epoch y declara el alcance PG-only de O5 a partir del codigo. No lee archivos de credenciales root, no llama al repositorio remoto, no modifica DB ni detiene temporizadores.

Ejecutar una sola vez:

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    bash -n scripts/audit_mb1_o5_restore_contract_readonly.sh
    sudo env MB1_O5_READONLY_AUDIT=YES bash scripts/audit_mb1_o5_restore_contract_readonly.sh
    echo "MB1_O5_READONLY_EXIT_CODE=$?"

Interpretar `MB1_O5_RESTORE_PIN_MATCHES_LIVE=NO` como diferencia entre la referencia estatica y la migracion DEV leida, no como prueba de fallo de una restauracion remota. El resultado de la consulta no garantiza estado, integridad ni custodia de Drive. Pendiente ejecucion del operador.


## Evidencia del operador — auditoría O5 read-only PASS (31/10/2026)

`MB1_O5_LIVE_SCHEMA_QUERY=OK`, `MB1_O5_RESTORE_STATIC_PIN=FOUND`, `MB1_O5_RESTORE_PIN_MATCHES_LIVE=NO`, `MB1_O5_BACKUP_SCOPE=POSTGRESQL_ONLY_IN_VERSIONED_SOURCE`, `MB1_O5_OBJECT_JOURNAL_CAPTURE=NOT_IN_VERSIONED_O5`, `MB1_O5_ANTIROLLBACK_PREFLIGHT=NOT_IN_VERSIONED_O5`, `MB1_O5_SUCCESS_MARKER=RECENT`, `MB1_O5_READONLY_AUDIT_RESULT=0`, `MB1_O5_READONLY_EXIT_CODE=0`. No se imprimió ni registró aquí el nombre de la migración activa; solo su desacuerdo con el pin 0014. El marcador de éxito reciente es local y NO valida la restauración remota. El operador confirma `MB1_O5_REMOTE_RESTORABILITY=NOT_VERIFIED_BY_THIS_AUDIT`, `MB1_O5_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Acción propuesta:** eliminar únicamente la comparación del *máximo* nombre de migración en el restaurador O5 versionado y comprobar la presencia de una migración base requerida, con las tablas esenciales y tests positivos/negativos. El cambio no debe instalarse automáticamente ni alterar el backup programado. Validar antes de activar.


## Corrección candidata del verificador O5 (fuentes únicamente, SIN DESPLEGAR)

El desacuerdo `MB1_O5_RESTORE_PIN_MATCHES_LIVE=NO` confirmado por operador motivó sustituir la comparación del nombre de **última** migración con `0014_renewal_outcomes`. En la fuente de `scripts/o5_restore_drill.sh` (commit `82e1fa0`) se recupera en lectura el inventario de migraciones reminders y tablas del **PostgreSQL restaurado temporal**, y se exige, mediante `scripts/o5_restore_schema_contract.py` (`c249f43`), la presencia de `0001_initial`, `0014_renewal_outcomes` y las tablas `django_migrations`, `reminders_workspace`, `reminders_renewal`. Permite versiones posteriores legítimas pero **rechaza inventarios incompletos, duplicados o inválidos**; esto es solo un contrato estructural mínimo, NO confirma compatibilidad de toda la aplicación, frescura, anti-rollback ni integridad de datos de negocio.

Pruebas puras nuevas `scripts/test_o5_restore_schema_contract.py` (`59c646b`, 10 casos): aceptación del baseline y versión posterior, rechazo de baseline/initial/tablas ausentes, inventario duplicado o inválido. Script de auditoría read-only adaptado (`31ebea3`) para identificar el contrato nuevo; **la unidad O5 instalada en `/usr/local/libexec/` no ha sido inspeccionada ni modificada** y las copias diarias permanecen intactas. Este cambio no debe desplegarse sin ejecutar las pruebas y revisar restauración efímera y procedimiento de rollback.

Validación local única (SIN sudo, sin Docker, sin acceso a claves o DB):

    cd ~/vencira-localcheck
    git pull --ff-only origin feature/c-ficha-independent-attachments
    bash -n scripts/o5_restore_drill.sh scripts/audit_mb1_o5_restore_contract_readonly.sh
    python3 -m unittest -v scripts.test_o5_restore_schema_contract
    echo "MB1_O5_SCHEMA_FIX_EXIT_CODE=$?"

Esperado: **10 pruebas**, `OK`, `MB1_O5_SCHEMA_FIX_EXIT_CODE=0`. Código **aún sin validar mediante salida del operador**. No ejecutar en DEV el restaurador O5; para comprobar el código actual basta la prueba pura.

Pendiente para M1-05/M1-06: restauración desde Drive efectiva en clon, custodia externa autenticada, control anti-rollback previo a recuperación, alcance de adjuntos si se activan y separación de escritores. `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
