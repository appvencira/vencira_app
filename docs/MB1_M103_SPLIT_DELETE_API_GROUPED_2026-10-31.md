# VENCIRA — MB1 M1-03 / C-FICHA: ensayo agrupado de separación de modelos y borrado (31/10/2026)

Rama: `feature/c-ficha-independent-attachments`. **Primera ejecución FAIL por Auth incompleto; reensayo corregido PASS confirmado por operador (01/11/2026).** No representa transición definitiva de datos ni autoriza migración operativa.

## Motivo: fallo real reproducido y avance anterior

El intento de borrar un `Renewal` desde Django con PostgreSQL migrado hasta `reminders.0018` falló con `UndefinedTable: reminders_renewalattachment`. El modelo histórico registrado en Django tiene una relación de protección `on_delete=PROTECT` que el collector consulta aunque no existan adjuntos. La tabla histórica solo se crea en `reminders.0027`, después de MFA 0019–0026, que **no está autorizada**. Se registró FAIL del ensayo completo y luego PASS limitado de CRU de `Renewal` y borrado de modalidad: `MB1_M103_DJANGO_PG17_RESULT=0`, pero `MB1_M103_DJANGO_FULL_RENEWAL_DELETE=NOT_VERIFIED`. Evidencias anteriores: `docs/MB1_M103_HBA_SCOPE_DJANGO_ORM_LAB_2026-10-31.md`.

No aplicar MFA 0019–0027 para superar el ensayo; tampoco `--fake`, tablas manuales, `_raw_delete` ni supresión permanente de protecciones.

## Cambios preparados (solo test)

- `backend/config/settings.py` (`b634e6b`) acepta `VENCIRA_M103_SPLIT_DELETE_LAB=1` **únicamente** cuando `VENCIRA_ENV=test` y `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1`; de lo contrario arranca fallando.
- `backend/reminders/models.py` (`e7102c3`): el modelo histórico `reminders.RenewalAttachment` **solo se omite en el registro Django del laboratorio explícito**. El runtime normal de desarrollo/producción conserva exactamente la clase histórica, todas las migraciones y sus relaciones. No se ha modificado el archivo de migración `reminders.0027` ni se ha editado el esquema normal.
- `backend/renewal_attachments/offline_mb1_m103_split_delete_lab.py` (`304e35c`): confirma que el registro del laboratorio solo incluye el modelo independiente, que 0019–0027/MFA no se aplicaron, y que la cuenta Django real no es superusuario. Prueba borrado del vencimiento sin adjuntos; protección `ProtectedError` cuando existe adjunto independiente; después, eliminación explícita del adjunto sintético y del vencimiento. En las vistas de la API (mediante `APIRequestFactory` + `force_authenticate`) verifica listado solo de metadatos, `no-store`, subida/descarga/borrado `403`, acceso ajeno `404`, y ausencia de `storage_key` y `sha256`. Un estado `clean` NO habilita descargas. **Este ensayo de API se limita a las vistas DRF; no valida middleware real, sesión MFA, proxy HTTPS ni flujo HTTP extremo a extremo.**
- `scripts/rehearse_mb1_m103_split_delete_api_grouped.sh` (`3a685b3`): ejecutor único. Construye imagen temporal local, crea PostgreSQL 17 y red interna sin publicar puertos, migra **exclusivamente** `reminders.0018`, `renewal_attachments.0006`, sesiones y dependencias imprescindibles, concede permisos CRUD a un login no administrador de laboratorio, ejecuta las comprobaciones y elimina contenedor PostgreSQL con volumen anónimo, red e imagen. Sin volúmenes, claves ni datos de DEV, ni acceso a O5.

## Comando histórico de reproducción (ya ejecutado; NO repetir sin cambios)

```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_m103_split_delete_api_grouped.sh
MB1_M103_SPLIT_DELETE_LAB=YES bash scripts/rehearse_mb1_m103_split_delete_api_grouped.sh
echo "MB1_M103_SPLIT_GROUP_EXIT_CODE=$?"
```

Marcadores esperados:

```text
MB1_M103_SPLIT_SOURCE_PREFLIGHT=OK
MB1_M103_SPLIT_POSTGRES17_INTERNAL_ONLY=OK
MB1_M103_SPLIT_INDEPENDENT_SCHEMA_WITHOUT_MFA=OK
MB1_M103_SPLIT_LIMITED_ROLE_READY=OK
MB1_M103_SPLIT_RUNTIME_ONLY_NO_HISTORICAL_MODEL=OK
MB1_M103_SPLIT_NO_MFA_MIGRATIONS=OK
MB1_M103_SPLIT_DJANGO_LIMITED_ROLE=OK
MB1_M103_SPLIT_RENEWAL_DELETE_EMPTY=OK
MB1_M103_SPLIT_ATTACHED_RENEWAL_PROTECTED=OK
MB1_M103_SPLIT_ATTACHMENT_API_VIEW_FAILCLOSED=OK
MB1_M103_SPLIT_ATTACHMENT_HTTP_MIDDLEWARE=NOT_VERIFIED
MB1_M103_SPLIT_RENEWAL_DELETE_AFTER_ATTACHMENT_REMOVAL=OK
MB1_M103_SPLIT_DATA_MIGRATION=NOT_IMPLEMENTED
MB1_M103_SPLIT_DJANGO_DELETE_LAB=OK
MB1_M103_SPLIT_GROUP_DONE=OK
MB1_M103_SPLIT_GROUP_PHASE=DONE
MB1_M103_SPLIT_GROUP_RESULT=0
MB1_M103_SPLIT_GROUP_EXIT_CODE=0
```

Ante cualquier fallo, NO se dan por aprobados los demás casos ni se activa la ruta test-only en DEV.

## Límites arquitectónicos y fase siguiente

Un resultado 0 demostrará únicamente la **viabilidad semántica** del esquema independiente en laboratorio sin activar MFA. **No significa que los datos existentes estén migrados ni que sea seguro quitar la clase histórica de la aplicación operativa.**

Antes de implementar la transición real habrá que decidir el mecanismo de compatibilidad con entornos que sí tienen `reminders.0027` aplicada en clones, demostrar preservación de IDs/huellas/objetos con datos históricos, bloquear escrituras globalmente y restaurar en un segundo host. Es necesario definir el comportamiento de las API y del collector de Django frente a ambos modelos, y validar HTTP completo. La ruta independiente está diseñada para **no depender de MFA**; podría autorizarse separadamente solo tras cumplir los gates aplicables de seguridad, custodia, migración de datos y aceptación operativa. MFA y el legado 0027 continúan bloqueados. Un `migrate` global que arrastre MFA sigue prohibido.

```text
MB1_M103_SPLIT_RUNTIME_OMISSION=TEST_ONLY
MB1_M103_HISTORICAL_DATA_TRANSITION=NOT_IMPLEMENTED
MB1_M103_FULL_HTTP_MIDDLEWARE=NOT_VERIFIED
MB1_GLOBAL_FREEZE=NOT_VERIFIED
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Incidencia observada al ejecutar — FAIL Auth incompleto (31/10/2026)

El operador ejecutó el bloque de laboratorio real y obtuvo, antes del fallo:
`MB1_M103_SPLIT_IMAGE_BUILD=OK`,
`MB1_M103_SPLIT_POSTGRES17_INTERNAL_ONLY=OK`,
`MB1_M103_SPLIT_INDEPENDENT_SCHEMA_WITHOUT_MFA=OK`,
`MB1_M103_SPLIT_LIMITED_ROLE_READY=OK`,
`MB1_M103_SPLIT_RUNTIME_ONLY_NO_HISTORICAL_MODEL=OK`,
`MB1_M103_SPLIT_NO_MFA_MIGRATIONS=OK`,
`MB1_M103_SPLIT_DJANGO_LIMITED_ROLE=OK`.

Al crear `auth.User` ficticio, PostgreSQL rechazó el valor nulo de `auth_user.last_login`: `psycopg.errors.NotNullViolation`. Se comprobó que el runner solo migraba la dependencia mínima de Auth (procedente de `reminders.0018`), pero no ejecutaba explícitamente `migrate auth`; el campo se hace nullable mediante la migración estándar Django `auth.0005_alter_user_last_login_null`. La causa es **esquema Auth incompleto en la base efímera**, no un fallo de permisos del login limitado ni una justificación para activar MFA.

La ejecución reportó `MB1_M103_SPLIT_GROUP_PHASE=REAL_ORM` y `MB1_M103_SPLIT_GROUP_RESULT=1`. **El gate completo no pasó y no debe afirmarse lo contrario**. La prueba de borrado y las vistas DRF no llegaron a ejecutarse. El contenedor de laboratorio y su volumen se destruyeron según el trap del runner. No se modificó DEV, preview ni O5.

## Corrección de alcance mínimo — reensayada y validada

- Runner `scripts/rehearse_mb1_m103_split_delete_api_grouped.sh` (commit `eeae957`): tras `reminders.0018` y `renewal_attachments.0006`, ejecuta explícitamente `python manage.py migrate auth --noinput` y `migrate sessions` **solo en el contenedor efímero**. Antes de conceder grants, consulta que la migración Auth 0005 esté aplicada y que `auth_user.last_login` tenga `is_nullable=YES`. No ejecuta `migrate` global ni toca 0019–0027.
- Programa `backend/renewal_attachments/offline_mb1_m103_split_delete_lab.py` (commit `f96b2ee`): segundo control fail-closed del mismo esquema, desde la sesión limitada, antes de crear usuarios.
- No se repiten los gates M1-02, HBA, roles genéricos ni las auditorías previas; se vuelve a ejecutar únicamente el bloque que falló, con la corrección necesaria de las migraciones Auth.

Comando:
```bash
cd ~/vencira-localcheck
git pull --ff-only origin feature/c-ficha-independent-attachments
bash -n scripts/rehearse_mb1_m103_split_delete_api_grouped.sh
MB1_M103_SPLIT_DELETE_LAB=YES bash scripts/rehearse_mb1_m103_split_delete_api_grouped.sh
echo "MB1_M103_SPLIT_GROUP_EXIT_CODE=$?"
```

Nuevos requisitos de aceptación **además de los marcadores previos**:
```text
MB1_M103_SPLIT_DJANGO_BUILTIN_AUTH_MIGRATIONS=OK
MB1_M103_SPLIT_AUTH_LAST_LOGIN_NULLABLE=OK
MB1_M103_SPLIT_AUTH_SCHEMA_READY=OK
MB1_M103_SPLIT_GROUP_RESULT=0
MB1_M103_SPLIT_GROUP_EXIT_CODE=0
```

**Resultado posterior:** el reensayo corregido fue ejecutado con `MB1_M103_SPLIT_GROUP_RESULT=0` y `PHASE=DONE`. Véase evidencia posterior. **No cerrar M1-03 ni M2/C-FICHA**: las migraciones MFA continúan prohibidas y la migración de datos históricos no existe.


## 01/11/2026 — Reensayo corregido: PASS de laboratorio (evidencia aportada)

El operador facilitó los siguientes marcadores (algunas líneas llegaron concatenadas por formato de copia):

```text
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
```

**Evaluación:** el control de seguridad de las migraciones Auth estándar es PASS; en PG17 recién creado con un login Django no superusuario, `Renewal.delete()` elimina un vencimiento sintético sin adjuntos; cuando existe un adjunto independiente, `ProtectedError` impide borrar el vencimiento; una vez retirado explícitamente el adjunto sintético, la eliminación funciona. Las vistas DRF comprobadas mediante `APIRequestFactory` presentan metadatos sin claves privadas y rechazan subir, descargar y borrar (403) o consultar otro tenant (404). La prueba **no incluye** middleware completo, cliente HTTP real, proxy ni MFA de sesión. El modelo histórico se omitió **solo en runtime test-only**: esto no corrige ni autoriza su eliminación en DEV, ni transforma registros del esquema 0027.

**Precisión de transcripción:** el operador envió `MB1_RELEASE_AUTHORIZED=;NO`, con un carácter `;` ajeno al formato literal que escribe el runner (el código imprime `MB1_RELEASE_AUTHORIZED=NO`). Registrar **valor copiado mal formado, no una autorización**; todas las señales de release son NO y no hay aprobación explícita. Tampoco se incluyó la línea `MB1_M103_SPLIT_GROUP_EXIT_CODE=0` del `echo` de shell, de modo que **solo** se certifica el `MB1_M103_SPLIT_GROUP_RESULT=0` emitido por el trap. El primer marcador `MB1_M103_SPLIT_SOURCE_PREFLIGHT` llegó truncado; el avance posterior lo presupone por el flujo fail-closed, sin atribuirle un literal no visible.

**Progreso formal inalterado:** M1-03 [ ], M1-04 [ ], M2-02 [ ], M2-03 [ ], `MB1_GLOBAL_FREEZE=NOT_VERIFIED`, `MFA_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`. **1/15 = 6,7 %**.

**Siguiente fase sin repetir este gate:** diseño de transición entre los dos modelos y migraciones coexistentes con inventario de datos históricos y custodia de archivos, ensayos íntegros **solo en clon** con datos sintéticos, cobertura HTTP/middleware bajo rol limitado y censos P0 restantes. Requiere resolver congelación universal y custodia externa para liberación operativa. No activar `reminders.0019–0027`, no ejecutar un `migrate` global y no habilitar tráfico de adjuntos.
