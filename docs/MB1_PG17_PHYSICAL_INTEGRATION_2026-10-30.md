# VENCIRA MB1 — Integración PG17 ORM y archivos físicos (30/10/2026)

Nueva batería focalizada `test_mb1_pg17_physical_integration.py`: Django TransactionTestCase sobre PG17 efímero del script de split, con registro real de `RenewalAttachment` en la BD de pruebas, fichero de objeto sintético, diario sintético y registro de digest **esperado tomado antes de leer ficheros**. Los cinco escenarios ensayan consistencia, manipulación de objeto, ausencia de objeto/diario y conflicto de lock cooperativo. Reutiliza verificador B18E y `IsolatedProcessFence`.

**Importante:** No hace `pg_dump`, no crea backup durable, no realiza `pg_restore`, no mantiene una instantánea transaccional real entre PG17 y archivos, ni bloquea escritores no cooperativos. Un resultado PASS certifica solamente lectura ORM+filesystem durante ensayo focalizado. La restauración B09E ya fue probada históricamente por separado; las dos pruebas NO demuestran automáticamente una captura/restauración integrada. El modelo de prueba contiene una identidad y dos hashes externos sintéticos; NO acredita autenticidad independiente, ni custodia externa.

## Gate único

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
MB1_PG17_PHYSICAL_ONLY=1 bash scripts/rehearse_c_ficha_split_readonly.sh
echo "MB1_PG17_PHYSICAL_EXIT_CODE=$?"
```

Esperado, solo después de ejecución: `MB1_PG17_PHYSICAL_ORM_TESTS=OK`, `MB1_PG_DUMP_RESTORE=NOT_RUN`, `MB1_NONCOOPERATIVE_WRITERS=NOT_BLOCKED`, `C_FICHA_FULL_SUITE=NOT_RUN`, `C_FICHA_SPLIT_PG17_RESULT=0`, `MB1_PG17_PHYSICAL_EXIT_CODE=0`. El script prepara esquema y crea su propia base de test en PG17 temporal, destruye contenedor y red internos al acabar; **no toca DEV**. No repetir los gates B18B–L ni tests físicos anteriores.

## Pendiente real de MB1

Implementar un orquestador de clon que detenga **todos** los procesos que pueden escribir en DB, objetos y diario, sea capaz de demostrar que la instantánea está estable durante `pg_dump` y empaquetado, verifique conjunto autenticado, recupere en PG17 destino diferente mediante B09E y tenga custodia de claves fuera del VPS. Hasta entonces `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

**Estado:** código preparado, prueba aún no ejecutada.
