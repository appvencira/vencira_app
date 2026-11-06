# I1 — Integración del núcleo de calendario en main

Este lote porta **sin modificaciones funcionales** tres módulos del desarrollo avanzado a una rama nacida de `main`:

- `backend/reminders/legal_deadlines.py`: un mes civil anterior a una fecha; no equiparar automáticamente a plazo legal aplicable a todas las pólizas.
- `backend/reminders/default_reminders.py`: propuesta inerte de 60/45/35 días, sin programación.
- `backend/reminders/reminder_planning.py`: planificación y vista previa sin persistencia, envíos ni automatizaciones.
- `scripts/test_i1_calendar_core.py`: ocho comprobaciones de Python stdlib, sin Django ni base de datos.

## Por qué se integran separados

A fecha de esta revisión, `main` no contiene `backend/config/settings.py` ni `clients/flutter/pubspec.yaml`, mientras que la rama de desarrollo sí. Por tanto es prematuro portar pantallas y API completas sin un bloque de estructura Django/Flutter. Estos módulos solo importan la biblioteca estándar y entre sí.

## Validación pendiente (no simular PASS)

```bash
git fetch origin integration/i1-calendar-core-20261106
git switch --detach FETCH_HEAD
python3 -m unittest discover -s scripts -p test_i1_calendar_core.py -v
```

La prueba puede ejecutarse también en un checkout temporal; evitar cambiar la rama del entorno operativo y **no ejecutar sobre el directorio de despliegue**. El estado de CI del HEAD no se ha verificado en esta PR. Se exige salida `Ran 8 tests`, `OK` y revisión de la diff antes de integrar.

No se despliega, migra ni se registra un nuevo endpoint. `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
