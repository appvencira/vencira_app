# VENCIRA — Anotación externa: Entrada y Modalidad (etapa segura)

**Fuente revisada antes de programar:** `White_paper_agenda_vencimientos.pdf`, 18 de octubre de 2026, §1, §2, §5, §6, §12, §13. El whitepaper es la referencia funcional, aunque quedan diferencias declaradas con el MVP.

## Objetivo de esta iteración

Avanzar del prototipo «Referencia + vencimiento» hacia la **anotación de póliza externa**, sin introducir todavía nombres, teléfonos, emails, fotos, pólizas ni datos personales reales en el servidor de desarrollo, mientras no se complete el cifrado en almacenamiento, cumplimiento RGPD y controles de archivo/borrado del §12.

- **Entrada**: `clients` = Clientes (póliza que el propio cliente tiene fuera), `prospects` = Candidatos (futuro cliente). Las dos entradas son distintas, **no dos fichas CRM**.
- **Modalidad**: campo textual opcional de 80 caracteres, con catálogo inicial del whitepaper: Autos, Motos, Patinetes, Hogar, Comercio, Decesos, Salud, Vida, Accidentes, Responsabilidad civil, Comunidades, Otros. Los valores básicos se guardan como códigos independientes del idioma; el diálogo Flutter los presenta traducidos en ES/CA. La **lista editable por cuenta** del whitepaper no está implementada todavía; existe una opción Otros, sin editor de catálogo.
- **Antiguos registros:** ambos campos quedan sin clasificar o vacíos; **no inferir tipo automáticamente** a partir de una referencia como `DEMO-HOGAR` o por la modalidad. Una migración `0008_renewal_entry_modality` añade solo columnas y no borra datos. El editor deja elegir Entrada cuando se crea una anotación desde Flutter; puede clasificar una antigua al editarla.
- La API acepta transitoriamente `entry=null` o ausente **solo** para retrocompatibilidad de clientes previos. Si se envía `entry` con valor no permitido o vacío/null explícitos, se rechaza. Antes de V1 se deberá migrar datos legados y **exigir Entrada en todas las altas de API**.
- El listado principal y las tarjetas de agenda identifican la Entrada con un color/categoría, mientras los puntos diarios/semanales/mensuales mantienen el código de tipo de evento (`expiry`, `notice_deadline`, `reminder`). En la fase final habrá que diseñar conjuntamente el color **de Entrada** que exige el whitepaper y la señalización temporal, sin confundir uno con otro.
- Los cambios se auditan por **nombre del campo** y nunca se copian valores de texto de la póliza o de su modalidad al historial. No se altera el control de permisos ni la asignación.
- El campo actual `customer_reference` se conserva como **referencia técnica de prueba**. El documento exige que más adelante se sustituya/complemente por `Nombre y apellidos o razón social`, obligatorio, además de Nick, Teléfono, Email, Número de póliza, Aseguradora, Notas y Archivos, como registros independientes de pólizas externas.

## Riesgos y siguientes decisiones

1. La captura de datos personales reales **no está autorizada** en `dev.vencira.es` con esta mejora. Validar cifrado en reposo, claves, backups UE, controles de acceso, bloqueo y retención del §12 antes.
2. La lista de Modalidad por cuenta (añadir, editar, borrar) es una iteración posterior, preservando denominaciones localizadas y la referencia estable en cada anotación.
3. El selector de Aseguradora y su lista pública requiere una fuente fiable y mantenimiento; no se ha añadido con este cambio.
4. La anotación V1 necesita **Entrada y Nombre obligatorios**, sugerencias para copiar datos de otras anotaciones **dentro de la misma cuenta**, y integración voluntaria de contactos móviles; nunca acceso masivo a la agenda.
5. Los cierres §9, avisos §7/8, adjuntos, QR, campos de persona y archivo §12 permanecen pendientes; no inferir entregas a partir de avisos previstos.

## Verificación

- Django: migrations `--check`; SQLite + PostgreSQL 17; legacy nulo, creación Candidato, cambio a Cliente, auditoría sin valores, rechazo de valores manipulados, aislamiento de organización.
- Flutter: selecciones Entrada/Modalidad en ES/CA, tamaños móviles, envío de códigos estables, tarjeta con entrada y detalle actualizado.
- Docker E2E: `smoke_same_origin`; despliegue controlado en `vencira_localcheck` con copia de seguridad de PostgreSQL, `git pull` SSH y recreación de `api` + `web_preview`, nunca `down -v`.
- No tocar Caddy, el proyecto anterior `vencira_preview` ni contraseñas.

## Estado

**Código en rama de integración**, no desplegado hasta que GitHub Actions confirme todos los trabajos del commit exacto. Una vez desplegado, probar exclusivamente `PRUEBA-...` y registros sintéticos.
