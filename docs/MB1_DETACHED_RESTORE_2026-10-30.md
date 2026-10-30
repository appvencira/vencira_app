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
