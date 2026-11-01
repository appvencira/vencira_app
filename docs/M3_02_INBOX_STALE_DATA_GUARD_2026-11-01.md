# VENCIRA — M3-02: bloqueo de acciones sobre bandeja obsoleta

## Problema revisado
`clients/flutter/lib/ui/operational_inbox_screen.dart` conservaba la última lista durante la recarga. Si la petición terminaba en un error, establecía `_failed=true` pero volvía a mostrar `inbox.items` y permitía abrir detalles o lanzar acciones sobre datos no actualizados.

## Corrección en rama aislada
La lista solo se representa si `_failed` y `_unauthorized` son falsos. Las acciones de detalle, menú y modificación también quedan bloqueadas si existe fallo de actualización o pérdida de autorización; el botón de reintento sigue disponible. La lista permanece internamente para evitar saltos durante las recargas correctas, sin presentarse tras un error. No cambia contratos del backend ni estados en PostgreSQL.

El workflow `m3-product-contracts.yml` añade un job Flutter con `flutter analyze` y el test existente `operational_inbox_test.dart` junto a las comprobaciones Django. **No hay PASS de Actions observado**; faltan pruebas de widget de fallo de recarga y aceptación Android. M3-02 sigue abierto, 2/15 (13,3%).

Sin tocar DEV, sin despliegue ni migraciones.
