# MB1 — Clasificador conservador de estados incompletos

30/10/2026. Implementado, pendiente de ejecutar.

El módulo `offline_recovery_classifier_mb1.py` clasifica la presencia de un UUID en diario de intención, objeto cifrado y metadatos PostgreSQL, incluidos los seis estados incompletos posibles y el completo. Devuelve **solo contadores**, no identificadores, nombres ni información de clientes. Rechaza inventarios mal formados y fija siempre `repair_authorized=False`, `deletion_authorized=False`, `release_authorized=False`, `content_verified=False` y `consistent_snapshot_verified=False`.

La suite `test_recovery_classifier_mb1.py` prueba nueve casos, incluidos inventarios vacíos, todas las combinaciones, bloqueo de reparaciones y errores en formatos. El nuevo módulo es **clasificador puro**, no lee volúmenes ni abre conexiones DB. Todavía NO se ha integrado en un inventario PG17 de captura estable. No ejecuta reparaciones ni habilita adjuntos.

## Validar en VPS (solo Docker efímero sin red)

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
sudo bash scripts/validate_mb1_recovery_classifier.sh
echo "MB1_CLASSIFIER_EXIT_CODE=$?"
```

Un éxito acreditará las reglas de clasificación, **no** resolución de huérfanos ni coherencia global. No tocar DEV, ni eliminar objetos/diarios, ni migrar PostgreSQL persistente. Los siguientes gates: conectar al inventario real del laboratorio sobre un corte estable; introducir clasificador de estado/digest; realizar simulación de fallos de proceso/DB y decidir reconciliación conservadora. Después excluir escritores y custodiar claves fuera del VPS.

```text
MB1_CLASSIFIER_TESTS=PENDING
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MB1_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED
MB1_RELEASE_AUTHORIZED=NO
```


## Primera ejecución: fallo de preflight Django, corregido

La primera prueba abortó antes de cargar los tests con `ImproperlyConfigured: Falta DJANGO_SECRET_KEY aleatoria (>=32 caracteres)` y `MB1_CLASSIFIER_EXIT_CODE=1`. El ejecutor aportaba una cadena sintética demasiado corta. Commit `5978262`: sustituida por una cadena de prueba suficientemente larga, sin credenciales operativas. **Corrección pendiente de reejecución**. Este error no constituye un fallo funcional del clasificador ni implica modificaciones en DEV.


## Revalidación del operador — PASS

La revisión corregida finalizó con `Ran 10 tests in 0.001s`, `OK`, `MB1_READONLY_CLASSIFIER_TESTS=OK`, `MB1_CLASSIFIER_AUTOMATIC_REPAIR=DISABLED`, `MB1_CLASSIFIER_LIVE_INVENTORY=NOT_CONNECTED`, `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `MB1_CLASSIFIER_EXIT_CODE=0`. El cómputo real es 10 tests, no los 9 originalmente estimados. Se confirma solo el clasificador de inventarios sintéticos; no hay integración live ni funciones de reparación.


## M1-01 confirmado y M1-02 iniciado

M1-01 PASS del operador: `MB1_INTEGRATED_PG17_ORPHAN_CLASSIFICATION=OK`, `MB1_INTEGRATED_AUTOMATIC_REPAIR=DISABLED`, `MB1_INTEGRATED_RESULT=0`, `MB1_INTEGRATED_EXIT_CODE=0`; checklist maestra marcada en commit `080da9f`.

M1-02 primera etapa (pendiente de ejecutar): commit `4ee70a9` introduce una prueba que mata **realmente** con SIGKILL dos procesos de escritura en un directorio aislado, después de `fsync` del diario y después de guardar además el objeto cifrado mediante implementaciones reales. El padre constata código `-SIGKILL`, clasifica `intent_only` e `intent_and_object_without_metadata`, y no autoriza borrar/reparar/liberar. El runner de clasificación, commit `38b3d39`, ejecuta también esa suite. Esta prueba **no** usa PostgreSQL, no corta en mitad de la escritura y no acredita un snapshot consistente ni reconciliación reparadora. M1-02 sigue [ ] hasta ensayar fallos/recuperación completos sobre PG17 y volúmenes.
