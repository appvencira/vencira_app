# VENCIRA — Preparación de adjuntos (sin activación)

Estado: diseño. **No se admite subir ni descargar documentos todavía.**
Cada documento corresponderá a **una anotación** (póliza externa), nunca a una ficha compartida de cliente.

## Contrato propuesto antes de activar almacenamiento

- ID aleatorio de documento y vínculo inmutable a `Renewal`, cuya organización debe coincidir con la organización autorizada.
- Nombre visible corto definido por el usuario (ej.: Póliza, Recibo); no usar el nombre original como clave de almacenamiento.
- Lista permitida: PDF, JPEG, PNG; validar tipo por contenido, no exclusivamente por extensión o cabecera HTTP.
- Límites de tamaño por archivo, cuota por cuenta y política de retención: **pendientes de decisión**. Rechazar archivos antes de reservar espacio si superan los límites.
- Guardar fuera de los directorios servidos por Nginx, con claves opacas y permisos mínimos.
- Descarga únicamente a través de una vista autorizada; aplicar **el mismo filtro de cuenta y usuario asignado** que `_visible_renewals`, antes de buscar el adjunto. Responder 404 para documentos ajenos.
- No incluir nombres, textos o rutas del documento en la auditoría, logs, excepciones ni analítica.
- Cifrado en reposo con gestión de claves separada, cifrado de backups y procedimiento de recuperación verificado.
- Analizar documentos maliciosos, bloquear ejecución y contenido activo; devolver Content-Disposition attachment, X-Content-Type-Options nosniff y Cache-Control no-store.
- Validar permisos para alta, listado, lectura y eliminación; protección CSRF/sesión y anti-abuso.
- Política de borrado, retención, derecho de supresión, exportación, y acuerdo de encargado de tratamiento antes de uso real.
- En móvil, pedir acceso únicamente a la fotografía o fichero seleccionado; no leer contactos ni archivos de forma masiva.
- No conectar IA/OCR externa sin contrato y garantías RGPD.

## Barrera de lanzamiento

No activar API de adjuntos ni aceptar datos personales reales sin pruebas de acceso entre organizaciones, usuarios asignados y cambios de titular, cifrado y recuperación, límites, borrado y revisión RGPD. El diseño actual no supone que esos controles estén implementados.
