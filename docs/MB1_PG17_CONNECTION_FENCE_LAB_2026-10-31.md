# MB1 — Experimento de barrera SQL (31/10/2026)

**Estado: implementado, no ejecutado.** Rama feature/c-ficha-independent-attachments.

El script scripts/rehearse_mb1_pg17_connection_fence_disposable.sh crea exclusivamente un contenedor PostgreSQL 17 nuevo sin red externa, rol de ensayo y base de ensayo. Aplica ALTER ROLE ... NOLOGIN al rol ordinario y comprueba que no puede abrir una conexión TCP nueva. Confirma deliberadamente que el administrador conserva acceso. Destruye el contenedor al salir; no toca volúmenes, proyectos VENCIRA ni O5.

**Limitación crítica:** NOLOGIN no corta sesiones abiertas, NO detiene administradores ni otros roles y no protege ficheros. Por tanto, **no es una barrera global apta para producción**. Este experimento prueba solo una propiedad acotada: denegación de conexión a un rol ordinario después de cambiarlo. Se requiere diseñar una puerta de mantenimiento para todos los escritores, gestionar sesiones en curso, evitar bypass y probar captura coherente de PostgreSQL y almacenamiento persistente.

Ejecutar en VPS, sin reiniciar servicios:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_pg17_connection_fence_disposable.sh
sudo bash scripts/rehearse_mb1_pg17_connection_fence_disposable.sh
echo "MB1_PG17_FENCE_EXIT_CODE=$?"
```

Esperado: MB1_PG17_NEW_WRITER_DENIAL=OK; MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK; MB1_PG17_FENCE_RESULT=0. Los marcadores EXISTING_WRITER_DRAIN=NOT_VERIFIED, GLOBAL_FREEZE=NOT_VERIFIED y RELEASE_AUTHORIZED=NO deben persistir.

**M1-03 pendiente** (vías SQL y tareas fuera del control); **M1-04 pendiente** (barrera integral y captura restaurable). No tachar por publicar el código ni por aprobar este ensayo parcial.


## Resultado confirmado por operador — PASS parcial

`MB1_PG17_NEW_WRITER_DENIAL=OK`, `MB1_PG17_EXISTING_WRITER_DRAIN=NOT_VERIFIED`, `MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK`, `MB1_PG17_FENCE_RESULT=0`, `MB1_PG17_FENCE_EXIT_CODE=0`. Asimismo `MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED`, `MB1_FILESYSTEM_WRITERS=NOT_BLOCKED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`. Prueba **únicamente** de denegación de conexión nueva a un rol ordinario, no un freeze. M1-04 sigue abierto.


## Segunda etapa M1-04: sesión preexistente y drenaje (pendiente de operador)

Commit `a7947e2`: el mismo ensayo efímero establece primero una sesión SQL de un rol ordinario, mantiene una transacción abierta con `pg_sleep(18)` y exige observarla en `pg_stat_activity`. Después impone `NOLOGIN` al rol, comprueba que nuevas conexiones fracasan y **rechaza considerar apta la captura** mientras siga viva la transacción. Tras la salida del escritor verifica que no queda sesión y marca `MB1_PG17_EXISTING_WRITER_DRAIN=OK`, `MB1_PG17_CAPTURE_SQL_QUIESCENT_LAB=OK`; verifica además que el administrador continúa pudiendo acceder. Se mantiene `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, ya que la sesión del administrador y otros roles no están bloqueados y los archivos no forman parte del ensayo. Ejecutar el mismo script tras `git pull`; no hay necesidad de repetir otras suites. **No validado aún**.


## Segunda etapa validada por operador — PASS parcial

`MB1_PG17_EXISTING_WRITER_ACTIVE=OK`, `MB1_PG17_NEW_WRITER_DENIAL=OK`, `MB1_PG17_CAPTURE_BLOCKED_WHILE_WRITER_ACTIVE=OK`, `MB1_PG17_EXISTING_WRITER_DRAIN=OK`, `MB1_PG17_CAPTURE_SQL_QUIESCENT_LAB=OK`, `MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK`, `MB1_PG17_FENCE_RESULT=0`, `MB1_PG17_FENCE_EXIT_CODE=0`. Persisten `MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED`, `MB1_FILESYSTEM_WRITERS=NOT_BLOCKED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED` y `MB1_RELEASE_AUTHORIZED=NO`. El test prueba drenaje de un rol ordinario controlado, no ausencia de todos los escritores. M1-04 sigue pendiente.


## M1-04: captura combinada PG17 + fichero bajo bloqueo cooperativo (pendiente)

Commit `4a944f4` extiende el script sin tocar DEV. Tras confirmar que el rol escritor está deshabilitado y su sesión ha terminado, crea dos archivos **sintéticos no cifrados** en directorios temporales 0700, y adquiere `IsolatedProcessFence.capture()` contra un escritor cooperativo de otro proceso. Bajo el bloqueo exclusivo ejecuta `pg_dump -Fc` de la base PG17 efímera, restaura en una segunda base efímera, comprueba una fila y verifica hashes estables de los archivos; al liberar, confirma que el escritor cooperativo vuelve a obtener el lock. Esto no congela superusuarios ni writers de archivos que ignoren el bloqueo, y no sustituye restauración integral de adjuntos cifrados. Por ello M1-04 continúa abierto. Nuevos marcadores previstos: `MB1_JOINT_FILE_WRITER_DENIED=OK`, `MB1_JOINT_PG17_DUMP_RESTORE=OK`, `MB1_JOINT_FILES_HASH_STABLE=OK`, `MB1_JOINT_COOPERATIVE_FENCE_RELEASE=OK`, `MB1_JOINT_CAPTURE_LAB=OK`, `MB1_UNIVERSAL_CAPTURE=NOT_VERIFIED`. Validar con el mismo runner tras `git pull`, sin ejecutar otras suites.


## Resultado de captura conjunta — PASS parcial (operador)

Se han confirmado `MB1_PG17_EXISTING_WRITER_ACTIVE=OK`, `MB1_PG17_NEW_WRITER_DENIAL=OK`, `MB1_PG17_CAPTURE_BLOCKED_WHILE_WRITER_ACTIVE=OK`, `MB1_PG17_EXISTING_WRITER_DRAIN=OK`, `MB1_PG17_CAPTURE_SQL_QUIESCENT_LAB=OK`, `MB1_JOINT_FILE_WRITER_DENIED=OK`, `MB1_JOINT_PG17_DUMP_RESTORE=OK`, `MB1_JOINT_FILES_HASH_STABLE=OK`, `MB1_JOINT_COOPERATIVE_FENCE_RELEASE=OK`, `MB1_JOINT_CAPTURE_LAB=OK`, `MB1_PG17_FENCE_RESULT=0`, `MB1_PG17_FENCE_EXIT_CODE=0`. Permanecen explícitamente `MB1_UNIVERSAL_CAPTURE=NOT_VERIFIED`, `MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED`, `MB1_FILESYSTEM_WRITERS=NOT_BLOCKED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`. El test utiliza dos archivos sintéticos no cifrados y una base PG17 efímera. **M1-04 sigue pendiente**; no extrapolar a freeze universal o captura operacional.


## Extensión: clases reales de cifrado y diario bajo lock (sin validar)

Commit `d94154d`: tras la captura PG17/archivos sintéticos ya validada, el mismo script crea un objeto cifrado Fernet mediante `PrivateQuarantineStore` y una intención mediante `IntakeJournal` en directorios temporales privados, ejecutando la imagen Django de la rama. Una segunda instancia de dicha imagen los descifra y comprueba el SHA-256 dentro de `IsolatedProcessFence.capture`. Se espera `MB1_REAL_ENCRYPTED_STORE_JOURNAL=WRITE`, `MB1_REAL_ENCRYPTED_STORE_JOURNAL=READ` y `MB1_ACTUAL_ENCRYPTED_OBJECT_JOURNAL_CAPTURE=OK`. Esta extensión aún **no une un único snapshot transaccional de PG17 y los objetos reales**; la prueba conjunta previa mantiene archivos sintéticos. Tampoco prueba writers no cooperativos ni administración SQL. No habilitar liberación. Ejecutar el mismo script tras `git pull`; mantener M1-04 sin tachar.


## Fallo de configuración del subproceso Django — corregido, sin revalidar

El operador confirma PASS de bloqueo SQL, drenaje, captura PG17 y hashes de archivos sintéticos, pero la fase real de Fernet/IntakeJournal abortó antes de escribir por `ImproperlyConfigured: Requested setting LOGGING_CONFIG, but settings are not configured`. El contenedor invocaba `python -c` con `django.setup()` sin `DJANGO_SETTINGS_MODULE`. Commit `cec92ec` agrega `DJANGO_SETTINGS_MODULE=config.settings` solo a ese contenedor efímero. La ejecución finalizó `MB1_PG17_FENCE_RESULT=1`. **No marcar PASS de cifrado ni M1-04 hasta reejecución.**
