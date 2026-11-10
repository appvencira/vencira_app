# VENCIRA — D1-O regresión integral de candidato (09/11/2026)

## Estado

**PUBLICADO EN MAIN; NO EJECUTADO EN VPS. NO ES PASS.**

D1-N ya superó restauración O5 auténtica, aplicación de reminders.0019–0027 y rollback a 0018 en un PostgreSQL17 temporal. B2 Flutter 7/7 PASS con API sintética. Estos resultados no certifican ni contrato HTTP ni compilación web completa.

## Alcance publicado

- `scripts/main_d1o_candidate_integral_gate.sh`: comprueba checkout limpio con HEAD idéntico a `origin/main` (también admite HEAD detached), identidad de los tres contenedores DEV por labels e IDs, crea red Docker `--internal`, PostgreSQL17 con PGDATA `tmpfs`, imagen Django candidata y credenciales **sintéticas** privadas en `/tmp`. No lee ni monta la BD ni configuración DEV.
- Ejecuta `manage.py check --deploy`, `makemigrations --check --dry-run`, `migrate` **solo en DB sintética temporal**, los tests específicos HTTP de D1-O y `manage.py test reminders` con base de test PostgreSQL desechable.
- `backend/reminders/test_d1o_release_contract.py`: verifica URLs nativas de muestra no resueltas, middleware/DRF de sesión sin bearer, acceso anónimo protegido, POST login sin CSRF rechazado y enrolamiento MFA deshabilitado. **La muestra de URLs no prueba ausencia de todos los alias**: debe inspeccionarse `config.urls` antes de una promoción.
- Copia `clients/flutter` dentro de contenedor temporal Flutter 3.44.0, realiza `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web --release` y comprueba artefactos web. Esta fase puede acceder a internet para dependencias; no recibe redes, mounts ni secretos DEV.
- Trampa de salida elimina red, contenedor PG17, imagen Django y fichero de variables; verifica IDs originales de contenedores DEV. El gate **aborta** ante errores: un `RESULT=0` requiere que todos los pasos terminen con éxito.

### Límites

- La base PG17 de D1-O es **sintética**, no repite D1-N histórico.
- Las pruebas HTTP usan `django.test.Client`, no peticiones HTTPS reales a Caddy ni una sesión real del navegador.
- No se realiza inventario completo de manifiesto Compose/Caddy en este gate ni se prueban adjuntos con archivos reales.
- `manage.py check --deploy` puede emitir warnings: esta versión verifica código de salida, no garantiza ausencia de avisos. Los warnings deben revisarse antes del despliegue.
- La suite Django completa puede incluir dependencias no preparadas para esta variante de laboratorio. Un fallo es **FAIL/PENDIENTE DE DIAGNÓSTICO**, no se puede atribuir automáticamente a código de producción.
- No demuestra login nativo Android operativo ni valida UI física.
- No certifica rollback de imágenes web ni ejecución de migraciones en DEV. No imprime datos reales, porque utiliza fixtures sintéticos.

## Ejecución en Termius — única validación pendiente

Revisión previa del ejecutor recomendable por ser Docker vía sudo. Desde el checkout independiente:

```bash
cd ~/vencira-main-check-20261108
git fetch origin main
git merge --ff-only FETCH_HEAD
git status --short
bash scripts/main_d1o_candidate_integral_gate.sh
echo "D1O_SHELL_RESULT=$?"
```

Para registrar el log sin perder un código de fallo al utilizar `tee`:

```bash
set -o pipefail
bash scripts/main_d1o_candidate_integral_gate.sh 2>&1 | tee /tmp/vencira-d1o-gate.log
echo "D1O_SHELL_RESULT=${PIPESTATUS[0]}"
```

Ejecutar **una sola** de las variantes. Se requiere capacidad de Docker e internet para descargar imágenes/dependencias (si no están en caché). No copiar claves/variables locales al chat ni a GitHub.

### Aceptación

Exigir todos los marcadores, no anticiparlos:

```text
D1O_DEV_IDENTITY=PASS
D1O_INTERNAL_NETWORK=PASS
D1O_PG17_SYNTHETIC_TMPFS=PASS
D1O_CANDIDATE_IMAGE_BUILD=PASS
D1O_DJANGO_DEPLOY_CHECK=PASS
D1O_MODEL_PARITY=PASS
D1O_SYNTHETIC_MIGRATIONS=PASS
D1O_SECURITY_HTTP_CONTRACT=PASS
D1O_DJANGO_REMINDERS_SUITE=PASS
D1O_FLUTTER_ANALYZE_TEST_WEB_BUILD=PASS
D1O_CANDIDATE_INTEGRAL_GATE=PASS
D1O_DEV_CONTAINERS_UNCHANGED=OK
D1O_EPHEMERAL_CLEANUP=DONE
D1O_RESULT=0
D1O_SHELL_RESULT=0
```

Los marcadores `D1O_COMPOSE_CADDY_RUNTIME_INSPECTION=NOT_RUN` y `D1O_ANDROID_PHYSICAL=NOT_RUN` son límites expresos.

**MFA_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1; D1_RELEASE_AUTHORIZED=NO**.

## Después del gate

Si D1-O pasa, aún quedará validación HTTPS/CSRF contra Caddy, permisos de ficha/adjuntos con fixtures adecuados e inventario/rollback exacto del Compose real para una promoción DEV. Ningún resultado permite desplegar sin **autorización específica posterior**. Mantener Android nativo como pista independiente.


## Resultado aportado por el operador (10/11/2026)

**D1-O PASS en el alcance ejecutado.** El operador comunicó los siguientes marcadores, tras resolver una discrepancia entre `HEAD` y la referencia local `origin/main` y excluir `scripts/__pycache__/` con `.gitignore` (commit `f246bae3`):

```text
D1O_DEV_IDENTITY=PASS
D1O_INTERNAL_NETWORK=PASS
D1O_PG17_SYNTHETIC_TMPFS=PASS
D1O_CANDIDATE_IMAGE_BUILD=PASS
D1O_DJANGO_DEPLOY_CHECK=PASS
D1O_MODEL_PARITY=PASS
D1O_SYNTHETIC_MIGRATIONS=PASS
D1O_SECURITY_HTTP_CONTRACT=PASS
D1O_DJANGO_REMINDERS_SUITE=PASS
D1O_FLUTTER_ANALYZE_TEST_WEB_BUILD=PASS
D1O_COMPOSE_CADDY_RUNTIME_INSPECTION=NOT_RUN
D1O_ANDROID_PHYSICAL=NOT_RUN
D1O_MFA_NATIVE_PUBLIC_ENABLED=NO
D1O_CANDIDATE_INTEGRAL_GATE=PASS
D1O_DEV_CONTAINERS_UNCHANGED=OK
D1O_EPHEMERAL_CLEANUP=DONE
D1O_DEPLOY_EXECUTED=NO
D1O_LIVE_MIGRATIONS_EXECUTED=NO
D1O_RESULT=0
```

La salida mostrada **no incluye** `D1O_SHELL_RESULT`; el propio `D1O_RESULT=0` emitido por la trampa de salida es evidencia del resultado del script. No inventar marcador de shell. Se observó un primer intento `sudo` erróneo seguido de autenticación suficiente para ejecutar el gate. El aviso de `flutter build web` sobre dry-run WASM no es un fallo de compilación.

**No equivale a test de HTTPS/Caddy real ni a prueba integral de autorización de adjuntos.** Sigue prohibido despliegue y migración DEV; planificar D1-P de contrato HTTPS externo de solo lectura y revisión de rollback Compose, sin usar datos privados ni iniciar acciones persistentes.
