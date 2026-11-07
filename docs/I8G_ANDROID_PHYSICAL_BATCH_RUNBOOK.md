# I8-G — Macrobloque Android de almacenamiento protegido (07/11/2026)

## Estado

- I8-E: HTTPS real backend contra PostgreSQL 17 efímero — **PASS**.
- I8-F: Flutter real contra backend candidato por TLS — **PASS**.
- I8-G gate estático y contrato: **24 tests PASS**, confirmados en Termius.
- I8-G APK de almacenamiento protegido en Android físico: **PREPARADO, NO EJECUTADO**.
- `MFA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

## Un solo gate VPS de construcción

En `~/vencira-m3-localcheck` actualizar la rama de forma fast-forward
y ejecutar `bash scripts/native_i8g_android_batch.sh`. El script repite
24 tests de contrato, analiza Flutter y el código instrumentado, compila
exclusivamente una APK **DEBUG** con `applicationId=es.vencira.vencira.i8glab`
y devuelve:

- `NATIVE_I8G_BATCH_MAIN_ANALYZE=OK`
- `NATIVE_I8G_BATCH_APK_PACKAGE=es.vencira.vencira.i8glab`
- `NATIVE_I8G_BATCH_APK_BUILD=PASS`
- `NATIVE_I8G_BATCH_GATE=PASS`
- `NATIVE_I8G_BATCH_DEV_CONTAINERS_UNCHANGED=YES`
- `NATIVE_I8G_BATCH_LOCAL_RESULT=0`

APK local en VPS, si el gate pasa:
`~/vencira-m3-localcheck/clients/flutter/build/i8g-phone/VENCIRA-I8G-LAB-debug.apk`.
Al lado se genera el archivo `.sha256`. **No hay descarga o instalación
automática** ni exposición de puerto HTTP para repartir APK.

## Paso físico — teléfono Android

1. Transferir la APK desde el VPS por un canal autenticado (SFTP de Termius,
   o SCP desde un equipo propio). Comprobar SHA256 del archivo transferido.
2. Instalar manualmente la APK de laboratorio con identificador independiente
   `es.vencira.vencira.i8glab`. No desinstalar ni borrar datos entre fases.
3. Abrir **VENCIRA I8-G Storage**, pulsar
   «1. Guardar y rotar credencial sintética». Debe mostrar
   `NATIVE_I8G_ANDROID_PHASE1=PASS`.
4. En Android: Ajustes → Aplicaciones → VENCIRA I8-G Storage →
   **Forzar detención**. Volver a abrir la app (no borrar datos).
5. Pulsar «2. Verificar persistencia y borrar». Debe mostrar
   `NATIVE_I8G_ANDROID_PHASE2_PERSISTENCE=PASS`.
6. Pulsar «Borrar datos sintéticos de I8-G», confirmar
   `NATIVE_I8G_ANDROID_LAB_CLEAN=PASS`; desinstalar cuando termine.

Se usan exclusivamente valores sintéticos y el namespace de prueba
`vencira_i8g_device_disposable_v1`, sin servidor. No copiar tokens ni
contraseñas a los logs. Si aparece un marcador de fallo, **no atribuir PASS**.
Registrar versión Android y resultado de cada fase (sin identificadores,
secretos ni datos personales).

## Qué demuestra y qué no

La fase física comprueba escritura, rotación, readback y persistencia tras
force-stop/reapertura mediante el plugin real de Android y la capa de vault
de Flutter. **No** demuestra atestación de hardware, imposibilidad de
extracción forense, supervivencia a reinstalación, recuperación MFA con
PostgreSQL real, credenciales operativas o APK funcional para usuarios.
G13 ya tiene pruebas físicas de HTTPS sobre otro laboratorio; I8-G no las
sustituye. Mantener separado el gate de Android, la autorización de emisión
MFA y el futuro despliegue operativo.

## Evidencia física posterior — 07/11/2026

El usuario aportó capturas de la APK DEBUG de laboratorio que muestran `NATIVE_I8G_ANDROID_PHASE1=PASS`, `NATIVE_I8G_ANDROID_PHASE2_PERSISTENCE=PASS` y `NATIVE_I8G_ANDROID_LAB_CLEAN=PASS`. Se confirma ejecución visible de las tres fases y limpieza de la credencial sintética, no uso de cuentas operativas. La secuencia exacta de «Forzar detención» en Ajustes no queda demostrada únicamente por las capturas; para una certificación formal de resistencia al cierre forzado debe registrarse esa acción como evidencia adicional. Sigue sin equivaler a una atestación hardware ni al backend MFA operativo. Restricciones invariables: `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

