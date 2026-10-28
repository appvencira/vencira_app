# C-FICHA — separación segura de migraciones (diseño previo a implementación)

## Hechos confirmados
- Producción/DEV persistente: reminders.0018 como último esquema confirmado.
- Rama MFA: reminders.0019–0026; no autorizada para despliegue.
- Adjuntos: reminders.0027 depende directamente de 0026, por lo que migrar a 0027 aplica MFA.
- El gate actual lo prueba en PG17 efímero y bloquea publicación; NO es una separación efectiva.

## Decisión arquitectónica recomendada
Crear una app Django independiente `renewal_attachments` con migración inicial `0001`, dependiente de `reminders.0018_draft_reasons` y `AUTH_USER_MODEL`. Mover la definición Python de `RenewalAttachment` y todas las importaciones al nuevo app, conservando las FK hacia `reminders.Renewal`.

**Requisitos del plan de transición:**
1. Garantizar que la nueva app no hereda dependencia alguna de reminders.0019–0026.
2. Preservar un esquema coherente en pruebas Django tanto desde 0018 como cuando la rama MFA esté presente.
3. Decidir el tratamiento de reminders.0027 **antes** de editarlo: ya forma parte de la rama publicada en GitHub y fue aplicada en clones temporales, no en persistente. Una modificación destructiva de la historia podría romper entornos de ensayo. Especificar transición con datos nulos/sintéticos y sin pérdida de registros.
4. No ejecutar `migrate` global de un contenedor que cargue la rama MFA mientras no esté autorizada: aplicaría 0019–0026 aunque la app de adjuntos fuera independiente. Requerir un entrypoint de migración explícito, auditable, con lista permitida y comparación de `migrate --plan`.
5. Probar en PG17 efímero el trayecto 0018→renewal_attachments.0001 y exigir que el registrador de migraciones no incluya reminders.0019–0026, ni que se cree ninguna tabla MFA.
6. Probar PG17 temporal con historial MFA completo en otro clon para asegurar coexistencia y evitar duplicados de tabla, sin activar MFA, ni usar claves reales.
7. Sólo después actualizar API, ORM, scanner y pruebas, más backup/restore y autorizaciones de publicación.

## Alternativa descartada para publicación automática
Cambiar `0027` a `0018` y añadir una migración merge en `reminders` dejaría rutas de hojas múltiples o un `migrate` global que arrastraría MFA al converger; no se considera una vía segura de publicación.

## Límites de autorización
No modificar el historial persistente, no instalar claves reales, no desplegar, no subir PII, no habilitar operaciones públicas. `MFA_RELEASE_AUTHORIZED=NO`.

## Estado
DISEÑO_DOCUMENTADO=SI
SEPARACION_IMPLEMENTADA=NO
MIGRACION_INDEPENDIENTE_VALIDADA=NO
AUTORIZACION_DEPLOY=NO
