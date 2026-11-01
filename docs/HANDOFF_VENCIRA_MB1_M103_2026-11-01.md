# VENCIRA — HANDOFF integral al nuevo chat (01/11/2026)

**Fuente de verdad:** repositorio GitHub \`appvencira/vencira_app\`, rama \`feature/c-ficha-independent-attachments\`. Checklist maestra: \`docs/VENCIRA_MASTER_COMPLETION_CHECKLIST_2026-10-30.md\` (actualización del 01/11, commit \`27ad503\`). Evidencia más reciente: \`docs/MB1_M103_SPLIT_DELETE_API_GROUPED_2026-10-31.md\` (commit \`17143ab\`).

Este documento está pensado para que un asistente nuevo retome el trabajo sin dar por completados gates no ejecutados, sin solicitar al operador repetir salidas previamente confirmadas y **sin aplicar cambios a DEV ni a la base persistente**.

## 1. Identidad, servicios y reglas de trabajo

- Producto VENCIRA, gestión de vencimientos de clientes/prospectos y modalidades. Arquitectura Django 5 + PostgreSQL 17, Flutter Web, Docker, Caddy HTTPS en \`dev.vencira.es\`. Código en rama de desarrollo \`feature/c-ficha-independent-attachments\`.
- Directorio de trabajo del VPS IONOS Ubuntu: \`/home/vencira/vencira-localcheck\`; usuario de shell \`vencira\`. Otro proyecto Docker \`vencira_preview\` comparte host; **no confundir bases, redes ni servicios**. Evidencia anterior indica contenedores API/DB/web sanos; **la última ejecución solo prueba un laboratorio**, no vuelve a demostrar salud actual de DEV.
- Esquema persistente confirmado anteriormente: \`reminders.0018_draft_reasons\`. En rama hay \`reminders.0019–0026\` MFA y \`reminders.0027_renewal_attachment_metadata\` (histórico), **sin autorización para migrarlas en DB persistente**.
- Adjuntos independientes en app \`renewal_attachments\` con migraciones hasta \`0006_ed25519_signature_length\`, habilitada solo en test con \`VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1\`.
- Flujo preferido: **desarrollar y documentar directamente en GitHub**, agrupar nuevos tests en una única ejecución de operador; evitar repetir gates ya aprobados, evitar ensayos de a uno. Un PASS de laboratorio no es autorización de release. No inventar métricas ni commits.
- **Reglas innegociables:** no \`migrate\` global que arrastre MFA, no migrar/modificar PostgreSQL persistente, no despliegue/reinicio de DEV, no desactivar Caddy/cron/O5, no copiar secretos ni claves a chat/GitHub, no saltar guards o borrar objetos para conseguir PASS. Mantener \`MFA_RELEASE_AUTHORIZED=NO\`, \`C_FICHA_RELEASE_AUTHORIZED=NO\`, \`MB1_RELEASE_AUTHORIZED=NO\`, \`NO_DEPLOY_NO_LIVE_MIGRATION=1\` y \`MB1_GLOBAL_FREEZE=NOT_VERIFIED\`.

## 2. Evidencia **nueva y confirmada**: split de adjuntos + borrado + API

**Fecha de transcripción:** 01/11/2026. El usuario ejecutó \`scripts/rehearse_mb1_m103_split_delete_api_grouped.sh\` (versión corregida con \`auth.0005\`) en **PostgreSQL 17 desechable**, Docker red interna, sin datos reales ni migraciones MFA. **Resultado final del propio runner: \`MB1_M103_SPLIT_GROUP_RESULT=0\`, \`PHASE=DONE\`.**

Marcadores verificados por el operador:

\`\`\`text
MB1_M103_SPLIT_IMAGE_BUILD=OK
MB1_M103_SPLIT_POSTGRES17_INTERNAL_ONLY=OK
MB1_M103_SPLIT_DJANGO_BUILTIN_AUTH_MIGRATIONS=OK
MB1_M103_SPLIT_AUTH_LAST_LOGIN_NULLABLE=OK
MB1_M103_SPLIT_INDEPENDENT_SCHEMA_WITHOUT_MFA=OK
MB1_M103_SPLIT_LIMITED_ROLE_READY=OK
MB1_M103_SPLIT_RUNTIME_ONLY_NO_HISTORICAL_MODEL=OK
MB1_M103_SPLIT_NO_MFA_MIGRATIONS=OK
MB1_M103_SPLIT_DJANGO_LIMITED_ROLE=OK
MB1_M103_SPLIT_AUTH_SCHEMA_READY=OK
MB1_M103_SPLIT_RENEWAL_DELETE_EMPTY=OK
MB1_M103_SPLIT_ATTACHED_RENEWAL_PROTECTED=OK
MB1_M103_SPLIT_ATTACHMENT_API_VIEW_FAILCLOSED=OK
MB1_M103_SPLIT_ATTACHMENT_HTTP_MIDDLEWARE=NOT_VERIFIED
MB1_M103_SPLIT_RENEWAL_DELETE_AFTER_ATTACHMENT_REMOVAL=OK
MB1_M103_SPLIT_DATA_MIGRATION=NOT_IMPLEMENTED
MB1_M103_SPLIT_OPERATIONAL_RELEASE=NO
MB1_M103_SPLIT_DJANGO_DELETE_LAB=OK
MB1_M103_SPLIT_DJANGO_NONADMIN_DELETE_AND_API=OK
MB1_M103_SPLIT_GROUP_DONE=OK
MB1_M103_SPLIT_GROUP_PHASE=DONE
MB1_M103_SPLIT_GROUP_RESULT=0
MB1_M103_SPLIT_RUNTIME_OMISSION=TEST_ONLY
MB1_M103_FULL_HTTP_MIDDLEWARE=NOT_VERIFIED
MB1_M103_HISTORICAL_DATA_TRANSITION=NOT_IMPLEMENTED
MB1_M103_LIVE_SCHEMA_CHANGE=NOT_AUTHORIZED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
MFA_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
\`\`\`

**Precisiones de la captura:** el primer marcador \`MB1_M103_SPLIT_SOURCE_PREFLIGHT=OK\` aparece truncado (\`CE_PREFLIGHT=OK\`); el resto del flujo y \`RESULT=0\` lo hacen compatible con preflight superado, pero no inventar el literal completo. El usuario copió \`MB1_RELEASE_AUTHORIZED=;NO\`; el runner imprime \`MB1_RELEASE_AUTHORIZED=NO\` sin punto y coma; no hay ningún permiso de release. **NO se incluyó el \`echo\` de shell \`MB1_M103_SPLIT_GROUP_EXIT_CODE=0\`**, por lo que no citar ese marcador como observado. Controles de archivo/código se verificaron por lectura en GitHub; la comprobación del host corresponde a la salida del operador.

**Qué se ha demostrado, y solamente eso:** en el registro Django **test-only** sin el modelo histórico, el \`Renewal\` sin adjuntos se puede borrar; con adjunto independiente se preserva mediante \`on_delete=PROTECT\`; tras borrar explícitamente el adjunto de laboratorio, puede borrarse el vencimiento. Las vistas DRF llamadas directamente con \`APIRequestFactory\` permiten listar **metadatos autorizados**, no bytes; rechazan upload/download/delete y otro tenant. Usuario de la app no es superusuario. No se cambió la definición histórica para ejecución normal.

**Qué NO está demostrado:** migración real de metadatos/objetos históricos a app nueva; HTTP real vía cliente, middleware de sesión/MFA o proxy; seguridad de role grants finales; restore integral fuera del VPS; escrituras universalmente congeladas; despliegue seguro. No incrementar progreso formal.

### Cronología de fallos ya corregidos (NO reproducir innecesariamente)

1. Primer ensayo ORM sin tabla \`reminders_renewalattachment\`: \`UndefinedTable\` en \`Renewal.delete()\`, porque el runtime normal registra el histórico cuyo esquema nace en \`reminders.0027\` después de MFA. Documentado en \`docs/MB1_M103_HBA_SCOPE_DJANGO_ORM_LAB_2026-10-31.md\`. Corrección de alcance test-only: \`backend/config/settings.py\` (\`b634e6b\`) y \`backend/reminders/models.py\` (\`e7102c3\`) omiten histórico **solo con \`VENCIRA_ENV=test\` + split + \`VENCIRA_M103_SPLIT_DELETE_LAB=1\`**; en DEV/prod se conserva.
2. Primera ejecución del nuevo split test falló \`NotNullViolation: auth_user.last_login\` porque faltaba \`auth.0005_alter_user_last_login_null\` en PG temporal. Se corrigió ejecutando explícitamente \`migrate auth\` en el laboratorio y comprobando \`is_nullable=YES\` (\`eeae957\`, \`f96b2ee\`). **El segundo intento fue PASS \`RESULT=0\`**.
3. Otro ensayo previo de mínimo privilegio fue PASS **parcial**: CRUD de modelos sin \`Renewal.delete\` por la 0027 ausente (\`MB1_M103_DJANGO_PG17_RESULT=0\` y \`FULL_RENEWAL_DELETE=NOT_VERIFIED\`). No sustituir sus límites por el PASS actual, que solo vale en el registro test-only independiente.

### Archivos relevantes

- \`backend/config/settings.py\`: guard test-only de \`VENCIRA_M103_SPLIT_DELETE_LAB\`.
- \`backend/reminders/models.py\`: antiguo modelo histórico omitible **solo en ese laboratorio**.
- \`backend/reminders/attachment_model_router.py\`: resolución de modelo independiente estrictamente test-only.
- \`backend/renewal_attachments/models.py\` y \`migrations/0001_initial.py\`…\`0006_ed25519_signature_length.py\`: esquema aislado.
- \`backend/renewal_attachments/offline_mb1_m103_split_delete_lab.py\`: prueba Django no superusuario, borrado y protección, vistas DRF.
- \`scripts/rehearse_mb1_m103_split_delete_api_grouped.sh\`: runner que ya pasó; crea, usa y elimina PostgreSQL + volúmenes/red/imagen temporales.
- \`backend/reminders/attachment_api.py\` y \`backend/reminders/attachment_gate.py\`: API metadata-only, subida/descarga/borrado deshabilitados.
- \`docs/MB1_M103_SPLIT_DELETE_API_GROUPED_2026-10-31.md\`: salida real, fallo anterior y resultados actuales.
- \`docs/C_FICHA_MIGRATION_SPLIT_DESIGN_2026-10-28.md\`, \`docs/C_FICHA_SPLIT_BRANCH_STATUS_2026-10-28.md\`: antecedentes y coexistencia experimental de ambos esquemas.

## 3. Comprobaciones previas que YA pasaron y no se deben repetir sin cambios

### M1-03: escritores, seguridad SQL y HTTP parcial

- Auditoría inicial de ambos proyectos: tres miembros por red DB, sin contenedores de otros proyectos ni privilegiados detectados. Cada PostgreSQL: un único rol login, que es **superusuario**; la API usa efectivamente ese rol (riesgo de mínimo privilegio en DEV/preview). \`MB1_M103_EFFECTIVE_ACCESS_INVENTORY=OK\`, \`MB1_M103_GROUP_RESULT=0\`.
- HBA: \`HOST_TRUST=4\`, \`LOCAL_TRUST=2\`, regla host amplia con \`SCRAM=1\`, \`BROAD_HOST_TRUST=0\`, por DB. Las cuatro reglas host \`trust\` de ambos proyectos están limitadas a **loopback** (dos IPv4 + dos IPv6); \`NONLOOPBACK=0\`, \`UNRESOLVED=0\`, \`MB1_M103_TRUST_SCOPE_READONLY=OK\`. **No demuestra seguridad de red completa ni exposición a Internet.**
- 11 pruebas HBA/identidad PASS; PostgreSQL limitado sintético CRUD + seis denegaciones administrativas PASS; ORM parcial con rol limitado PASS (véase limitación anterior).
- Censos previos: 76 archivos / 264 llamadas heurísticas, 34 archivos P0 / **131 llamadas P0**, P1=15, P2=118. Solo un subconjunto revisado semánticamente; **censo universal y exclusión de root, acceso SQL externo, objetos y diario siguen pendientes**. Documento \`docs/MB1_EFFECTIVE_WRITER_COVERAGE_2026-10-30.md\` y B18J/B18K. \`M1-03\` sigue abierto.

### M1-02: fallos parciales y commit ambiguo

- 30/30 tests de intake + objeto Fernet + diario + conciliación de solo lectura PASS.
- En PG17 real **efímero**, COMMIT seguido de TimeoutError simulando ACK perdido y rollback previo al COMMIT: \`MB1_M102_REAL_PG17_RESULT=0\`; ciphertext y diario conservados; no autoborrado.
- Falta pérdida de energía real y reconciliación operacional autónoma autorizada. \`M1-02\` abierto. \`docs/MB1_M102_REAL_PG17_AMBIGUOUS_ACK_2026-10-31.md\`.
- Un informe histórico B18J2 mencionaba borrado inseguro en la etapa de metadata. La corrección posterior \`05bea57\` preserva ciphertext ante resultado SQL ambiguo; documento \`docs/MB1_B18J2_CRITICAL_WRITERS_REVIEW_2026-10-30.md\` fue anotado para distinguir hallazgo histórico de estado actual.

### M1-04: captura conjunta sin freeze universal

- Ensayos sintéticos PG17 + objeto cifrado + diario bajo ventana cooperativa y restauración PASS.
- Los bypasses con SQL administrativo y filesystem no cooperativo están **confirmados**, por lo que \`MB1_GLOBAL_FREEZE=NOT_VERIFIED\` y \`M1-04\` abierto. No usar advisory locks como garantía universal.

### M1-05 y O5: restauración PG, sin paquete integral operativo

- Restic O5 a Drive para PostgreSQL **solo**; la restauración de una copia cifrada real de Drive a PG17 temporal en el mismo VPS fue PASS con 25 tablas, 10 pruebas y \`MB1_O5_GROUP_RESULT=0\`. El O5 instalado no se reemplazó.
- Antirollback puro 11 tests, paquete físico 23 tests, rechazo sintético de generación antigua y restauración protegida de generación vigente PASS. **Cabeza externa/antirollback operacional, objetos/diario en backup O5 y congelación universal no implementados**. \`M1-05\` abierto.
- Docs: \`docs/MB1_O5_GROUPED_DRIVE_RESTORE_2026-10-31.md\`, \`docs/MB1_M105_GATED_TWO_GENERATION_RESTORE_2026-10-31.md\`.

### M1-06: recuperación en segundo equipo bloqueada

- El intento \`scripts/rehearse_mb1_o5_independent_host_dr.sh\` reportó \`MB1_DR_ORIGIN_CONTAINER_PRESENT=ABORT\`, \`PHASE=PRECHECK\`, \`RESULT=2\`; encontró firma de contenedor del entorno origen, así que no demuestra segundo host. **No sortear la comprobación ni repetir en el VPS origen**.
- Necesita Ubuntu x86_64 realmente separado, custodia B externa real de credenciales y cabeza antirollback, y recuperación de PG17 más objetos/diario bajo procedimiento completo. Documento \`docs/MB1_M106_INDEPENDENT_O5_DR_GATE_2026-10-31.md\`. \`M1-06\` abierto.

## 4. Cierre global / hitos formales

Fuente: \`docs/VENCIRA_MASTER_COMPLETION_CHECKLIST_2026-10-30.md\`. **Solo 1 de 15 = 6,7 %**, que mide hitos finalizados, no proporción del código o tiempo restante.

- **MB1 1/7:** M1-01 [x]. M1-02 [ ] reconciliación/pérdida; M1-03 [ ] escritores/SQL; M1-04 [ ] freeze DB+archivos; M1-05 [ ] antirollback/captura integral; M1-06 [ ] custodia offhost; M1-07 [ ] gate final.
- **MB2 0/4:** M2-01 [ ] custodia MFA; M2-02 [ ] escáner/firma/adjuntos; M2-03 [ ] migraciones en clon/rollback; M2-04 [ ] revisión y liberación separada.
- **MB3 0/4:** M3-01 [ ] whitepaper; M3-02 [ ] UX y funcionalidad; M3-03 [ ] E2E/accesibilidad/rendimiento; M3-04 [ ] despliegue gradual/aceptación.
- Las pruebas test-only de adjuntos no autorizan uploads/downloads ni cambio de tabla operativa. MFA, C-FICHA y MB1 siguen con \`RELEASE_AUTHORIZED=NO\`.

## 5. Siguiente bloque recomendado (preparar en GitHub; **no ejecutado aún**)

**Objetivo:** cerrar brechas de diseño de transición histórico→independiente, evitando más pruebas triviales. Priorizar un **único gate compuesto** para un clon PG17 vacío/sintético con:
1. **Preflight de compatibilidad del grafo y recuentos**, rutas hasta \`reminders.0018\` + \`renewal_attachments.0006\`, sin MFA; reproducir por separado coexistencia con histórico 0027 **únicamente en clon aislado** cuando la prueba lo exija, sin \`migrate\` global.
2. **Contrato de transición de datos con zero-loss** sobre metadatos/UUID/storage_key/hash/tamaños/estados, ante 0 registros, registros solo históricos, conflictos, duplicados y divergencias; no trasladar datos operativos ni bytes reales. Si existe un registro histórico sin paquete de objeto verificable, **abortar** sin mutación; plan explícito para mantener ambos modelos durante transición y recuperación.
3. **HTTP/middleware real y rol DB no superusuario** sobre clon test-only, con rutas de adjuntos que continúen cerradas, comprobar separación de tenants y sesión sin habilitar MFA. Evitar afirmar cobertura de scanner/bytes o de prod.
4. **Una sola ejecución y documento de aceptación/fallos**; no volver a correr los gates M1-03, B18K, O5, HBA, RTO, MFA o ClamAV previamente validados salvo cambios que lo justifiquen.

**Advertencia arquitectónica:** la omisión condicional del modelo histórico en \`reminders/models.py\` es una técnica de **laboratorio**. No se convierte automáticamente en transición válida con registros existentes; la metadata vieja y el \`on_delete\` histórico exigen reconciliación, preservación de objetos cifrados y aceptación del plan de migraciones. Separación de identidades SQL para API/admin/backup también requiere ensayos en clon con matriz de grants y rollback.

**Primer paso del nuevo chat:** leer este archivo y la checklist maestra desde GitHub, revisar el código de transición ya existente (ver \`renewal_attachments/transition_preflight.py\`, \`transition_reconciliation.py\`, \`transition_object_audit.py\`) antes de crear código, y desarrollar/commitizar las comprobaciones nuevas. **No solicitar al operador repetir los 15 gates ya probados; si se necesita shell, dar UN comando seguro.**

## 6. Operación de continuación sugerida

En el VPS se puede verificar solamente el origen de código, sin tocar servicios:

\`\`\`bash
cd ~/vencira-localcheck
git status -sb
git pull --ff-only origin feature/c-ficha-independent-attachments
git log -1 --oneline
sed -n '1,200p' docs/HANDOFF_VENCIRA_MB1_M103_2026-11-01.md
\`\`\`

No ejecutar \`migrate\`, \`docker compose up\`, \`systemctl restart\`, ni el gate de recuperación independiente en este VPS. Los documentos de GitHub, no la memoria del chat, son la referencia reproducible. Los siguientes PASS deberán registrarse con resultado concreto, evidencia, commit y cambios permitidos; actualizar checklist y documento de traspaso al cerrar nueva fase.
