# D2-D — validación agrupada de interacciones Flutter (móvil/escritorio)

Fecha: 11/11/2026. **Estado: PREPARADO, NO VALIDADO EN VPS.**

## Progreso verificado

Tramo anterior D1-Z, D2-A, D2-B y D2-C: **4/4 gates PASS = 100 % de aquel tramo específico**. D2-D es un gate **nuevo**, no reabre los cuatro anteriores. Para la secuencia extendida D1-Z→D2-D: **4/5 gates completados = 80 %**. Esta métrica NO representa desarrollo total, seguridad de producción ni autorización de publicación.

## Objetivo y controles agrupados

D2-D incluye un único script `scripts/main_d2d_flutter_ui_grouped_isolated.sh` que usa una copia temporal de `clients/flutter` montado solo lectura en `ghcr.io/cirruslabs/flutter:3.44.0`. Ejecución en container `--rm` y `tmpfs`. No monta base de datos, secretos, volúmenes operativos ni contenedores DEV. Comprueba identidad de los tres contenedores DEV antes/después.

Subgates:

- `flutter analyze --no-pub` después de resolver dependencias.
- `flutter test --no-pub test/d2d_real_editor_gestures_test.dart`: gestos reales en el motor de widgets Flutter, 390×844 y 1280×800: abrir editor, comprobar validación obligatoria, introducir nombre, seleccionar Entrada Clientes mediante hoja de opciones, abrir selector de fecha Material y confirmar, escribir notas y guardar; verificar `VenciraRenewalInput` devuelto. También edición de anotación ficticia preexistente y cancelación sin resultado.
- `flutter test --no-pub test/renewal_editor_test.dart`: regresión existente de selección de Entrada y Modalidad y textos es/ca.

**Precisión:** Flutter `testWidgets` ejercita gestos reales sobre los widgets, pero no es un test de clics en Chromium sobre Flutter Web compilado ni un test de persistencia backend. D2-C ya verificó por separado el contrato autenticado, CRUD y agenda sobre PostgreSQL sintético. La unión de evidencias no implica que un flujo completo GUI→backend esté probado; ese es un gate independiente posterior.

## Ejecución en Termius

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main
bash -n scripts/main_d2d_flutter_ui_grouped_isolated.sh
bash scripts/main_d2d_flutter_ui_grouped_isolated.sh
echo "D2D_SHELL_RESULT=$?"
```

Marcadores **esperados, aún NO observados**:

```text
D2D_DEV_IDENTITY=PASS
D2D_FLUTTER_ANALYZE=PASS
D2D_REAL_EDITOR_GESTURES=PASS
D2D_EXISTING_EDITOR_REGRESSION=PASS
D2D_FLUTTER_UI_GROUP=PASS
D2D_REAL_CHROMIUM_GUI_CLICK_VERIFIED=NO
D2D_REAL_DEV_DATA_USED=NO
D2D_FLUTTER_EDITOR_DESKTOP_MOBILE_GROUP_GATE=PASS
D2D_DEV_CONTAINERS_UNCHANGED=OK
D2D_RESULT=0
```

En caso de fallo Flutter, el test debe mantenerse FAIL hasta corrección fundamentada, sin ocultar excepciones ni relajar expectativas para forzar aprobación.

## Límites y prohibiciones

El script usa red Docker predeterminada únicamente para que Flutter pueda resolver dependencias; **no se presenta como una red completamente aislada sin acceso exterior**. El código del proyecto se monta en solo lectura y se copia a `tmpfs`; no monta credenciales ni DB. Este gate no controla aún accesibilidad real, fuentes Google Fonts, responsividad visual completa, historial operativo ni rollback de un despliegue persistente.

```text
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
D2D_RELEASE_AUTHORIZED=NO
D2D_DEPLOY_EXECUTED=NO
D2D_LIVE_MIGRATIONS_EXECUTED=NO
D2D_LIVE_RESTORE_EXECUTED=NO
```

No ejecutar migraciones, despliegues ni MFA real.
