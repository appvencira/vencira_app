# MB1 — Integración PG17 + almacén cifrado + diario persistente

**30/10/2026. Implementado en rama, aún sin ejecución del operador.**

`scripts/rehearse_mb1_integrated_durable_pg17.sh` integra en un mismo ensayo la **implementación real** `PrivateQuarantineStore` (Fernet), `IntakeJournal` (intención duradera) y modelo ORM `RenewalAttachment` sobre PostgreSQL 17 desechable. Crea red Docker interna nueva, PostgreSQL efímero, dos volúmenes Docker de laboratorio para objetos y diario, migra únicamente la base temporal hasta `reminders.0018` y `renewal_attachments.0006`, guarda una ficha sintética y su objeto cifrado/intención. A continuación **lanza un segundo contenedor Django** conectado a los mismos recursos temporales y comprueba la recuperación, huella SHA-256 del texto descifrado, identidad de `storage_key` y consistencia con la ficha ORM. El trap elimina sus recursos nombrados; no elimina ni migra ninguna base persistente de DEV.

**Límites:** no es un ciclo transaccional integral autorizado (la prueba crea modelo, diario y objeto consecutivamente); no prueba fallo a mitad de operación, writers simultáneos, freeze global, servidor remoto ni backup operacional. La clave Fernet de ensayo se genera en el volumen efímero del propio laboratorio; **no es custodia externa**. Los montajes son volúmenes de ensayo, no destinos operativos. La restauración independiente sintética MB1 anterior se mantiene válida.

## Comprobación única en VPS IONOS

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_integrated_durable_pg17.sh
sudo bash scripts/rehearse_mb1_integrated_durable_pg17.sh
echo "MB1_INTEGRATED_EXIT_CODE=$?"
```

Si falla, facilitar **solo** fase, error sin secretos y código de salida; no continuar con despliegue. Éxito esperado: `MB1_INTEGRATED_REAL_STORE_JOURNAL_PG17=OK`, `MB1_INTEGRATED_RECREATED_APP_CONSISTENT=OK`, `MB1_INTEGRATED_PG17_PRIVATESTORE_JOURNAL_PERSISTENCE=OK`, `MB1_INTEGRATED_RESULT=0`. Mantener `MB1_OPERATIONAL_RELEASE=NO`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

La etapa siguiente, tras PASS, es demostrar comportamiento fail-closed frente a una interrupción o escritura concurrente mediante el writer barrier ya existente y un ensayo con PG17/FS controlados.


## Incidencia de ejecución y corrección

La primera ejecución produjo `PermissionError: [Errno 1] Operation not permitted: '/lab/objects'` en fase `WRITE`, y `MB1_INTEGRATED_RESULT=1`. Causa: raíz de volumen Docker creada con propietario root frente al usuario no privilegiado de Django. Commit `c5100f9`: tras crear **exclusivamente** los dos volúmenes efímeros, obtiene UID/GID de la imagen Django y utiliza un contenedor aislado temporal con usuario root para ajustar propietario y permisos 0700. La prueba Django ahora verifica los permisos sin intentar modificarlos. No se cambian permisos ni volúmenes de DEV. **Corrección aún pendiente de validación**.


## Revalidación tras corrección de permisos — PASS

El operador informa `MB1_INTEGRATED_PRIVATE_VOLUME_PERMISSIONS=OK`, `MB1_INTEGRATED_REAL_STORE_JOURNAL_PG17=OK`, `MB1_INTEGRATED_RECREATED_APP_CONSISTENT=OK`, `MB1_INTEGRATED_PG17_PRIVATESTORE_JOURNAL_PERSISTENCE=OK`, `MB1_INTEGRATED_RESULT=0` y `MB1_INTEGRATED_EXIT_CODE=0`. Ensayo sintético con PostgreSQL 17 temporal y dos volúmenes Docker desechables. No acredita freeze global, custodia externa operativa ni activación de adjuntos en DEV. `MB1_OPERATIONAL_RELEASE=NO`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.


## Extensión M1-01 (pendiente de ejecución)

Commit `52464eb`: tras validar la persistencia, el mismo laboratorio efímero crea tres fallos sintéticos distintivos en **PG17 y volúmenes reales de ensayo**: solo intención, solo objeto y solo metadatos. Enumera los tres inventarios sin mutarlos durante clasificación y verifica que el clasificador devuelve exactamente cada caso, mantiene una ficha completa y bloquea reparación, borrado y liberación. Marcadores: `MB1_INTEGRATED_PG17_ORPHAN_CLASSIFICATION=OK` y `MB1_INTEGRATED_AUTOMATIC_REPAIR=DISABLED`. **No ejecutado aún.** Ejecutar el mismo runner con `sudo` tras `git pull --ff-only`; no repetir las suites anteriores. Checklist central: `docs/VENCIRA_MASTER_COMPLETION_CHECKLIST_2026-10-30.md`.


## M1-02 — Interrupción real con transacción PG17 abierta (pendiente de ejecutar)

Commit `4ab0fa0`: ampliación del mismo laboratorio temporal. Tras los ensayos anteriores, un nuevo proceso Django registra y sincroniza una intención y objeto cifrado real, inicia una transacción `transaction.atomic()` de PostgreSQL 17, inserta metadatos y se interrumpe a sí mismo con `SIGKILL` **antes del commit**. El orquestador exige código de salida 137. Un contenedor Django posterior debe comprobar que PostgreSQL ha revertido los metadatos no confirmados, pero que el objeto cifrado y diario todavía están presentes y legibles. El clasificador debe señalar `intent_and_object_without_metadata=1` y mantener reparación, eliminación y liberación bloqueadas. Marcadores: `MB1_SIGKILL_PG17_ROLLBACK=OK`, `MB1_SIGKILL_ENCRYPTED_OBJECT_JOURNAL_PRESERVED=OK`, `MB1_SIGKILL_READONLY_RECONCILIATION=OK`, `MB1_INTEGRATED_RESULT=0`. **Sin ejecución confirmada.** Esto demuestra recuperación de un estado tras la caída, no conciliación reparadora ni coherencia global con escritores simultáneos. Checklist: M1-02 sigue pendiente de cerrar.


## M1-02: ejecución con salida inesperada y corrección de aislamiento de shell

La ejecución del operador pasó los gates previos, pero en `SIGKILL_PG17` el comando terminó con **código 0** (`MB1_SIGKILL_UNEXPECTED_SUCCESS=1`, `MB1_INTEGRATED_RESULT=1`, `MB1_INTEGRATED_EXIT_CODE=1`), en lugar del 137 exigido. No se ha demostrado la interrupción y no es legítimo marcar PASS. No hay evidencia suficiente para afirmar por qué la shell devolvió 0; una posible causa es el intérprete interactivo autoseleccionado por Django. El commit `ba2eeae` fuerza `manage.py shell --interface python` solo para la fase SIGKILL y mantiene la exigencia de código 137 junto con la inspección independiente del estado PostgreSQL/objetos. **Pendiente de revalidación.**


## Segunda ejecución fallida y cambio de estrategia

El operador vuelve a informar `MB1_SIGKILL_UNEXPECTED_SUCCESS=1` en `SIGKILL_PG17` tras la corrección de shell (`e54be73`), por lo que la hipótesis anterior no resolvió el problema. Commit `4be795b`: la fase ahora invoca **Python directamente como PID 1 del contenedor Docker**, configura Django mediante `django.setup()` y ejecuta la transacción; se sigue exigiendo código Docker `137` por SIGKILL y posterior verificación de rollback y conservación. Esta modificación está **pendiente de ejecutar**. No se ha dado por validado M1-02. No hay cambios en DEV.


## Tercera ejecución fallida: cambio a SIGKILL externo

La tercera ejecución, incluso invocando Python como PID 1, devolvió `MB1_SIGKILL_UNEXPECTED_SUCCESS=1`, `MB1_INTEGRATED_PHASE=SIGKILL_PG17`, `MB1_INTEGRATED_RESULT=1`, `MB1_INTEGRATED_EXIT_CODE=1`. La autoseñal de un proceso PID 1 de contenedor no es un procedimiento fiable de ensayo de terminación forzosa: no se considera evidencia de rollback. Corrección publicada en commits `1701dc4` y `427a3ae`: se lanza un **contenedor escritor separado en segundo plano**, que guarda objeto/diario con fsync, abre una transacción PG17 e inserta metadatos, crea un marcador sincronizado en el volumen del diario y permanece vivo con la transacción abierta. El host verifica dicho marcador, ejecuta `docker kill --signal KILL` contra **únicamente ese contenedor de nombre temporal** y exige resultado de `docker wait` 137; posteriormente otro proceso consulta PostgreSQL y clasifica la inconsistencia en modo lectura. El trap elimina el contenedor temporal si algo falla. No se interviene en el contenedor DB ni en los servicios DEV. **Pendiente de ejecutar y validar**. Antes de correr: `bash -n scripts/rehearse_mb1_integrated_durable_pg17.sh`.
