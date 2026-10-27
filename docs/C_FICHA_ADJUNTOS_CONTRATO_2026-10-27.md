# VENCIRA — Macrobloque ficha / contrato de adjuntos

## Verificación del código existente
Al 27/10/2026 no existen modelos, rutas API ni almacén de adjuntos de pólizas en la rama integration/local-e2e-prep. No confundir `policy_number`, `notes` o `RenewalAuditEvent` con archivo de fotografías/PDF.
Ya están resueltos y NO se duplicarán: validación de Entrada+Nombre+Vencimiento en `RenewalSerializer`, referencia técnica opcional; `_reset_reminder_template` de 60/45/35 al declinar; sugerencias explícitas por anotaciones visibles, sin CRM global; el Dashboard ya acepta `openTodayOnLoad`.

## Contrato pendiente de implementación por macrobloque vertical
1. `RenewalAttachment` vinculado a Renewal y workspace, ID UUID, nombre visible saneado, MIME validado, tamaño y hash calculados en servidor, objeto con identificador aleatorio y estado de escaneo. Actor de alta, fecha, y evento auditable sin nombre original sensible en logs.
2. Servicio de subida: sesión autenticada, CSRF, verificación de tenant + asignación mediante `_membership` y `_visible_renewals`, autorización al crear/leer/borrar. Máximo de tamaño/cuota como decisión de producto aún pendiente; aplicar valores temporales conservadores solo en pruebas, no presentarlos como precio/cuota comercial definitiva.
3. Detección por firma real, no confiar en `Content-Type` ni extensión. Solo PDF/fotos aprobadas, límites de páginas/megapíxeles, bloqueo de SVG, HTML y polyglots peligrosos. Antivirus/escáner o cuarentena sin servir objetos pendientes, control de ZIP bombs y descompresión de imágenes.
4. Almacén PRIVADO no accesible desde Nginx o Caddy ni desde `MEDIA_URL` público. Cifrado en reposo, permisos mínimos, claves y rotación documentadas, backups O5 alineados y recuperación/restauración ensayada. Jamás almacenar adjuntos como blobs en logs ni en git.
5. Descarga mediante endpoint autenticado y objeto autorizado, `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`, `Cache-Control: no-store` y acceso solo tras estado CLEAN. No generar enlace persistente ni incluir datos personales en la URL.
6. Eliminación lógica/auditada, retención y borrado físico coordinados con requerimientos RGPD y backup. No purga automática sin aprobación legal/operativa; cancelación de subidas y objetos huérfanos controlada.
7. Flutter web/escritorio: zona drag&drop y lista de adjuntos en ficha; móvil: cámara/galería/selector de documentos con permiso puntual. Verificar 320/375/768 y ES/CA, cargas interrumpidas, errores, progreso y recuperación; nunca lectura masiva de contactos.
8. Pruebas adversarias: anónimo, usuario de otro workspace, miembro no asignado, registro archivado, MIME falso, exceso tamaño, doble upload, objeto huérfano, descarga previa a escaneo, eliminación, XSS, CSRF, restauración PG17 y archivos, auditoría de rutas.

## Decisión de seguridad
**No habilitar cargas reales ni almacenar PII hasta** disponer del almacén privado cifrado, escaneo, régimen de conservación, revisión RGPD, pruebas aisladas y autorización de despliegue diferenciada. No prometer que un `FileField` sin estos controles es seguro.

## Desglose de trabajo no redundante
Macrobloque C-FICHA: modelo + migración + API + almacenamiento seguro + Flutter ES/CA + pruebas, seguido de un solo gate integral. Cambios de esquema se ensayan en PG17 clonado desde O5 antes de autorización explícita. No reabrir los gates MFA.

CONTRATO_DE_ADJUNTOS_DOCUMENTADO=SI
ADJUNTOS_IMPLEMENTADOS=NO
CARGAS_REALES_AUTORIZADAS=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO

## Primer avance de implementación (sin carga de archivos)
- Modelo `RenewalAttachment` y migración `0027_renewal_attachment_metadata` añadidos en rama de desarrollo: metadata vinculada a Renewal, identificador opaco y estado inicial `quarantined`.
- Pruebas sintéticas `test_attachment_metadata.py` para cuarentena por defecto, clave opaca única y bytes positivos. **No ejecutadas todavía**.
- Ninguna ruta API de upload/download, almacenamiento de bytes, antivirus, cifrado real o interfaz Flutter creada en este avance. No considerar funcionalidad lista.
- **Dependencia crítica:** la migración 0027 depende de 0026 MFA. La base persistente continúa en 0018; no aplicar 0027 al entorno vivo porque migraría también MFA 0019–0026. Antes de un futuro despliegue hay que acordar orden/estrategia de dependencias y los gates independientes.

## Resultado de validación comunicado por operador
El operador ejecutó en contenedor Docker aislado y SQLite temporal los tests `reminders.test_attachment_validation` y `reminders.test_attachment_metadata` tras integrar la migración 0027. Comunicó `OK`, destrucción de la base de pruebas y `RESULTADO_FINAL=0`. Se registra como validación de esas pruebas, no como revisión integral ni prueba PostgreSQL17. Sin publicación ni migración persistente. Pendiente gate PG17 temporal y validación del almacenamiento privado.

## Almacén privado cifrado — gate comunicado por operador
Tras el commit e95a3a6c70971d7947d04cbb80d9de716fa29573, el operador ejecutó las pruebas aisladas de validación, metadatos y almacén cifrado mediante Docker/SQLite de test. Resultado comunicado: `OK`, destrucción de base de pruebas y `RESULTADO_FINAL=0`. Esto acredita únicamente los casos sintéticos probados. Aún no existe API de subida/descarga ni escáner antivirus, y el almacén no se encuentra activado. Migración 0027 NO aplicada a PostgreSQL persistente. No repetir esta batería como paso aislado; incorporarla al futuro gate integral.

## Control de acceso a metadatos y bloqueo de descargas (código sin gate aún)
Se añadió `backend/reminders/attachment_gate.py`: el queryset de metadatos se limita a las anotaciones visibles para el miembro, con separación por workspace y asignación. `may_download_attachment` devuelve SIEMPRE falso, incluso si el estado se marca `clean`: aún no existe analizador/verificador de confianza y no se debe inferir seguridad desde un campo mutable. Pruebas sintéticas en `test_attachment_gate.py` cubren owner, miembro, otro workspace y rechazo con estado `clean`. **No hay ruta pública, API ni escáner activo**. Pendiente ejecutar los tests y construir un escáner aislado verificado antes de cambiar la denegación absoluta. Migración 0027 y PostgreSQL persistente sin desplegar.

## Gate del aislamiento de adjuntos — resultado aportado por operador
Después del commit 3b19746e93bff06d006e52fbc6fff79155937ed5 se ejecutó `reminders.test_attachment_gate` en contenedor Docker con SQLite temporal. El operador comunicó `OK`, destrucción de base de pruebas y `RESULTADO_FINAL=0`. Queda validado el alcance de autorización de metadatos y bloqueo incondicional de descarga de los casos de prueba. No equivale a escaneo, almacenamiento operativo, API o publicación. No repetir como prueba separada; incluir en gate integral. Sin cambios de PostgreSQL persistente.

## Preinspección estructural (pendiente de gate)
`attachment_content_inspection.py` añade preinspección conservadora PDF/JPEG/PNG sin instalar parser de terceros ni afirmar detección de malware. Comprueba truncamiento básico PDF/JPEG y chunks/CRC/dimensiones PNG. Su `release_allowed` siempre es `False`, también cuando la estructura parece correcta. **No es antivirus ni escaneo completo**: PDF puede contener contenido activo, JPEG requiere decodificador seguro, PNG requiere decodificación real y límites de memoria. `attachment_gate.py` sigue bloqueando descargas sin excepción. Pruebas sintéticas en `test_attachment_content_inspection.py`; pendiente validarlas. Sin endpoints ni exposición pública.

## Gate de preinspección — evidencia de operador
El operador ejecutó `reminders.test_attachment_content_inspection` después del commit `1d9c728a8399cf7629581a2ee1e90429e870d18a` y comunicó `OK`, `RESULTADO_FINAL=0`. Se consideran superados los tests estructurales sintéticos en el alcance ensayado; no se declara conformidad de parser, antivirus, aprobación para descarga o integración productiva. Sin despliegue ni migración persistente. Evitar repetir la batería aislada.

## Contrato de resultado de escáner — código pendiente de validación
Se incorporó `attachment_scan_contract.py` para verificar resultados firmados HMAC-SHA256 con clave independiente, identificador de objeto, SHA256, fecha de escaneo y dictamen `clean`. Rechaza firma incorrecta, objeto ajeno, digest alterado, fecha caducada/futura, estado infectado/error y campos extra. Tests sintéticos en `test_attachment_scan_contract.py`. **No hay un escáner antivirus instalado ni resultados reales acreditados**: quien posea la clave de firma puede emitir cualquier dictamen, de modo que el proceso emisor deberá ser aislado, autenticado, auditado y estar sujeto a controles propios. El validador de firma no garantiza por sí solo la seguridad del archivo. `may_download_attachment()` sigue denegando SIEMPRE. No se ha habilitado API, almacenamiento persistente ni cambio de estado.

## Gate de contrato firmado — evidencia operador
El operador comunicó `OK` y `RESULTADO_FINAL=0` para `reminders.test_attachment_scan_contract`, tras commit `5d95b381efb9a39f5960224a7d38786b71998224`. El gate solo cubre verificaciones sintéticas de firma, identidad, dictamen y caducidad, no despliegue de antivirus ni habilitación de descarga. No repetirlo por separado; integrarlo en gate final. Sin despliegue o migraciones persistentes.

## Adaptador ClamAV aislado — pendiente de gate
`backend/reminders/attachment_clamav_adapter.py` implementa cliente INSTREAM para socket Unix de un futuro clamd aislado: límites de tamaño, plazo de respuesta y resultado `error` ante fallo, protocolo incorrecto o ausencia de servicio. `test_attachment_clamav_adapter.py` usa socket simulado, sin lanzar antivirus ni conectarse a la red. Un `clean` es solo `CLAMD_OK_UNATTESTED`, no certificado firmado, no promoción del estado y **no autoriza descarga**. Pendiente: desplegar motor aislado con definiciones actualizadas y política de actualización, cuotas CPU/RAM, aislamiento, pruebas EICAR y de formatos maliciosos, firma de veredictos en proceso protegido, integración cifrado+BD+API y validación PG17. El socket no está configurado en producción.

## Gate del adaptador ClamAV simulado — evidencia operador
Tras commit `d9d55717557051fc1c3d29c58624efb400c2bfaf`, el operador comunicó `OK` y `RESULTADO_FINAL=0` para `reminders.test_attachment_clamav_adapter`. Prueba de socket simulado; ClamAV real, definiciones, detección EICAR y despliegue permanecen PENDIENTES. Sin despliegue ni migraciones en BD persistente. No repetir test aislado; incluirlo en gate integral.

## Ensayo real ClamAV preparado, NO ejecutado todavía
`scripts/rehearse_clamav_real_isolated.sh` descarga imagen oficial `clamav/clamav:stable` (con bases preincluidas) y realiza un único escaneo `clamscan` en contenedor **sin red**, sin privilegios, con raíz de solo lectura y límites de memoria/CPU, sobre dos archivos sintéticos: texto limpio y firma EICAR de prueba, no malware. Un código 1 con detección EICAR y texto limpio es el resultado correcto. Falta ejecutar el ensayo y confirmar frescura de firmas: la imagen `stable` es mutable y la base preincluida puede no estar actualizada. Este ensayo NO prueba el adaptador socket Unix/clAMd de punta a punta, no autoriza escaneo productivo, ni cambia el bloqueo de descargas, las migraciones o los contenedores activos. No conectar documentos reales hasta verificación de arquitectura y RGPD.

## ClamAV real aislado — prueba aprobada
Operador confirma ejecución de `scripts/rehearse_clamav_real_isolated.sh` con commit `27c8952e3bddab2dac116c39a143da0fb6f6734a`: `CLAMAV_EICAR_FIXTURE_BYTES=68`, `CLAMAV_IMAGE_PULL=OK`, `CLAMAV_CLEAN_FIXTURE=OK`, `CLAMAV_EICAR_DETECTION=OK`, `CLAMAV_CONTAINER_NETWORK_DISABLED=1`, `CLAMAV_NO_PRODUCTION_CHANGE=1`, `CLAMAV_REAL_ISOLATED_RESULT=0`, `RESULTADO_FINAL=0`. La primera prueba fallida se debió al patrón EICAR con barra adicional y se corrigió. Esta evidencia verifica detección EICAR aislada, no actualización de firmas, daemon clamd/Unix, política de cuarentena real o permisos de descarga. Sin cambios en PostgreSQL persistente. Evitar repetir el ensayo aislado salvo modificación de la configuración del motor.

## Orquestación cifrado→huella→preinspección→escáner (pendiente gate)
`backend/reminders/attachment_scan_pipeline.py` obtiene únicamente bytes cifrados del almacén local mediante su interfaz de lectura para escáner, comprueba SHA-256 y tamaño frente a metadatos, realiza la preinspección estructural y llama al adaptador. El resultado NO firma atestaciones, NO cambia el estado BD y siempre incluye `release_allowed=False`, incluso con `clean`. Pruebas sintéticas `test_attachment_scan_pipeline.py` cubren limpio, infectado, error, discrepancia de huella/tamaño y objeto ausente. Este bloque NO demuestra servicio clamd vivo mediante socket ni autoriza adjuntos reales. No hay endpoint ni despliegue. Pendiente validación aislada y PG17 temporal; la migración 0027 sigue condicionada por MFA 0026.

## Gate de orquestación de cuarentena — validado según operador
Con el commit `e5fcf5bb29dd5f0f510541fefedf3a330609840d`, el operador ejecutó `reminders.test_attachment_scan_pipeline` en Docker de prueba y comunicó `OK`, `RESULTADO_FINAL=0`. Se acreditan únicamente casos sintéticos de lectura cifrada, coincidencia SHA-256/tamaño, rechazo de discrepancias/objeto ausente y propagación de resultados simulados, con descarga siempre bloqueada. No demuestra socket clamd real, integración API ni aprobación de archivos. PostgreSQL persistente permanece sin migración 0027. No repetir el gate aislado.
