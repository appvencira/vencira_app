# VENCIRA — Revisión de seguridad previa a datos personales reales
Fecha: 2026-10-22. Estado: **NO APTO PARA DATOS REALES / NO AUTORIZADO PARA PRODUCCIÓN**.

## Evidencia revisada

- `backend/config/settings.py`: sesiones Django, CSRF, cookies HttpOnly/SameSite, opción Secure detrás de proxy confiable, hostnames explícitos, validación de claves y HTTPS obligatorio en modo production.
- `backend/reminders/views.py`: alcance por workspace y usuario asignado para lecturas y escrituras de anotaciones; aislamiento con 404, transacciones y auditoría.
- `docs/SECURITY.md`: declara MFA, recuperación de cuentas, políticas RGPD, retención y backups externos todavía pendientes.
- `compose.yaml`: PostgreSQL en red interna y sin puerto publicado; API solo en loopback; volúmenes locales. No demuestra cifrado de volumen ni backups.
- `docs/ATTACHMENTS_SECURITY_GATE.md`: alcance de almacenamiento documental **solo en diseño**; no existe API de upload/download.

## Controles superados en CI de desarrollo

- `makemigrations --check --dry-run`, suite Django con SQLite y PostgreSQL 17, Flutter analyze/test/build y web same-origin con CSRF.
- Las pruebas funcionales no sustituyen pentest, auditoría legal ni revisión del servidor real.

## Bloqueantes de uso real

1. **Cifrado en reposo** no acreditado para PostgreSQL, copias externas ni documentos; decidir controles y verificar restauración.
2. **MFA y recuperación de acceso** pendientes; protección de login distribuido y Django Admin sin validación suficiente.
3. **RGPD/LOPDGDD**: identificar responsable y encargados, base jurídica, contrato de tratamiento, información y consentimientos cuando procedan, retención, exportación y supresión.
4. **Adjuntos**: sin límites definitivos, aislamiento de almacenamiento, antivirus, cifrado, autorización de descargas ni pruebas de acceso cruzado; mantener cargas deshabilitadas.
5. **Permisos y auditoría**: revisión independiente de roles, acceso técnico, registro de eventos administrativos y retención de logs.
6. **Operación**: automatizar backup/restauración cifrada, monitorizar y comprobar seguridad del despliegue TLS, dependencias y secretos.

## Decisión

La fase de desarrollo puede probarse con **datos sintéticos exclusivamente**. No marcar VENCIRA como producto listo para información personal real hasta aportar evidencia verificable de los seis puntos. Este informe no certifica seguridad ni cumplimiento normativo.
