# VENCIRA · Auditoría UX de fluidez y refrescos — 25/10/2026

## Motivación y síntoma reproducido

Tras el despliegue de la cuadrícula 2×2 de la Bandeja, el operador observó en Android, tema oscuro:
1. Al pulsar «Buscar» y «Limpiar filtros», parpadeo y desplazamiento vertical repentino.
2. En la Bandeja de avisos, al elegir cualquiera de los cuatro filtros, las celdas parecían subir momentáneamente y regresar.
3. Se solicitó revisar la app completa para evitar cargas que desmontan y reinsertan componentes.

## Diagnóstico (auditado directamente en el código Flutter)

La pantalla de Inicio ejecutaba `_renewals = null` en `_loadRenewals`, eliminaba los resultados al tener `_loadingRenewals=true`, y sustituía la vista por un spinner superior. La altura del `ListView` disminuía bruscamente; Android/Chrome reajustaba el offset de scroll. Además, `TextField.enabled = !_loadingRenewals` deshabilitaba temporalmente la búsqueda y podía perder el foco del teclado.

La Bandeja ejecutaba `_inbox = null` en cada `_load`; los cuatro filtros se reconstruían justo al desaparecer contadores y tarjetas. El mismo patrón apareció en Agenda, Archivo, Detalle, Resultados, Catálogos, Borrador y evaluaciones.

## Cambios de código

| Pantalla/archivo | Corrección |
|---|---|
| `dashboard_screen.dart` | Conservar anotaciones durante consulta del mismo workspace; reserva de indicador de 3px; filtros y campo de búsqueda no se deshabilitan mientras llega petición; requests concurrentes protegidas por `_sequence`; conservar workspace y selección al actualizar; limpiar al cambiar membresía o perder sesión |
| `operational_inbox_screen.dart` | Conservar resumen y tarjetas al cambiar filtro o actuar; barra fina en altura fija; impedir pulsaciones en tarjetas de respuesta anterior mientras carga; no mostrar datos si autorización falla |
| `day_agenda_screen.dart` | Conservar el día y los marcadores al refrescar mismo periodo; descartar los eventos únicamente al cambiar día; indicador en altura constante |
| `renewal_detail_screen.dart` | Mantener ficha, seguimiento manual ya consultado e historial cargado durante sus refrescos; no mostrar ficha sin autorización |
| `renewal_archive_screen.dart` | Preservar tarjetas de archivo en recargas; indicador de altura fija y vaciado al perder autorización |
| `results_screen.dart` | Evitar que métricas se desmonten durante recargas |
| `month_agenda_screen.dart` | Conservar mes al actualizar; al navegar a otro mes reservar 350px durante la carga para impedir colapso brusco |
| `modality_catalog_screen.dart` y `insurer_catalog_screen.dart` | Mantener filas visibles durante búsquedas/actualizaciones; borrar caché al perder autorización |
| `reminder_draft_card.dart`, `reminder_preview_card.dart`, `control_assessment_card.dart` | Mantener paneles y campos montados durante consulta de la misma anotación; invalidación explícita de caché al cambiar de ficha/organización |

No cambia el contrato backend, las reglas de aviso, idempotencia, casuística civil, autorización ni la base de datos.

## Pruebas nuevas

- `clients/flutter/test/widget_test.dart`: petición deliberadamente pendiente con `Completer`; verificar altura de scroll, desplazamiento vertical y que Buscar / Limpiar no vacían resultados ni deshabilitan el campo.
- `clients/flutter/test/operational_inbox_premium_test.dart`: petición lenta en el cambio de filtro; comprobar que las cuatro opciones y la tarjeta conservan coordenadas verticales durante la espera y tras resolverla.
- Suites existentes de navegación, catálogo, agenda, fichas y permisos.

## Validación pendiente / protección operativa

**ESTADO: CÓDIGO REVISADO EN GITHUB; NO SE HA PROBADO NI PUBLICADO ESTA CORRECCIÓN.**

Operador Ubuntu:
```bash
cd /home/vencira/vencira-localcheck
git pull --ff-only origin integration/local-e2e-prep
bash scripts/validate_macro_b_readonly.sh
```
El gate corre Django SQLite/PostgreSQL 17 aislados, Flutter analyze/test/build y build con la versión exacta del Dockerfile (`ghcr.io/cirruslabs/flutter:3.44.0`). Solo aceptar `MACRO_B_GATE_RESULTADO=0` y `FLUTTER_WEB_DOCKERFILE_PIN=OK`.

Tras gate verde:
```bash
bash -n scripts/deploy_macro_b_premium_ui_web_guarded.sh
sudo env MACRO_B_PREMIUM_UI_CONFIRM=DEPLOY_PREMIUM_WEB_DEV \
  bash scripts/deploy_macro_b_premium_ui_web_guarded.sh
```
El script es SOLO WEB; comprueba fuentes iguales al pin `e0fd537077dde84004af2adac5070bd8e0262003`, protege la versión anterior, mantiene API/DB, y valida esquema 0018 inalterado.

No repetir despliegue si falla. El operador deberá probar en Android:
- Buscar y Limpiar filtros desde scroll intermedio e inferior de Inicio.
- Cuatro filtros de Bandeja, repitiendo desde mitad de la lista.
- Refrescar manualmente, volver atrás desde una ficha, agenda diaria y mensual.
- Revisar tamaños 320/375px y temas oscuro/claro.
- Una reducción REAL de resultados puede requerir reubicar el scroll al cambiar el contenido; este cambio elimina los saltos artificiales por desmontaje temporal, no impide los cambios geométricos legítimos.

## Limitaciones y continuidad

La inspección de fuentes y nuevas aserciones no equivale a una aceptación visual real, particularmente en WebView/Chrome y con teclado virtual. No prometer ausencia absoluta de cualquier animación o ajuste de pantalla: confirmar con gate y pruebas en dispositivos.
