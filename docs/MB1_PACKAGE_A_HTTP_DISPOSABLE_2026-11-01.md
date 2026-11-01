# VENCIRA — paquete A: gate HTTP aislado (01/11/2026)

Rama de trabajo: `feature/mb1-m104-transition-contract-batch`. El contrato de inventario sintético anterior tiene 11/11 PASS y **no se repite**.

## Alcance desarrollado
`backend/renewal_attachments/offline_mb1_package_a_http.py` recorre solicitudes mediante `django.test.Client` con middleware real, sesiones y autorización (sin `APIRequestFactory`). Se prueban usuario anónimo, miembro autorizado, otros tenants, listados de solo metadatos y negativa de subida, lectura y borrado, incluso en estado CLEAN.

`scripts/rehearse_mb1_package_a_http_disposable.sh` crea imagen aislada, red `--internal`, PostgreSQL 17 temporal, aplica objetivos explícitos `reminders.0018`, `renewal_attachments.0006`, `auth`, `sessions` y elimina recursos mediante trap. Prohibido uso en DEV. Para satisfacer las consultas del middleware, crea **solo en la base efímera y con rol administrador sintético separado** tablas vacías MFA sintéticas mediante `schema_editor`, sin aplicar migraciones MFA. Esto prueba el middleware en el caso sin MFA activo, **no** la seguridad operacional MFA ni un grafo migratorio de producción.

## Limitaciones y aceptación
Este ensayo no ejecuta ambos esquemas históricos, no prueba reconciliación en PG17, no verifica usuario DB limitado para HTTP, no prueba adjuntos cifrados ni malware y no constituye freeze universal. No se marca M1-03/M2-03 como cerrado. `MB1_PA_RESULT=0` solo significaría PASS del alcance HTTP descrito. **Gate escrito pero no ejecutado**, no inventar resultado.

Antes de intentar el siguiente gate de convivencia histórica/independiente, revisar dependencia MFA de `reminders.0027`; no aplicar esa cadena en DEV ni considerarla una migración permitida automáticamente. Un laboratorio coexistente debe construirse con fixture sintético controlado o abortar explícitamente si no hay camino válido.

## Comando de ejecución previsto
Utilizar una copia temporal del HEAD de la rama en GitHub, nunca cambiar el checkout del VPS o actualizar servicios. El script requiere `MB1_PACKAGE_A_OPT_IN=YES` y `sudo docker` local para contenedores efímeros. No ejecuta `docker compose up`, no solicita credenciales de DEV y no requiere claves reales.

Estado: PASS confirmado del alcance HTTP aislado; coexistencia histórica NO EJECUTADA. `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `MFA_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Ejecución real confirmada por operador — 01/11/2026

`MB1_PA_SOURCE_PREFLIGHT=OK`, `MB1_PA_INTERNAL_PG17=OK`, `MB1_PA_MFA_TABLES_SYNTHETIC_ONLY=OK`, `MB1_PA_HTTP_NONADMIN_ROLE=OK`, `MB1_PA_REAL_HTTP_MIDDLEWARE_METADATA_ONLY=OK`, `MB1_PA_REAL_HTTP_CROSS_TENANT_DENIED=OK`, `MB1_PA_MFA_MIGRATIONS=NOT_APPLIED`, `MB1_PA_FULL_HTTP_NEW_ONLY=OK`, `MB1_PA_PHASE=DONE`, `MB1_PA_RESULT=0`, `MB1_PA_NONADMIN_HTTP=OK`. Límites expresos: `MB1_PA_HISTORICAL_BOTH_SCHEMAS=NOT_RUN`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, release `NO`, sin migraciones live. No hay medición independiente postensayo de salud DEV; el runner no apunta a DEV.
