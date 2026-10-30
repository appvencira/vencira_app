# MB1 — restauración desde soporte aislado (30/10/2026)

**Estado:** preparado en GitHub, pendiente de validación por el operador.

Se ha ampliado el ensayo E2E de dos PG17 para que la recuperación no lea ficheros del origen. Tras crear un paquete cifrado autenticado y probar rechazos de integridad, el script crea un segundo directorio privado de ensayo, copia **solamente** `capture.enc`, `manifest.json`, `manifest.mac` y claves sintéticas a ese directorio y elimina `source.dump`. El contenedor de recuperación monta únicamente ese segundo directorio, con red desactivada. La restauración abre el paquete tras verificar HMAC y digest, extrae objeto y diario a `recovered/`, contrasta sus bytes con los originales de ensayo y transmite el PG dump descifrado al **PostgreSQL destino efímero**, sin montar ningún fichero de origen. Se elimina el directorio temporal de recuperación en el trap. El árbol original del ensayo bajo /tmp se conserva para diagnosis con permisos de usuario, como sucedía antes.

**Limitaciones:** el segundo directorio permanece en el MISMO VPS y las claves sintéticas se copian con el paquete. Por tanto, esto demuestra independencia lógica de rutas de origen, **no** custodia real independiente ni supervivencia a pérdida de servidor. El origen PG17 de ensayo se mantiene vivo pero sin red y sin escritores de aplicación; no se demuestra congelación universal del host. Tampoco prueba anti-rollback ni tamaño de producción.

Gate único (no repetir anteriores):
```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_E2E_DETACHED_EXIT_CODE=$?"
```

Marcadores nuevos esperados: `MB1_E2E_DETACHED_RECOVERY_MEDIA=OK`, `MB1_E2E_DETACHED_OBJECT_JOURNAL=OK`. Permanecen `MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_OPERATIONAL_RELEASE=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.

Siguiente hito real de MB1: acreditar credenciales de recuperación bajo custodia independiente fuera del VPS, diseñar y comprobar aislamiento efectivo de **todos** los writers BD/objetos/diario y ensayar recuperación con borrado del origen en un clon, no más gates por componente.


## Resultado de ejecución — 30/10/2026

Operador: `MB1_E2E_DETACHED_RECOVERY_MEDIA=OK`, `MB1_E2E_DETACHED_OBJECT_JOURNAL=OK`, `MB1_E2E_REAL_PG_DUMP_RESTORE=OK`, `MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=OK`, `MB1_E2E_WRONG_KEY_AND_TAMPER_REJECTED=OK`, `MB1_E2E_RESULT=0`. También `MB1_E2E_SOURCE_NETWORK_INGRESS_DENIED=OK`, `MB1_E2E_FILESYSTEM_INVENTORY_STABLE=OK`. Permanecen `MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED`, `MB1_E2E_GLOBAL_FREEZE=NOT_VERIFIED`, `MB1_OPERATIONAL_RELEASE=NO`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Log privado local `/tmp/vencira-mb1-e2e.CwhKJPWs/drill.log` no inspeccionado. Validada la recuperación sintética desde un soporte lógico separado, no la custodia externa real ni la congelación universal.


## Ensayo de pérdida real del origen sintético — nueva revisión pendiente de validar

El mismo ejecutor E2E se ha ampliado: **después de generar y copiar el paquete autenticado** a un directorio independiente, elimina el `source.dump`, destruye el contenedor PostgreSQL de origen y borra los originales de objeto y diario sintéticos. Solo entonces restaura el objeto y el diario a partir del paquete y comprueba sus SHA-256 esperados, y hace `pg_restore` en el contenedor destino desde el paquete descifrado. Si falla alguna validación, se detiene el gate. Marcador añadido `MB1_E2E_ORIGINAL_SOURCE_DESTROYED=OK`. El directorio de recuperación temporal se elimina al finalizar. Las claves siguen estando en el **mismo VPS**; no se demuestra continuidad tras pérdida del VPS ni custodia externa. No hay congelación global de escritores. El procedimiento continúa confinado a contenedores PG17 de ensayo y datos sintéticos.

Validar mediante el **mismo gate E2E**, sin repetir pruebas parciales:

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash scripts/rehearse_mb1_pg17_e2e_disposable.sh
echo "MB1_SOURCE_LOSS_EXIT_CODE=$?"
```

Estado de esta revisión: pendiente de ejecución. `MB1_RELEASE_AUTHORIZED=NO`.
