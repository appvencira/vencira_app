# VENCIRA — Macrofase D · Seguridad y preparación para datos reales

Fecha: 26/10/2026. Estado: **D0 auditoría de solo lectura / pendiente de verificación ejecutable**.

## Punto de partida

- El promotor confirma «Done; siguiente macrofase» tras la última iteración UX premium y sus gates, sin transcribir en este turno el recibo final completo de despliegue. No sustituir la confirmación por una salida inventada.
- El último esquema persistente comprobado en la sesión es `reminders.0018_draft_reasons`. No se autorizan migraciones ni modificación de datos reales.
- Whitepaper original §§3, 4, 12, 16 y 18: organización Individual/Equipo, permisos y aislamiento, acceso seguro y MFA, almacenamiento/adjuntos, privacidad RGPD, retención/borrado, backups y recuperación, offline nativo. **No usar datos personales reales hasta superar gates técnicos y jurídicos.**

## D0 — Inventario y matriz de riesgos (primero, sin alteraciones)

1. Identidad y sesiones: login, cookies, CSRF, recuperación, MFA, revocación de sesiones y controles de fuerza bruta. Identificar código y pruebas reales, clasificar hallazgos.
2. Autorización multiempresa: permisos owner/member, usuario asignado, controles de escritura/lectura, exportaciones, historial, borradores y endpoints C2. Probar denegación cruzada con datos sintéticos.
3. Datos personales: minimización de campos, backups, adjuntos deshabilitados, cifrado en tránsito y reposo, logging sin secretos, eliminación, retención y derecho de acceso.
4. Continuidad O5: verificación de snapshot cifrado, restauración periódica en PostgreSQL efímero, RPO/RTO definidos, monitorización de fallos; sin revelar claves.
5. Cadena de suministro: dependencias Django/Flutter, imágenes Docker, configuración de producción, cabeceras, secreto en entorno y análisis estático de repositorio.
6. Exigencias jurídicas: responsable/encargados, bases legales, ubicación del alojamiento y subencargados, contratos, políticas RGPD/LOPDGDD; revisar con asesor jurídico.

## D1 — Hardening (solo después de D0)

- Priorización P0/P1/P2 con evidencia por archivo/test.
- Implementar controles de autenticación/MFA y pruebas de autorización por tenant.
- Acordar política de retención/borrado y adjuntos privados antes de schema changes.
- No activar Resend, correo, push o almacenamiento nativo hasta gate independiente.

## D2 — Validación

- Tests aislados Django SQLite/PG17, Flutter ES/CA, threat model y matriz de denegaciones, O5 backup/restore aislado.
- Sin despliegue, sin migración real y sin tocar Caddy, OAuth o Restic hasta autorización expresa.
- Comprobar en móvil accesibilidad sin reducir la UX premium aprobada.

## D3 — Publicación protegida

- Pin de versión probada y auditoría de diferencias de fuentes; respaldo y rollback.
- Despliegue DEV aislado; revisión de seguridad y aceptación; **producción y datos reales siguen bloqueados**.

## Primer paso ejecutable

Revisión GitHub de estructura de auth/permissions y tests actuales. Crear informe D0 con evidencia y severidad, sin cambios operativos.

## Contrato de continuidad

Mantener `docs/NEXT_CHAT_HANDOFF_SHORT.md` y `docs/CONTINUITY_RUNBOOK.md` actualizados. No convertir VENCIRA en CRM ni registrar un aviso interno como notificación enviada.
