# VENCIRA — D1-Q: inventario de promoción y diseño de rollback (10/11/2026)

**Estado: plan publicado, validación de inventario pendiente, DESPLIEGUE NO AUTORIZADO.**

Antecedentes comprobados: D1-N O5 PG17 histórico y rollback de migraciones en clon PASS; D1-O regresión sintética Django/Flutter web PASS; D1-P HTTPS y rutas GET del **DEV actual** PASS. Ninguno valida el candidato `main` publicado a través de Caddy ni una recuperación operacional del servicio completo.

## Inventario seguro para el siguiente gate

Reutilizar el comprobador **ya existente** `scripts/d1b_dev_compose_o5_metadata_readonly.py` en lugar de inventar comandos de despliegue. Este módulo lee etiquetas Compose de la API (nombre de proyecto, nombres de ficheros y basename del directorio de trabajo) y estados de timers O5. No lee variables de entorno ni secretos, no abre archivos de Compose/Caddy ni toca la BD. Su resultado no acredita un rollback.

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
python3 scripts/d1b_dev_compose_o5_metadata_readonly.py
echo "D1Q_INVENTORY_SHELL_RESULT=$?"
```

Comprobar que el resultado D1B es 0 y que el proyecto sigue siendo `vencira_localcheck`. Si el script muestra rutas fuera del alcance de nombres de fichero (inesperado), no compartirlas.

## Matriz de decisión para futura promoción (sin ejecución)

| Componente | Evidencia disponible | Bloqueo restante |
| --- | --- | --- |
| PostgreSQL | O5 real restaurado y migraciones 0019–0027 revertidas en clon | Estrategia de recuperación de datos añadidos tras upgrade, RPO/RTO y copia pre-cambio |
| Imagen API | Imagen candidata D1-O compila y suite `reminders` pasa | Registrar digest anterior y candidato, comprobar rutas/seguridad HTTPS en entorno efímero |
| Web Flutter | `flutter build web` de candidato PASS | Validar el artefacto servido por Nginx/Caddy de laboratorio sin alterar DEV |
| Caddy/TLS | TLS GET del DEV actual PASS | Identificar config activa exacta de proxy, rutas, host y directivas sin revelar credenciales |
| Ficha/adjuntos | Cobertura de `reminders` y gates históricos | Pruebas explícitas de autorización cruzada y carga/descarga aisladas; almacenamiento/backup de adjuntos |
| MFA/Android | Emisor nativo deshabilitado; muestras públicas 404 | MFA release sigue NO; no habilitar issuer, bearer ni APK nativa |
| Operación | O5 demostrado restaurable | Runbook de conmutación/rollback con responsables, verificación y autorización |

**Riesgo de rollback de datos:** D1-N demostró reversión de esquema y conservación de tres conteos; no probó recuperación de modificaciones realizadas entre migración y vuelta atrás. No asumir que `migrate reminders 0018` sea por sí solo una recuperación íntegra ni usarlo contra DEV. Una futura reversión puede requerir restauración del snapshot anterior a la ventana, con pérdida controlada de escrituras posteriores; decidirlo explícitamente antes de desplegar.

**Requisitos antes de solicitar autorización de DEV:** (1) inventario exacto Compose/Caddy revisado con información sensible redactada; (2) prueba integral aislada de imagen + HTTPS reverse proxy; (3) casos de acceso cruzado a workspace/ficha/adjuntos; (4) plan respaldado de conmutación, downtime, rollback imagen y BD y chequeos postrelease. Los tres gates anteriores son necesarios pero no suficientes.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D1_RELEASE_AUTHORIZED=NO
D1_DEPLOY_EXECUTED=NO
D1_LIVE_MIGRATIONS_EXECUTED=NO
```
