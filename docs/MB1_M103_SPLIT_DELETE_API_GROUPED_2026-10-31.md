# VENCIRA — MB1 M1-03 / C-FICHA: ensayo agrupado de separación de modelos y borrado (31/10/2026)

Rama: `feature/c-ficha-independent-attachments`. **PREPARADO, PENDIENTE de ejecución del operador.** No representa transición definitiva de datos ni autoriza migración operativa.

## Motivo: fallo real reproducido y avance anterior

El intento de borrar un `Renewal` desde Django con PostgreSQL migrado hasta `reminders.0018` falló con `UndefinedTable: reminders_renewalattachment`. El modelo histórico registrado en Django tiene una relación de protección `on_delete=PROTECT` que el collector consulta aunque no existan adjuntos. La tabla histórica solo se crea en `reminders.0027`, después de MFA 0019–0026, que **no está autorizada**. Se registró FAIL del ensayo completo y luego PASS limitado de CRU de `Renewal` y borrado de modalidad: `MB1_M103_DJANGO_PG17_RESULT=0`, pero `MB1_M103_DJANGO_FULL_RENEWAL_DELETE=NOT_VERIFIED`. Evidencias anteriores: `docs/MB1_M103_HBA_SCOPE_DJANGO_ORM_LAB_2026-10-31.md`.

No aplicar MFA 0019–0027 para superar el ensayo; tampoco `--fake`, tablas manuales, `_raw_delete` ni supresión permanente de protecciones.

## Cambios preparados (solo test)

- `backend/config/settings.py` (`b634e6b`) acepta `VENCIRA_M103_SPLIT_DELETE_LAB=1` **únicamente** cuando `VENCIRA_ENV=test` y `VENCIRA_ATTACHMENT_SPLIT_REHEARSAL=1`; de lo contrario arranca fallando.
- `backend/reminders/models.py` (`e7102c3`): el modelo histórico `reminders.RenewalAttachment` **solo se omite en el registro Django del laboratorio explícito**. El runtime normal de desarrollo/producción conserva exactamente la clase histórica, todas las migraciones y sus relaciones. No se ha modificado el archivo de migración `reminders.0027` ni se ha editado el esquema normal.
- `backend/renewal_attachments/offline_mb1_m103_split_delete_lab.py` (`304e35c`): confirma que el registro del laboratorio solo incluye el modelo independiente, que 0019–0027/MFA no se aplicaron, y que la cuenta Django real no es superusuario. Prueba borrado del vencimiento sin adjuntos; protección `ProtectedError` cuando existe adjunto independiente; después, eliminación explícita del adjunto sintético y del vencimiento. En las vistas de la API (mediante `APIRequestFactory` + `force_authenticate`) verifica listado solo de metadatos, `no-store`, subida/descarga/borrado `403`, acceso ajeno `404`, y ausencia de `storage_key` y `sha256`. Un estado `clean` NO habilita descargas. **Este ensayo de API se limita a las vistas DRF; no valida middleware real, sesión MFA, proxy HTTPS ni flujo HTTP extremo a extremo.**
- `scripts/rehearse_mb1_m103_split_delete_api_grouped.sh` (`3a685b3`): ejecutor único. Construye imagen temporal local, crea PostgreSQL 17 y red interna sin publicar puertos, migra **exclusivamente** `reminders.0018`, `renewal_attachments.0006`, sesiones y dependencias imprescindibles, concede permisos CRUD a un login no administrador de laboratorio, ejecuta las comprobaciones y elimina contenedor PostgreSQL con volumen anónimo, red e imagen. Sin volúmenes, claves ni datos de DEV, ni acceso a O5.

## Un solo comando para el VPS (todavía NO ejecutado)

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
