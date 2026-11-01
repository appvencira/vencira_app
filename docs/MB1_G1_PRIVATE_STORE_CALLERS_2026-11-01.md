# VENCIRA — G1 trazabilidad de llamadores del almacén privado (01/11/2026)

## Publicado
`scripts/mb1_g1_private_store_callers.py` busca en los archivos Python de la rama activa los imports y llamadas explícitas a `PrivateQuarantineStore`, `put_quarantine`, `discard_quarantine` y `read_quarantine_for_scanner_only`. Clasifica cada coincidencia como TEST, LAB o RUNTIME_OR_UNKNOWN, con ruta relativa y línea. Se añadió al workflow `.github/workflows/mb1-audit.yml`.

## Límites
La búsqueda del conector GitHub sobre la rama predeterminada devolvió cero coincidencias para estos símbolos: no es una prueba de ausencia en la rama de trabajo. El nuevo script rastrea el código efectivo de checkout, pero no detecta referencias por reflexión, alias complejos, subprocess, scripts no Python o código inyectado. Cualquier invocación interna de borrado necesita revisión de autorización previa, identidad SQL y diario. El escaneo no ejecuta los módulos inspeccionados.

**Pendiente ejecución CI y revisión de los resultados.** No se ha establecido un inventario cerrado de llamadores ni se ha demostrado que no existan rutas operativas. `MB1_GLOBAL_FREEZE=NOT_VERIFIED`; `MB1_RELEASE_AUTHORIZED=NO`; `NO_DEPLOY_NO_LIVE_MIGRATION=1`. Total hitos cerrados: 1/15.
