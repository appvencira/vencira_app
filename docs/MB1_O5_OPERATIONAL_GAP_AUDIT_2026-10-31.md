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
