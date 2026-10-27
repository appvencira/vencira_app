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
