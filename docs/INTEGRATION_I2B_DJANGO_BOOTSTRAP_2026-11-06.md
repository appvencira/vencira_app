# I2-B1 — Traspaso de estructura Django existente a main

## Alcance
Esta PR añade desde `feature/m3-android-local-notifications`, sin reescribir lógica: `backend/manage.py`, `backend/requirements.txt`, `backend/config/{__init__,asgi,wsgi,views,settings,urls}.py` y `backend/reminders/{__init__,apps}.py`. Se preserva el código I1 y el archivo Flutter exclusivo de `main`.

**No es aún un backend completo ni ejecutable.** La configuración original referencia middleware, autenticación MFA, URLs y modelos de `reminders` todavía ausentes de `main`. No ejecutar `manage.py runserver`, `manage.py migrate` ni utilizar esta rama como imagen de producción. No se incorpora Dockerfile a este lote para evitar presentar la estructura parcial como imagen instalable.

El contrato de seguridad original conserva el acceso DRF con sesiones; la app de sesiones nativas y el candidato móvil solo son registrables en `VENCIRA_ENV=test` cuando se habilitan expresamente. La variable de bearer permanece `False`. Esto no implica prueba de comportamiento runtime.

## Gate dirigido
`python3 scripts/i2b_django_bootstrap_source_gate.py` verifica la sintaxis de los archivos copiados, invariantes estáticas de la configuración y **enumera las dependencias de runtime que aún faltan**. El indicador `I2B_DJANGO_RUNTIME=BLOCKED_INCOMPLETE_DEPENDENCIES` es **correcto y esperado**; no equivale a gate rojo de integridad del traspaso. `I2B_BOOTSTRAP_SOURCE=OK` solo avala este alcance.

CI `.github/workflows/i2b-django-bootstrap.yml` ejecuta el gate y el gate anterior I2-A sin Django ni Docker. La validación de la PR aún no está confirmada.

## Siguientes pasos
I2-B2: portar los módulos y migraciones de `reminders` de forma íntegra y revisada por dependencias, o dividir por verticales funcionales sin cambiar el grafo de migraciones. Solo entonces ejecutar los tests reales Django/SQLite/PG17; nunca aplicar migraciones a la BD persistente por el mero merge. Más adelante incorporar Flutter de manera coherente (pubspec, l10n, lib, Android) sin activar laboratorios ni autenticar con emisor sin revisar.

`MFA_RELEASE_AUTHORIZED=NO`; `MB1_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
