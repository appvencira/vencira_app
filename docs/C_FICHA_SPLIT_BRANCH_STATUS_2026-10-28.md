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
