# VENCIRA — C-FICHA, macroentrega única

Fecha 28-10-2026. Rama integration/local-e2e-prep. Objetivo: terminar el sistema de adjuntos de pólizas SIN fragmentar ensayos por fichero y SIN desplegar prematuramente.

## Base ya validada que NO se repite individualmente
- Ficha y contratos existentes del whitepaper §6.
- Metadatos 0027, cifrado sintético, scope owner/asignado/tenant, preinspección.
- Firma/verificación de veredictos sintéticos, adaptador ClamAV simulado.
- ClamAV real detectó EICAR en un contenedor aislado.
- PG17 temporal 0027 y pruebas integradas comunicadas con resultado 0.
- Ninguna base productiva migrada; MFA sigue bloqueado.

## Entrega de código incorporada en este bloque
- API de metadatos de adjuntos con comprobación de organización y visibilidad de anotación, devolviendo estado de operaciones desactivadas. No se exponen rutas privadas ni hashes/identificadores de objeto.
- Endpoints POST upload, GET download y DELETE: rechazados de forma explícita.
- Pantalla premium de documentos en ficha con bloqueo visible ES/CA, pruebas visuales móviles 320/375/768.
- Pruebas API cross-workspace, asignación, anónimo, bloqueo de modificaciones.
- Gate PostgreSQL17 temporal + Flutter actualizado para validar de una vez el código nuevo.

**No se declara completo ni listo para producción.** La macroentrega solicitada agrupa el trabajo pero el circuito operativo necesita garantías aún no construidas.

## Criterios obligatorios antes de activar adjuntos
1. Servidor de escaneo clamd realmente aislado y actualizado, comunicación Unix validada; verificaciones completas PDF/JPEG/PNG, límites memoria y fallo cerrado.
2. Pipeline de cuarentena a CLEAN con atestación verificable emitida por servicio separado, persistencia auditada y revocación por cambio de contenido, actualización de firmas y caducidad de resultados.
3. Almacén privado cifrado independiente de MFA, montaje read-only cuando procede, credenciales custodias, recuperación junto a snapshots O5, cuotas, restauración y eliminación segura según RGPD.
4. API real de subida, listado, descarga y eliminación con CSRF, tenant/asignación, revisión archivo/cliente, límites, idempotencia, atomicidad BD/objetos, bloqueos carreras y medidas ante objetos huérfanos.
5. Flutter documentos, galería/cámara/selector, progreso, borrado y errores, ES/CA y validación Android/PC; no leer contactos masivamente.
6. Resolver migración 0027 que depende de 0026 MFA, sin aplicar nunca MFA a producción por vía indirecta.
7. Auditoría adversaria y gate integrado final PG17 + Flutter + escáner real y restauración de claves/backup, seguida de autorizaciones expresas para publicación y cargas reales.

## Estado
C_FICHA_BACKEND_API_METADATA_ONLY=CODE_READY_UNTESTED
C_FICHA_FLUTTER_LOCKED_UI=CODE_READY_UNTESTED
C_FICHA_OPERATIONAL_UPLOAD_DOWNLOAD=BLOCKED
C_FICHA_MACRO_GATE=PREPARED_UNRUN
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1

## Gate integral comunicado por operador — SUPERADO
Candidato validado `09987ca6f3d8410c002a9e75a670dce4b61ce761`. Resultados: `C_FICHA_MIGRATIONS_MATCH_MODELS=OK`, `C_FICHA_PG17_EPHEMERAL=OK`, `C_FICHA_SCHEMA_0027_WITH_MFA_DEPENDENCY=OK`, `C_FICHA_PG17_INTEGRATED_TESTS=OK`, `C_FICHA_FLUTTER_ANALYZE_TEST_BUILD=OK`, `C_FICHA_PUBLIC_UPLOAD_DOWNLOAD=DISABLED`, `C_FICHA_LIVE_MIGRATION_0027=NOT_AUTHORIZED`, `CLEANUP=OK`, `C_FICHA_PG17_GATE_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `RESULTADO_FINAL=0`. Log privado local `/tmp/vencira-c-ficha-pg17.3Bt4So9e.log`. Validación de componentes existentes: no equivale a completar el circuito operativo ni autoriza migraciones. No repetir este gate salvo modificaciones relevantes.

## Revisión de seguridad posterior al gate anterior
Se endureció la orquestación en cuarentena: requiere estado `quarantined` y trata excepciones del motor como fallo cerrado. Pruebas nuevas incorporadas y pruebas sintéticas anteriores ajustadas. **Pendiente nuevo gate; no afirmar probado este cambio.**

### Dependencia de migraciones
No modificar a ciegas la dependencia de `0027` (actualmente `0026`). Cambiarla directamente a `0018` crearía dos hojas del grafo `reminders` (rama MFA 0019–0026 y rama adjuntos 0027), y un merge mal diseñado podría volver a aplicar MFA indirectamente. Antes de desplegar, diseñar ramas de migración independientes con estrategia Django explícita y probar `showmigrations`, `migrate --plan`, estado 0018 y MFA desactivado en un clon restaurado. Ningún cambio al esquema persistente está autorizado.

## Firma del veredicto — código nuevo, pendiente de gate
Se agregó `attachment_scan_attestation.py` como primitiva **exclusiva del proceso escáner separado**: firma HMAC-SHA256 el digest SHA256, identificador del objeto, resultado, instante y versión de motor. `test_attachment_scan_attestation.py` prueba aceptación sintética de veredicto limpio, rechazo si cambian bytes, si la firma caduca, si se declara infectado o si el objeto no está en cuarentena. Ninguna clave real se ha configurado. El verificador actual permanece sólo consultivo y `may_download_attachment` sigue siempre `False`. Se añadió la prueba al gate conjunto, **que todavía no se ha ejecutado sobre este nuevo commit**. La publicación sigue bloqueada y la revisión del grafo 0018/0019–0027 continúa pendiente.

## Nuevo gate de frontera 0018 → 0027 (preparado, no ejecutado)
El gate integrado ahora levanta PG17 efímero, migra primero exactamente a 0018 y verifica que ninguna migración 0019–0027 aparece aplicada. Después consulta `migrate --plan` hacia 0027 y exige que se enumeren 0019 MFA, 0026 MFA y 0027 adjuntos. Publica explícitamente `C_FICHA_0027_LIVE_MIGRATION=BLOCKED`; **sólo en el PostgreSQL efímero** continúa con 0027 para pruebas sintéticas. Esto demuestra la incompatibilidad actual para publicación independiente, no la resuelve y no autoriza nada en DEV. Prueba pendiente, sin necesidad de reejecutar antiguos gates individuales.

## Ingesta offline de cuarentena cifrada (código nuevo, sin probar)
`attachment_quarantine_intake.py` aporta ingesta de bytes inmutables: cabecera/tipo/tamaño, SHA-256, UUID aleatorio, almacenamiento privado cifrado y confirmación externa de metadatos. Si esa confirmación falla, `PrivateQuarantineStore.discard_quarantine` elimina el objeto creado (sin exponerlo en API). `test_attachment_quarantine_intake.py` cubre datos sintéticos, cifrado y limpieza ante fallos. Incluido en el gate conjunto, que sigue **pendiente de ejecución sobre este commit**. Advertencia: esta primitiva no garantiza atomicidad completa entre disco y PostgreSQL ante cortes de proceso/energía; se requiere reconciliación durable, trazabilidad, cuotas y servicio de escaneo aislado antes de permitir subidas reales. No cambia permisos de descarga, ni endpoints ni esquema vivo.

## Auditoría offline de objetos huérfanos — código, pendiente gate
`attachment_orphan_audit.py` contrasta identificadores UUID del almacén privado con un conjunto consistente proporcionado por el operador/proceso de administración. Informa objetos sin referencia, referencias ausentes y entradas inseguras (incluidos enlaces simbólicos), sin descifrar, eliminar ni modificar ficheros. Añadidos tests `test_attachment_orphan_audit.py` y agregados al gate único. **No existe todavía extracción automática de snapshot transaccional, reparación atómica ni restauración O5 del almacén**: una discrepancia sólo se informa y requiere revisión manual; no se permite borrar automáticamente. Nuevo código pendiente de validación; uploads/downloads siguen desactivados, MFA no autorizado y BD persistente intacta.

## Reconciliación consultiva de PostgreSQL y cuarentena (pendiente validación)
`attachment_orphan_snapshot.py` obtiene en una consulta acotada (máx. 100 000) los UUID de objetos desde `RenewalAttachment` y los contrasta con el inventario cifrado privado; informa referencias sin objeto y objetos sin referencia. Usa una transacción de lectura para obtener el conjunto pero **no congela las escrituras concurrentes**, así que el resultado es meramente informativo y nunca autoriza borrar un objeto. No registra nombres de personas ni contenidos. Pruebas de base de datos ficticia y exceso de límite añadidas al gate integral (`test_attachment_orphan_snapshot.py`), todavía sin ejecutar sobre estos nuevos commits. No es una solución de restauración O5 ni de atomicidad ante caída.

## Endurecimiento del inventario de cuarentena — pendiente de gate
La auditoría offline limita ahora también el número de entradas físicas a 100 000 (además del límite del snapshot BD), rechaza un inventario demasiado grande antes de emitir informe y revalida permisos del directorio mediante su descriptor abierto. Añadida prueba de exceso de inventario y conservación de los archivos sin borrado. Código incorporado en la misma rama; **no ejecutado** sobre el commit nuevo. No incluye reconciliación duradera con escritores simultáneos, borrado seguro, recuperación automática ni activación de uploads.

## Worker de análisis y atestación — desarrollado, no validado
`attachment_scanner_worker.py` encadena lectura cifrada, comprobación de integridad/preinspección, escaneo mediante el adaptador y firma HMAC de resultado `clean`, validando la firma antes de devolverla. Casos `infected`, errores, mutación de metadatos y clave insuficiente quedan sin atestación. `release_allowed=False` es incondicional y no existen transiciones de estado BD. `test_attachment_scanner_worker.py` añadido al gate único PG17 + Flutter. **Importante:** el código sigue siendo una primitiva offline y depende de la segregación efectiva del proceso y de la clave, de clamd confiable con firmas al día, de auditoría/retención, de recuperación O5 y de la política de autorización futura. No se ha instalado servicio ni habilitado descarga. Gate posterior al último éxito aún no ejecutado.

## Pruebas adversarias del límite de liberación — nuevas, sin ejecutar
`test_attachment_release_boundaries.py` comprueba que una atestación limpia válida, incluso con la columna `state=clean`, nunca permite descargas mediante `may_download_attachment`; prueba también que una firma válida del objeto original no verifica sobre otro UUID. Añadida al único gate integrado. Esta prueba es una defensa regresiva; **no constituye una integración funcional de descarga ni confirma identidad operativa del escáner**. Nuevo código todavía pendiente de gate, sin tocar BD activa y con MFA sin autorización.

## Guard explícito de migraciones — código pendiente de gate
`backend/reminders/attachment_migration_guard.py` inspecciona el grafo Django con `MigrationLoader` y devuelve rechazo `MFA_DEPENDENCY_BLOCKS_ATTACHMENTS` si 0027 arrastra cualquiera de las migraciones 0019–0026 o si la ruta no contiene 0018. El gate integral exige ese rechazo antes de aplicar 0027 *sólo* en PostgreSQL efímero; `test_attachment_migration_guard.py` prueba el contrato negativo actual. **El bloqueo NO separa aún el grafo ni autoriza publicación**, simplemente dificulta promover por error el esquema MFA. Para separar de forma segura hará falta diseñar y verificar una estrategia de migraciones alternativa en entorno temporal y revisar guardas de despliegue existentes. Ningún comando de despliegue habilitado.

## Protección contra cambios entre análisis y firma — pendiente de gate
El worker offline compara los metadatos (UUID, SHA-256, tamaño, estado, nombre y MIME) antes y después de llamar al escáner; si alguno cambia, bloquea la firma incluso cuando la simulación devuelve `clean`. Tests nuevos alteran SHA-256 y estado durante el escaneo. Esto **sólo evita mutación del objeto en memoria en ese intervalo**: no proporciona bloqueo transaccional ni garantiza inmutabilidad del almacenamiento o de PostgreSQL concurrente. Para publicación serán obligatorias la vinculación al contenido real, la comprobación tras escaneo y la autorización externa. Código añadido a gate unificado, todavía no validado.

## Capacidades de adjuntos consumidas por Flutter (código pendiente del gate)
El endpoint de listado autorizado devuelve `capabilities.upload/download/delete=false` y razón `SECURITY_REVIEW_PENDING`. El cliente Flutter obtiene ese contrato por workspace/póliza con comprobación de tipos estricta; la ficha presenta el estado de seguridad y **no incluye acciones activas aunque se devuelvan permisos inesperados**. La API sigue rechazando POST/GET contenido/DELETE. Test de contrato añadido a `test_attachment_api.py`. Esta integración reduce la discrepancia entre frontend y backend pero no habilita carga/descarga ni demuestra seguridad operativa; pendiente gate conjunto. Sin cambios en servidor.
