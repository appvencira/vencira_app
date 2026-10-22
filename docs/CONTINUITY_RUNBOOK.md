# VENCIRA — CONTINUIDAD OPERATIVA (leer al comenzar un chat)

Fecha de revisión: 2026-10-22. Fuente de verdad: repositorio privado `appvencira/vencira_app`, rama `integration/local-e2e-prep`. Este documento describe **estado probado en GitHub y pasos pendientes**, no garantiza el estado de un servidor.

## Objetivo y normas permanentes

VENCIRA es agenda multiplataforma (Flutter + Django/PostgreSQL) de pólizas externas individuales, **no CRM**. Seguir el whitepaper original, especialmente §6: Clientes/Candidatos, identificación, modalidad/aseguradora personalizadas, fechas, estado, responsable, notas y adjuntos seguros. Los datos de anotaciones distintas **no están vinculados**: las sugerencias copian por decisión explícita sin sincronizar registros.

**Forma de trabajo acordada:** asistente desarrolla y actualiza GitHub; realiza cuanto pueda de forma autónoma. Pedir al usuario **solo bloques de consola para comprobaciones o despliegues que requieren su servidor**, nunca inspecciones repetidas que ya podamos efectuar desde GitHub. El usuario pega salidas; el asistente interpreta, corrige en GitHub, repite pruebas si procede. Mantener cambios documentados, comandos reproducibles y reversión. Evitar datos personales reales hasta pasar barreras de seguridad.

## Repositorio, ramas y cambios validados

- Integración: `integration/local-e2e-prep`; los PR de la fase están fusionados.
- PR #11 (identidad): commit de fusión `47f30738fa8eaa27e9a5304bf8c62b1b263d1c65`. Campos `full_name`, `nickname`, `phone`, `email`, `policy_number`; migración `0011_renewal_policy_identity`; serializador, editor Flutter y búsqueda; CI #79 verde.
- PR #12 (notas): commit `8eed7f47597f511543414b09628e578d91110658`. Migración `0012_renewal_notes`; editor y lectura, hasta 4000 caracteres desde API; CI #80 verde. Adjuntos **solo especificación**, aún desactivados: `docs/ATTACHMENTS_SECURITY_GATE.md`.
- PR #13 (sugerencias): commit `189065aa166e9ffd948fde1e28114e6eb48bc5d5`. Sin migración. Endpoint y Flutter para copiar contacto desde anotaciones visibles. Pruebas locales: Django 105 tests OK, Flutter analyze/test/build web OK.
- `0010_workspace_insurer` ya existe en integración; el servidor anterior estaba solamente hasta `0009_workspace_modality`.
- **GitHub Actions tiene la cuota agotada**: no volver a activar o depender de ejecuciones CI; preferir Docker local efímero. No afirmar CI verde para commits posteriores sin evidencia.

## Servidor conocido (solo descripción histórica, volver a comprobar antes de escribir)

- Usuario `vencira`, Ubuntu. Checkout correcto `/home/vencira/vencira-localcheck`, con remoto SSH de solo lectura `git@github-vencira-ro:appvencira/vencira_app.git`. Antes de esta fase rama `integration/local-e2e-prep`, commit `5d48225696f2ba426ba8eb6346b9123a12d3c9ad`, limpio. El remoto puede haber avanzado: comprobar FETCH_HEAD y origin.
- Contenedores del stack a conservar: `vencira_localcheck-api-1`, `vencira_localcheck-db-1`, `vencira_localcheck-web_preview-1`. **Existen también contenedores `vencira_preview-*` de otra instalación**. Jamás confundir stacks, volúmenes ni nombres Compose.
- Otro checkout: `/home/vencira/vencira-preview` con código más antiguo; **no usar para este despliegue**.
- Backups históricos: `/home/vencira/vencira-db-backups/`. Realizar nuevo `pg_dump -Fc` de la base del stack correcto, comprobar `pg_restore -l`, guardar `sha256sum` y permisos 600, antes de construir/reiniciar/aplicar migraciones.
- Los contenedores API ejecutan `python manage.py migrate --noinput` al arrancar (ver `compose.yaml`): **un `docker compose up --build -d` puede aplicar migraciones automáticamente**. No construir ni levantar API conectada a PostgreSQL existente antes de disponer de backup probado.
- Las pruebas recientes usaron worktree efímero `/tmp/vencira-suggestions.RIC9UU/source`, imagen `vencira-suggestions-check:local` y Flutter mediante `ghcr.io/cirruslabs/flutter:stable`. El worktree no es despliegue.
- No usar GitHub Actions; verificar Docker local con SQLite y, cuando proceda, PostgreSQL efímero `-p` exclusivo distinto de los nombres Compose presentes.

## Última evidencia del servidor

- Usuario confirmó `BACKUP_VERIFICADO=1` tras `pg_dump -Fc` y `pg_restore -l` en el contenedor validado `vencira_localcheck-db-1`.
- Archivo: `/home/vencira/vencira-db-backups/pre0010-0012_uti0uvWX.dump`.
- Al finalizar el respaldo indicó `DESPLIEGUE_AUN_NO_REALIZADO=1`. **No confundir respaldo con migración.**
- La verificación de restauración integral todavía está pendiente; `pg_restore -l` verifica la lectura del índice, no la restauración completa.

## Pasos siguientes del despliegue (todavía NO realizados)

1. Desde servidor, lectura única: comprobar rama, remoto, checkout limpio, `git fetch`, `git rev-parse HEAD` y `origin/integration/local-e2e-prep`; ver nombres exactos de proyectos y Compose con `docker compose ls`, `docker inspect` y `docker ps` antes de mutar.
2. Usar checkout/imagen **aislados** para confirmar Django check/makemigrations/test, incluyendo migraciones 0010–0012 con PostgreSQL temporal, y Flutter analyze/test/build. La prueba 105/Flutter ya se realizó sobre #13; repetir sobre SHA definitivo si cambia.
3. Backup `pg_dump -Fc` desde **la BD localcheck**; verificar con `pg_restore -l`, checksum, propietario/permisos. Evitar comandos que cambien contenedores `vencira_preview-*`.
4. Comprobar plan SQL con `manage.py migrate --plan` en entorno correcto; revisar cambios antes de aplicar. Actualizar únicamente stack localcheck, vigilar salud, registros y `showmigrations`.
5. Probar APIs, catálogo, notas, identidad, sugerencias, autenticación, aislamiento y dispositivo Android con **datos ficticios**. Preparar procedimiento de restauración; no intentar revertir migraciones destructivamente.
6. Registrar SHA desplegado, fecha, resultado de comandos, identificador no sensible de backup, estado de migraciones y estado posterior en este archivo o bitácora específica.

## Incidencia resuelta en código, pendiente de repetir prueba local

- Primer intento de construir la API nueva: `PermissionError: [Errno 13] Permission denied: '/app/reminders/models.py'`, antes de `showmigrations`. Ninguna migración aplicada; no se reiniciaron contenedores.
- Causa: Dockerfile copiaba los fuentes con el propietario del contexto y después ejecutaba como usuario `vencira` sin permiso para leer algún archivo.
- Corrección integrada en `integration/local-e2e-prep`: commit `9205ed03269b5bce5f3edef704e9b229fecf1a52`, `COPY --chown=vencira:vencira . /app`.
- Próximo paso: sincronizar ese commit, reconstruir solo la imagen, comprobar lectura de código en un contenedor efímero y volver a ejecutar `showmigrations` y `migrate --plan` sin aplicar.

## Hito confirmado por usuario: migraciones de localcheck

- La imagen API reconstruida leyó correctamente `/app/reminders/models.py` (`LECTURA_MODELS_OK=True`).
- Plan confirmado: `0010_workspace_insurer` (catálogo + relación), `0011_renewal_policy_identity` (cinco campos), `0012_renewal_notes` (notas), sin borrados previstos.
- El usuario ejecutó bloque con validación SHA-256 del backup, identidad del proyecto Docker, `migrate --noinput`, `showmigrations` y `migrate --plan`; informó `MIGRACIONES_VERIFICADAS=1` y `CONSOLA_ABIERTA`.
- **API y Flutter Web del stack persistente aún no se han recreado.** Siguiente paso: reconstruir/actualizar `api` y `web_preview` solo con `-p vencira_localcheck`; comprobar salud, migraciones y rutas. Mantener el backup `pre0010-0012_uti0uvWX.dump` intacto.
- No se han activado adjuntos ni habilitado uso con datos personales reales.

## Despliegue localcheck — evidencia de servicios

- Usuario confirmó `ACTUALIZACION_SERVICIOS_COMPLETADA=1` tras `docker compose -p vencira_localcheck ... up -d --no-deps api` y `up -d --no-deps --build web_preview`.
- API `vencira_localcheck-api-1`: `running/healthy`, ligado a `127.0.0.1:28731`.
- PostgreSQL `vencira_localcheck-db-1`: `running/healthy`, sin puerto público.
- Web `vencira_localcheck-web_preview-1`: `running/starting` inmediatamente tras recreación, ligado a `127.0.0.1:28732`. **Pendiente demostrar healthy y HTTP end-to-end**.
- Stack `vencira_preview` conservado por separado en `127.0.0.1:18731/18732`.
- `nginx -t` y `manage.py check` superados en el bloque completo que el usuario ejecutó; `migrate --plan` se invocó, pero la salida textual no se adjuntó.
- Confirmación final pendiente: salud Web estable, HTTP /api/health /api/ready a través del proxy, autenticación/E2E con datos sintéticos, Android. No activar datos reales.

## Verificación posterior al despliegue — completada

Confirmado por salida del servidor: `vencira_localcheck-web_preview-1` **healthy**; API `/api/health/` y `/api/ready/` en `127.0.0.1:28731` devuelven 200. Proxy web `127.0.0.1:28732` devuelve HTTP 200 para `/`, `/api/health/`, `/api/ready/` y `/accounts/login/`. `python manage.py migrate --plan`: **No planned migration operations**. Resultado `COMPROBACION_FINALIZADA=1`, `CONSOLA_ABIERTA`.

**Queda pendiente** prueba funcional autenticada de identidad, notas, sugerencias y permisos con datos sintéticos; esta verificación HTTP por sí sola no valida funcionalidad de negocio. No introducir datos personales reales.

## Límites de lanzamiento

- **No apto para datos personales reales ni producción**. Ver `docs/SECURITY_RELEASE_READINESS_2026-10-22.md` y `docs/SECURITY.md`: MFA, backups externos cifrados/restauración, cifrado en reposo, permisos, retención, RGPD/LOPDGDD y control de adjuntos aún pendientes.
- No habilitar upload/download de PDFs e imágenes hasta implementar controles de `docs/ATTACHMENTS_SECURITY_GATE.md`.
- No activar recordatorios reales por el mero hecho de desplegar la nueva ficha.

## En un chat nuevo

Leer primero este archivo desde GitHub y consultar las últimas confirmaciones del usuario sobre resultados del servidor. **No asumir que un PR fusionado equivale a despliegue.** Mantener el esquema `GitHub → pruebas aisladas → backup → migraciones → despliegue localcheck → Android → documentación final`. Evitar requerir al usuario información o verificaciones ya conocidas.
