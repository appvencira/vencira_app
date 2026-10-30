# MB1 — decisión de cierre de recuperación integral (30/10/2026)

## Evidencia real ya existente

- B09E ensayó `pg_dump -Fc` de PostgreSQL 17 efímero, cifrado del dump, paquete de objetos cifrados y diario, manifiesto HMAC, validación antes de `pg_restore`, segundo PG17 independiente y reconciliación ORM. Tiene negativos de mezcla de paquetes y clave incorrecta; véase `docs/B09E_INTEGRAL_RESTORE.md`.
- B18B D10, B18C, B18D, B18F y B18G pasaron sus gates focalizados reportados. B18C demostró el bypass de locks consultivos; B18D/F verificaron locks SQL limitados y su incapacidad para inmovilizar filesystem. B18E (12 tests), MB1 contratos (41 tests) y B18L (8 tests) pasaron, todos sintéticos.
- B18H–K obtuvieron inventarios y controles estáticos: 264 candidatos en 76 archivos, 131 P0 en 34 archivos, 131 contextos generados y cinco parejas de llamada vigiladas, cero nuevas parejas detectadas en el gate. **No significa 131 revisadas**.
- B18J2 examinó seis módulos de escritura y encontró dependencia de barrera desde el llamador y persistencia de intenciones que requieren conciliación.

## Bloqueador principal que las pruebas parciales no eliminan

No hay garantía transversal de que **toda escritura de BD, objetos y diario** esté suspendida en el mismo instante del snapshot. Una `pg_dump` coherente de PostgreSQL no representa un corte coherente con filesystem. Los locks `ACCESS EXCLUSIVE` no protegen archivos y pueden bloquear lecturas; los advisory locks solo cubren participantes. `drained=True`, `registered_writers` y los inventarios sintéticos no son prueba de un corte real. Custodia de claves externa, streaming de grandes bases, política anti-rollback y soporte de recuperación independiente también siguen pendientes.

## Decisión para acelerar sin garantías falsas

**No introducir nuevos cierres experimentales B18N/B18O que se limiten a comprobar otro fragmento de locking.** Concentrar la implementación en dos artefactos grandes:

### MB1-FREEZE — orquestador de captura del entorno aislado

1. Inventariar y **prohibir** entradas de escritura: API, tasks/workers, shell, SQL directo, almacenamiento de objetos y diario. El inventario estático es punto de partida, nunca certificación.
2. Aislar un clone PG17 y un volumen de datos **sintéticos**, con red privada y sin conexiones al DEV persistente. Iniciar producción de datos por un único proceso controlado.
3. Cambiar a modo mantenimiento y **detener físicamente** todos los escritores del clon (no solo locks cooperativos). Verificar que han terminado, que no existen sesiones escrituras activas y que no quedan handles escritores al volumen.
4. Hacer snapshot de BD y archivos mientras los escritores están detenidos. Mantenerlos detenidos hasta cerrar, sincronizar y autenticar el inventario DB+objetos+diario; escribir un identificador de época y capturas.
5. Si aparecen sesiones externas, cola pendiente, epoch divergente, errores, escritura nueva o archivo fuera del inventario, abortar y registrar `CAPTURE_REJECTED`. Nunca publicar backup como recuperable.

### MB1-RESTORE — desastre simulado sin datos reales

1. Separar artefactos cifrados de las claves en contenedores/volúmenes temporales diferentes.
2. Recrear un PG17 vacío en una segunda red y restaurar **solo después** de validar autenticidad/frescura del conjunto.
3. Confrontar filas ORM y bytes cifrados, diarios y huellas de contenido. Probar caída entre diario/objeto/BD y rechazar pares ausentes o inventarios desfasados.
4. Registrar `RPO/RTO` medido y evidencias de destrucción del clon, sin tocar DEV, O5 ni migraciones persistentes.
5. **No elevar a operativa** hasta custodia independiente real de claves y autorización humana de backups, restore, MFA y adjuntos.

## Criterios de aceptación

Se requieren: revisión demostrable de los escritores efectivos (incluidos fuera del código Python), fail-closed ante cualquier writer no controlado, evidencia de corte durable DB/objetos/diario en un clon, restore verificado en otro PG17, inyección de fallos durante freeze/snapshot/restore, y prueba de claves fuera del VPS. La cobertura P0 sigue sin ser auditada íntegramente, y no está resuelta por la mera existencia del informe de 131 contextos.

## Estado sin cambios operativos

```text
MB1_B09E_SYNTHETIC_RESTORE=HISTORIC_PASS
MB1_GLOBAL_FREEZE=NOT_IMPLEMENTED
MB1_INDEPENDENT_EXTERNAL_CUSTODY=NOT_VERIFIED
MB1_OPERATIONAL_DR=BLOCKED
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

Este documento es diseño de implementación y no proclama ejecución de MB1-FREEZE ni MB1-RESTORE. Sin intervención sobre DEV ni servicios vivos.
