# VENCIRA — G1 Inventario estático de escritores (01/11/2026)

## Nuevo instrumento
`scripts/mb1_g1_source_writer_inventory.py` recorre mediante AST los ficheros Python de `backend` (solo lectura) y cuenta candidatos de escritura ORM/SQL/FS y llamadas dinámicas que requieren revisión humana. Indica archivos ilegibles y errores de parseo; devuelve código distinto de cero si existen. No imprime código, credenciales ni rutas de usuario, y no toca ningún servicio.

El script está preparado pero aún no ejecutado por el operador. El análisis es HEURISTIC_ONLY: contar llamadas `.execute` o `.save` no prueba que sean escrituras, y puede omitir wrappers, comandos de sistema, scripts Bash, tareas externas, conexiones SQL, permisos reales, cron y servicios. **No acredita G1 completo ni congela escritores**.

## Comprobaciones posteriores agrupadas
1. Conciliar los contadores AST con el inventario histórico de 76 archivos/264 llamadas y 131 candidatos P0; una discrepancia no es fallo automáticamente, pues cambia la clasificación, pero debe revisarse.
2. Exigir análisis humano de cada ruta P0 y de llamadas dinámicas, incluyendo jobs, contenedores, escritor de objetos y diario. Asignar propietario y capacidad.
3. Unir ese censo a los roles de aplicación/administración y una frontera de exclusión adversarial en clon. El gate G1-G3 seguirá bloqueado si un escritor no está cubierto.

## Estado de seguridad
MB1_GLOBAL_FREEZE=NOT_VERIFIED; MB1_RELEASE_AUTHORIZED=NO; MFA_RELEASE_AUTHORIZED=NO; C_FICHA_RELEASE_AUTHORIZED=NO; NO_DEPLOY_NO_LIVE_MIGRATION=1. Hitos 1/15 (6,7%).
