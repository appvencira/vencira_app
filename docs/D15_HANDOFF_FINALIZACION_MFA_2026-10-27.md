# VENCIRA — Continuidad y finalización de MFA (27/10/2026)

## Situación actual

La fase de implementación y pruebas aisladas de MFA se ha cerrado según los resultados comunicados por el operador. El despliegue y la activación siguen pendientes. Última migración confirmada en PostgreSQL persistente: reminders.0018; migraciones MFA 0019–0026 ensayadas solo en entornos temporales.

Estado: MFA_RELEASE_AUTHORIZED=NO; MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO.

## Evidencias que no hace falta repetir

- Pruebas de TOTP, códigos de recuperación, bloqueos, sesiones, SQLite y PostgreSQL 17 temporal.
- Prueba con clave Fernet sintética en Docker y verificación local de custodia externa de la clave real, sin compartirla.
- Migraciones temporales 0018 a 0026 y vuelta sobre esquema vacío.
- Rechazo de un candidato sin protección MFA con cuenta sintética MFA activa, sin rollback destructivo.
- Protección estática de 16 scripts históricos y pruebas negativas.
- Puerta unificada de publicación con las operaciones schema-off, mfa-enable y rollback bloqueadas de forma intencional.

Consultar docs/D15_AUDITORIA_CONSOLIDADA_MFA_2026-10-27.md y docs/D15_CIERRE_MACROFASE_SEGURIDAD_MFA_2026-10-27.md.

## Cuándo retomar

Antes de incorporar datos personales reales, comenzar pruebas con usuarios reales o lanzar comercialmente el producto. El desarrollo funcional con datos ficticios puede continuar entretanto.

## Pendientes para terminar

1. Formalizar el riesgo de custodia individual y la política de pérdida total de factores. Sin verificación externa ni dos revisores humanos independientes, no habilitar restablecimiento administrativo de MFA basado solo en contraseña.
2. Completar pruebas manuales Android y escritorio, QR, códigos, ES/CA, bloqueo y recuperación. Revisar límites por IP/proxy, sesiones alternativas, alertas y requisitos RGPD.
3. Preparar un proceso de publicación verificable con controles sobre código candidato, estado de la base real en lectura, backups, restauración en clon y reversión sin eliminar MFA activo.
4. Solicitar autorización específica para desplegar esquema y código compatibles, manteniendo inicialmente el enrolamiento apagado.
5. Preparar la instalación segura del secreto Fernet mediante archivo protegido, sin imprimir ni enviar su contenido a chat, repositorio o logs; comprobar recuperación operativa con aprobación separada.
6. Solicitar autorización específica posterior para habilitar enrolamiento MFA y verificar activación progresiva. No confundir un OK general para desarrollar con autorización de producción.

## Estado final de la pausa

MFA_TECNICO_AISLADO=VALIDADO_SEGUN_EVIDENCIA_OPERADOR
MFA_OPERATIVO=INCOMPLETO
MFA_RELEASE_AUTHORIZED=NO
MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
