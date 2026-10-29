# B07 — Restauración completa en PostgreSQL 17 temporal

## Objetivo

Restaurar una base PostgreSQL 17 con las migraciones
Django del esquema independiente de adjuntos y
contrastar sus metadatos con un paquete cifrado y diario.

## Procedimiento

1. Crear dos PostgreSQL 17 desechables en red aislada.
2. Migrar el esquema real en origen, solamente en ensayo.
3. Insertar datos sintéticos usando el ORM Django.
4. Generar inventario y paquete cifrado.
5. Ejecutar pg_dump -Fc del PostgreSQL de origen.
6. Ejecutar pg_restore sobre PostgreSQL de destino vacío.
7. Leer metadatos restaurados con el ORM Django.
8. Conciliar huellas, tamaño, contenido y diario.
9. Rechazar clave incorrecta y metadatos alterados.
10. Destruir bases y archivos temporales.

## Limitaciones y alcance

La prueba de B07 no implementa aún un orquestador
de captura atómica de producción. Aunque los datos
sintéticos permanecen estables y el exclusivo protege
su empaquetado, pg_dump se ejecuta después de liberar
el bloqueo y sin procesos escritores adicionales.

El inventario del ciphertext procede del ensayo y
no de un registro externo autenticado o custodio.

El archivo de dump está protegido por permisos locales,
pero no se incorpora todavía a un respaldo cifrado
de base de datos y adjuntos con custodia independiente.

La prueba NO manipula copias O5, datos reales ni la
base persistente. No autoriza descargas ni despliegue.

B07_RESTORE_REHEARSAL_ONLY=YES
B07_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
