# I2 — Base de integración continua hacia main

## Lo verificado en GitHub

- PR #19: núcleo de calendario fusionado en `main`, commit `7cf7b2bc1de87b9ae1287b69f7fcf5c535564b7d`, 8/8 pruebas locales.
- El `main` actual **no incluye** `backend/config/settings.py` ni `clients/flutter/pubspec.yaml`. Por tanto, no puede tratarse todavía como una instalación íntegra de Django/Flutter.
- Los archivos exclusivos de la rama principal respecto a la rama avanzada incluyen `clients/flutter/lib/ui/control_assessment_card.dart` y `scripts/c2_deploy_readiness_readonly.sh`; este lote los preserva.
- La rama avanzada contiene material test-only de MFA y Android. No copiarla íntegra para eludir sus límites de seguridad.

## Este lote

Se añade `scripts/i2_main_foundation_gate.py`, que valida por AST la presencia y sintaxis de los tres módulos de calendario, conserva los dos archivos exclusivos de main, detecta qué componentes de estructura base Django/Flutter existen y ejecuta las ocho regresiones I1 mediante Python stdlib.

Se añade `.github/workflows/i2-main-foundation.yml` con checkout + Python 3.12 + el gate anterior. No incluye secretos, Docker, credenciales, Django, Flutter, acciones de despliegue ni migración. Un fichero presente no implica que su función esté probada: `FILES_PRESENT_UNVERIFIED` no es PASS de Django/Flutter.

**Estado: fuente publicada, sin evidencia de CI/ejecución para el HEAD de la PR.**

## Ruta siguiente

I2-B: portar Django + Flutter como un conjunto coherente después de inventariar dependencias reales, imports, migraciones y workflows. Hacerlo sobre rama derivada de main; no activar endpoints, almacenamiento persistente, MFA ni aplicación Android operativa por un merge.

`MFA_RELEASE_AUTHORIZED=NO`; `MB1_RELEASE_AUTHORIZED=NO`; `C_FICHA_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`.
