# O8c — Ajuste de espaciado móvil en borradores (25/10/2026)

## Evidencia y alcance

El usuario aportó capturas reales de `https://dev.vencira.es/`, en móvil Android, con anotación de prueba y `Borrador guardado`, entrada `20,15` y advertencia `Sin aviso anterior al límite informativo.`. Esto prueba que la sección muestra el borrador personalizado; no prueba aún, por sí solo, el aislamiento respecto de una segunda anotación ni el control de concurrencia en navegador. Resultado comunicado `RESULTADO_EJECUCION=0`, pero no asociado a una prueba de interfaz automatizada nueva.

**Problema visual constatado:** la etiqueta flotante `Días antes` queda demasiado cerca de `Borrador guardado`; la advertencia informativa se pega al botón `Guardar solo borrador`. La pantalla muestra el simulador O8b predeterminado `60,45,35` encima del borrador persistido `20,15`; son funciones separadas por diseño. No confundir preview con configuración guardada.

## Cambio acotado a Flutter Web

- `clients/flutter/lib/ui/reminder_draft_card.dart`: `Padding(bottom: 20)` tras el texto de estado, separando la etiqueta flotante del campo; `SizedBox(height:16)` tras campo/ayuda y `Padding(bottom:12)` después de cada advertencia de vencimiento o Vida antes del botón. Conserva ES/CA, validación, datos y API.
- `clients/flutter/test/reminder_draft_test.dart`: pruebas 320 px para ES/CA con temas claro/oscuro, afirmando separación de estado/campo y aviso/botón, sin errores ni escrituras. Mantiene los tests funcionales previos.
- Nuevo `scripts/deploy_o8c_spacing_web_only.sh`: despliegue **solamente del servicio `web_preview`** de `vencira_localcheck`. Exige rama limpia y fuente fijada al commit de corrección `0f9c17b03fde147d780fdcff5fc2d3e162488a0c` (sin cambios posteriores en backend/clients/compose/deploy), health, `reminders.0015_renewal_reminder_drafts`, O5 lectura, guarda imagen anterior con etiqueta exclusiva, compila solo Flutter Web y recrea solo Web `--no-deps --no-build`; verifica contenedores API/DB idénticos, 0015 intacta, HTTP y sesión 401/403. **No migra, ni ejecuta scripts O4/O8c de migración, ni reinicia API/DB ni reconfigura O5.**

## Validación requerida antes de deploy web

Tras sincronizar GitHub, ejecutar primero `bash -n scripts/deploy_o8c_spacing_web_only.sh` y `bash scripts/validate_o7_o8_preflight.sh`: suite Django SQLite y PG17 temporal, Flutter analyze/tests dirigidos+completos y compilación web. Solo si marca `RESULTADO_GLOBAL=0`, ejecutar `bash scripts/deploy_o8c_spacing_web_only.sh`. Si falla la fase Web después de recreación, **no repetir a ciegas**, revisar el recibo e imágenes; no restaurar PG. Sin salida real no declarar nuevo espaciado desplegado.

## Aceptación manual

Abrir ficha en móvil de 320–420 px, estado «Borrador guardado», anticipaciones `20,15`. Comprobar que estado y etiqueta `Días antes` no se tocan, que la advertencia tiene margen con el botón y que sigue funcionando guardado/recarga de borrador. Repetir en ES y, cuando sea posible, CA. Comparar otra anotación DEMO sin reglas para comprobar defaults independientes. No activar notificaciones.
