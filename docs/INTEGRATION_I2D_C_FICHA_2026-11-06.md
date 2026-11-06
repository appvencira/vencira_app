# I2-D — Consolidación C-FICHA aislada en main

**Fecha:** 2026-11-06

## Resultado de preparación
- Base de main: `7d47482bbe0047c4011f4ca73e2fb1828edb4dab`.
- Origen: rama `feature/m3-android-local-notifications`, commit `2b770626baa98deccbcde1c79e69679447d9a304`.
- Incorporados mediante blobs Git originales **138 archivos** en `backend/renewal_attachments/`, incluidas migraciones propias `0001`–`0006`, código de ensayos offline/aislamiento y pruebas.
- El backend principal, UI Flutter y el control `may_download_attachment(...)=False` permanecen intactos.
- El registro `renewal_attachments` en `backend/config/settings.py` **exige** `VENCIRA_ENV=test` y `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1`. La instalación predeterminada de DEV/producción no registra la app; la API sigue siendo de metadatos y las operaciones de archivos continúan denegadas.
- La existencia de código de recuperación, cifrado, firmantes y ensayos NO demuestra seguridad de almacenamiento real ni habilita un servicio de adjuntos. Las migraciones solo se versionan.

## Validaciones obligatorias
Workflow `.github/workflows/i2d-c-ficha-isolated.yml`, en CI con SQLite temporal, sin acceso a PostgreSQL vivo ni secretos operativos:
1. `manage.py check` con split test explícito.
2. `makemigrations --check --dry-run`.
3. Tests aislados de lectura y prohibición de subida/descarga/eliminación, pertenencia a workspace, integridad de contrato objeto y límites de autorización.
4. Verificación negativa de que la aplicación split se rechaza fuera del entorno `test`.

**Aún sin PASS del HEAD.** Esta PR permanecerá en borrador hasta verificar el workflow, y no se ejecutarán todas las suites offline/PG17 automáticamente: muchas requieren dispositivos o fixtures desechables específicos.

## Próxima fase
Después de fusionar código aislado se podrá evaluar de forma independiente un laboratorio PostgreSQL 17 efímero para coexistencia/migraciones y, en otra decisión, el protocolo de custodia, almacenamiento privado, cifrado y análisis de malware. Ninguna operación de subida o descarga se habilitará por la integración en `main`.

`C_FICHA_RELEASE_AUTHORIZED=NO`
`MB1_RELEASE_AUTHORIZED=NO`
`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`

## Primera ejecución de CI — corrección de alcance

El primer workflow de I2-D (HEAD 385fd09) ejecutó 26 pruebas con 4 fallos: las pruebas del modelo histórico `reminders.RenewalAttachment` esperaban resultados del esquema original, pero el flag de ensayo de esquema independiente estaba activado globalmente. Django check y `makemigrations --check --dry-run` fueron correctos. No se atribuyó fallo de migración ni seguridad por este síntoma.

La suite ahora se divide de forma explícita: pruebas `renewal_attachments` con `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1` y pruebas de API/alcance histórico con `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=0`. El test de denegación en entorno no-test continúa. El nuevo HEAD necesita CI verde antes del merge; ninguna función de subida/descarga queda autorizada.
