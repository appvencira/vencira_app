# VENCIRA — B18: recuperación integral, análisis de brechas (29/10/2026)

**Rama:** `feature/c-ficha-independent-attachments`. **Naturaleza:** inspección de código en GitHub; no se ejecutaron pruebas nuevas, Docker, PostgreSQL ni accesos al VPS.

## No duplicar B07–B09

Se inspeccionaron las siguientes implementaciones reales:

- `backend/renewal_attachments/b09e_integral_gate.py`: gate de conjunto cifrado y recuperación sobre BD PG17 efímera; crea manifiesto HMAC, envuelve dump cifrado y paquete de objetos+diario; verifica ORM, contenido y diario tras restaurar; casos negativos de clave, paquete y snapshot incorrecto.
- `offline_backup_manifest_b09.py`: liga huellas de DB y paquete a identificadores de snapshot y claves y autentica mediante HMAC. La clave de autenticación de prueba no sustituye custodia externa.
- `offline_verified_restore_b09.py`: verifica identidad del conjunto, recupera volcado, reconcilia bytes de objetos/diario; siempre devuelve `release_authorized=False`.
- `offline_backup_contract.py`: exige emparejamiento entre objeto cifrado y diario y verifica digest con inventario externo.
- `offline_capture_fence.py`: compara marcadores e inventarios; **no impone barrera de escritura**.
- `offline_write_barrier_b06b.py`: lock consultivo cooperativo exclusivo/compartido únicamente bajo `VENCIRA_ENV=test` y PG17; **escritores operativos no participan**.
- `b08bc_restore_harness.py`: recuperación temporal y tests negativos de clave, digest, snapshot y manipulación.

**Conclusión:** ya existe un ensayo integral sintético; no programar un B18 que simplemente repita B09E.

## Brechas que sí impiden operación

| Puerta | Estado verificado por inspección | Acreditación aún necesaria |
| --- | --- | --- |
| Conjunto DB+objeto+diario vinculado | Implementado B09E, pendiente revalidar contra commit actual solo si cambió código | Evidencia de ensayo correspondiente y restauración coherente en medio independiente |
| Barrera sobre todas las escrituras | **BLOQUEADO**; `offline_write_barrier_b06b` reconoce alcance test-only | Captura sin escritores no cooperativos, definición del punto de corte, recuperación tras caída |
| Consistencia de instante entre `pg_dump`, objetos y diario | **BLOQUEADO**; un mismo snapshot_id en manifiesto no prueba atomicidad | Coordinador con freeze/quiesce efectivo, journal/outbox estable, pruebas de carreras/fallos |
| Inventario independiente y durable | Modelo experimental | Catálogo cifrado, firmado o autenticado, versionado y conservado por custodio externo |
| Claves antiguas y rotación | **BLOQUEADO** | Restauración de backups históricos con versiones de claves y evidencia externa real |
| Copia fuera de VPS con retención independiente | O5 acredita copias PostgreSQL, no archivos | Backup cifrado de objetos/diario, prueba de ubicación separada y coherencia temporal |
| Recuperación con destrucción total del VPS | **BLOQUEADO** | Restauración aislada BD+objetos+diario+claves; verificación y objetivos RPO/RTO |
| RGPD y rollback operativo | **BLOQUEADO** | Política de retención/borrado y aprobación explícita |

## Orden de ejecución B18

1. **B18A:** auditar todos los caminos de escritura efectivos contra protocolo de captura, marcando cualquier escritor sin barrera como blocker; no basta contar locks en el receptor B17. Diseñar protocolo de captura consistente, sin integrar en DEV.
2. **B18B:** añadir prueba negativa de carreras/corte usando PG17 efímero, simular escritura concurrente y caída entre BD y objeto/diario; exigir fail-closed y limpieza. Reusar pruebas previas de B06/B09, no duplicar.
3. **B18C:** demostrar recuperación desde un conjunto sintético en almacenamiento distinto del contenedor fuente, claves ficticias independientes y restauración en clon, incluido desastre parcial y reconciliación.
4. **B18D (humano):** custodia real fuera del VPS, retención/recuperación de claves antiguas, RPO/RTO y aceptación formal independiente de MFA/adjuntos.

## Condiciones invariables

```text
B18_DOCUMENTARY_GAP_ANALYSIS=COMPLETE
B18_RUNTIME_GATE=NOT_RUN
B18_INTEGRAL_OPERATIONAL_RECOVERY=NOT_VERIFIED
B18_RELEASE_AUTHORIZED=NO
B17_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

No ejecutar `migrate` global, tocar `reminders.0027`, montar claves operativas, abrir puertos ni activar endpoints de adjuntos. Proteger el archivo local `clients/flutter/pubspec.lock` sin versionarlo.
