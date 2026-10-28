# C-FICHA — ensayo de separación de migraciones

Rama experimental: `feature/c-ficha-independent-attachments`.
Base: `integration/local-e2e-prep`.

## Implementado
Se ha creado la aplicación candidata `renewal_attachments` con su modelo y migración `0001_initial`. Depende únicamente de `reminders.0018_draft_reasons` y del modelo de usuario; **no contiene dependencias MFA**. El ensayo `scripts/rehearse_c_ficha_split_readonly.sh` inspecciona el grafo previsto sin ejecutar migraciones. PENDIENTE de validación en Ubuntu.

## Estado de aislamiento
No se ha añadido la app a `INSTALLED_APPS` de la configuración habitual, ni se han modificado los endpoints, referencias ORM o la antigua migración `reminders.0027`. Esta rama no debe desplegarse ni fusionarse hasta resolver el modelo duplicado en dos aplicaciones y la convivencia con entornos que ya aplicaron 0027 en clones temporales.

## Siguiente bloque antes de merge
1. Ensayo de grafo sin MFA.
2. Prototipo de transición de referencias ORM y reglas de datos históricos, mediante PostgreSQL 17 temporal en dos estados.
3. Garantía de que el entrypoint de despliegue no realiza `migrate` global arrastrando MFA.
4. Gate integral Django/Flutter y aprobación explícita de publicación.

MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1

## Ensayo PG17 independiente preparado (pendiente ejecución)
`backend/config/settings.py` sólo registra la app candidata con `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1` y `VENCIRA_ENV=test`; cualquier otro entorno con esa variable falla cerrado. `scripts/rehearse_c_ficha_split_readonly.sh` crea PostgreSQL17 y red efímeros, prueba la ascendencia 0018→renewal_attachments.0001, ejecuta esas migraciones **exclusivamente en la base vacía temporal** y verifica que ninguna 0019–0027 de reminders figura aplicada ni aparece la tabla `reminders_usermfastate`. Esta prueba todavía NO demuestra coexistencia posterior a MFA, no resuelve el modelo duplicado ni autoriza migración global o publicación. La rama de integración sigue intacta.

## Evidencia del ensayo independiente — APROBADO
Resultado comunicado por el operador (28-10-2026): `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK`, `C_FICHA_SPLIT_0001_WITHOUT_MFA=OK`, `C_FICHA_SPLIT_NO_MFA_TABLES=OK`, `C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `RESULTADO_FINAL=0`. Log local: `/tmp/vencira-c-ficha-split.T86Gv2sF.log`. Se ha verificado ruta independiente en PG17 temporal; no implica que esté integrada en backend/API ni que un `migrate` global sea seguro. Próximo hito: transición de modelos, coexistencia y gate completo sin tocar DEV.

## Ensayo ORM en PostgreSQL 17 — APROBADO
Resultado comunicado: `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK`, `C_FICHA_SPLIT_0001_WITHOUT_MFA=OK`, `C_FICHA_SPLIT_NO_MFA_TABLES=OK`, `C_FICHA_SPLIT_ORM_ROUTING=OK`, `C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log: `/tmp/vencira-c-ficha-split.rXmUMxXv.log`. No es validación de una sustitución final del modelo antiguo ni de un migrate global. PENDIENTES: transición y coexistencia 0027, API y operación completa de archivos, gate final, autorización separada.

## Ensayo de coexistencia añadido — PENDIENTE de ejecutar
Tras demostrar en PG17 temporal que `renewal_attachments.0001` se instala sin MFA, el mismo ensayo aplica `reminders.0027` (incluidas sus dependencias MFA) **sólo en esa base desechable**. Comprueba que existen ambas tablas con nombres diferentes, que no hay registros iniciales y que el selector mantiene el modelo independiente. Esto comprueba convivencia física de esquemas, NO una migración de datos históricos, ni evita el peligro de un `migrate` global en DEV. La publicación continúa prohibida. El gate anterior no cubre esta nueva fase y no debe citarse como su resultado.

## Coexistencia temporal comprobada — APROBADO
Operador informa: `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK`, `C_FICHA_SPLIT_0001_WITHOUT_MFA=OK`, `C_FICHA_SPLIT_NO_MFA_TABLES=OK`, `C_FICHA_SPLIT_ORM_ROUTING=OK`, `C_FICHA_SPLIT_BOTH_SCHEMAS_COEXIST=OK`, `C_FICHA_SPLIT_HISTORICAL_MFA_EPHEMERAL_ONLY=OK`, `C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Confirmada coexistencia física de tablas vacías en PG17 desechable, NO reconciliación de datos ni autorización de merge/release. Siguientes requisitos: eliminar duplicidad funcional, preparar migraciones sin MFA con procedimiento seguro y validar datos sintéticos en ambas rutas.

## Preflight de transición de datos sintéticos — SIN VALIDAR
Se incorpora `renewal_attachments/transition_preflight.py`: consulta en sólo lectura los recuentos del esquema antiguo e independiente y deniega la transición vacía ante cualquier registro. El ensayo PG17 crea adjuntos sintéticos alternativamente en ambas tablas y comprueba la denegación, sin copiar ni destruir ficheros reales. `C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK` queda pendiente de ejecución. **Límite:** recuento no es una garantía frente a concurrencia; antes de cualquier cambio real habrá que parar escrituras, hacer snapshot O5, reconciliar metadatos y objetos cifrados, validar digest y probar restore. No es herramienta de migración de datos ni concede autorización de despliegue.

## Ensayo de registros históricos — APROBADO (28-10-2026)
El operador comunicó: `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK`, `C_FICHA_SPLIT_0001_WITHOUT_MFA=OK`, `C_FICHA_SPLIT_NO_MFA_TABLES=OK`, `C_FICHA_SPLIT_ORM_ROUTING=OK`, `C_FICHA_SPLIT_BOTH_SCHEMAS_COEXIST=OK`, `C_FICHA_SPLIT_HISTORICAL_MFA_EPHEMERAL_ONLY=OK`, `C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK`, `C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log privado local: `/tmp/vencira-c-ficha-split.awxx4BR2.log`. Se aprueba el preflight de bloqueo con registros sintéticos; no está implementada la migración/reconciliación de datos históricos y no existe autorización de despliegue.

## Reconciliación comparativa en solo lectura — pendiente de gate
Se incorpora `backend/renewal_attachments/transition_reconciliation.py`: informe agregado con recuentos de registros no emparejados, inconsistencias por UUID y claves de almacenamiento reutilizadas con otro UUID, límite de 100000 registros por tabla y sin exposición de PII ni operaciones destructivas. Nunca concede autorización de publicación. El ensayo PostgreSQL temporal incluye casos sintéticos sin registros, registro antiguo aislado, metadatos coincidentes y discrepancia intencionada. Marcador pendiente: `C_FICHA_SPLIT_RECONCILIATION_READONLY=OK`. Los fixtures escritos en la base temporal no son una herramienta de migración, y el informe no inspecciona los bytes cifrados ni es seguro frente a escrituras concurrentes; exige pausa de escrituras, backup probado y reconciliación de objetos antes de cualquier migración real.

## Reconciliación en solo lectura validada — 28-10-2026
Evidencia del operador: `C_FICHA_SPLIT_PG17_EPHEMERAL=OK`, `C_FICHA_SPLIT_GRAPH_EXCLUDES_MFA=OK`, `C_FICHA_SPLIT_0001_WITHOUT_MFA=OK`, `C_FICHA_SPLIT_NO_MFA_TABLES=OK`, `C_FICHA_SPLIT_ORM_ROUTING=OK`, `C_FICHA_SPLIT_BOTH_SCHEMAS_COEXIST=OK`, `C_FICHA_SPLIT_HISTORICAL_MFA_EPHEMERAL_ONLY=OK`, `C_FICHA_SPLIT_HISTORICAL_RECORDS_BLOCKED=OK`, `C_FICHA_SPLIT_RECONCILIATION_READONLY=OK`, `C_FICHA_SPLIT_RELEASE_AUTHORIZED=NO`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log local `/tmp/vencira-c-ficha-split.z0rywYKw.log`. Aprobada la comparación sintética de metadatos; no se han reconciliado bytes cifrados ni autorizado despliegue. Próximo trabajo: diseño y prueba de conservación de objetos con datos exclusivamente sintéticos y gate integral antes de fusión.

## Bloque 1 agrupado — comprobación de integridad de objetos cifrados (en desarrollo)
Se añadieron `backend/renewal_attachments/transition_object_audit.py` y `test_transition_object_audit.py`: comparan ambos esquemas antes de inspeccionar exclusivamente en modo offline los objetos cifrados referenciados; comprueban legibilidad, SHA-256 y longitud y devuelven sólo contadores. Nunca entregan contenido ni autorizan liberación. Incluidos ensayos sintéticos de objeto válido, ausente y metadatos contradictorios. **Aún no ejecutado gate**. No confundir esta inspección con antivirus, restauración de backup, reconciliación durable frente a concurrencia o autorización de migración. Se mantiene como componente del BLOQUE 1, sin validaciones parciales; siguiente gate sólo tras completar el circuito conjunto. 

## Integración del gate de objetos cifrados — pendiente de ejecución
El ensayo de la rama experimental añade `python manage.py test renewal_attachments` con base de pruebas efímera después de la convivencia temporal de ambos esquemas. Incluye los casos de objeto cifrado válido, ausencia y discrepancia. Marcador `C_FICHA_SPLIT_OBJECT_AUDIT_TESTS=OK` aún no validado. Se añade `Cache-Control: no-store` también a la respuesta HTTP de subida rechazada. Nada de esto habilita acceso a documentos ni autoriza migraciones activas. Se mantiene el compromiso de evitar ensayos parciales y agrupar el gate con la entrega técnica completa.

## BLOQUE 1 — pruebas adicionales pendientes del gate integral
La auditoría de objetos cifrados compara también la proyección ordenada de claves, hashes y tamaños antes/después de la lectura. Un test sintético modifica metadatos durante la comprobación y exige bloqueo. test_independent_api.py comprueba que la API lista exclusivamente metadatos independientes autorizados, protege contra accesos de otros tenants y deniega operaciones HTTP. Estos tests se incluyen en la ejecución de la app independiente, pero NO se han ejecutado desde los últimos commits.

La app independiente continúa registrada sólo en test, el modelo antiguo permanece y no se han habilitado uploads/downloads/deletes. Para cerrar BLOQUE 1 faltan conexión efectiva con escáner aislado y firma verificable persistida, transición final y flujo real seguro en backend y Flutter; ningún resultado previo equivale a autorización de despliegue.
