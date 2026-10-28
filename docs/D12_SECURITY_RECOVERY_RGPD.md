# VENCIRA — D12: seguridad, recuperación y RGPD

## Controles técnicos validados

- PostgreSQL 17: migraciones 0001–0005 y reversión
  sobre esquema vacío y temporal.
- Conciliación histórica: registros sintéticos,
  comparación estricta de metadatos.
- O5: restauración de PostgreSQL en clon aislado.
- DEV y O5: esquema 0018, 36 migraciones en ambos.
- Prueba sintética de recuperación de archivo Fernet
  y diario de intención.
- Confirmación fsync del archivo y del directorio.

Estas verificaciones no autorizan producción.

## Custodia de claves

La clave de adjuntos deberá:

1. Ser independiente de MFA, Django y Restic.
2. Estar custodiada fuera del VPS y del repositorio.
3. Disponer de recuperación por personal autorizado.
4. Tener control de versiones y procedimiento de rotación.
5. Permitir recuperar objetos anteriores durante la rotación.
6. Impedir registrar secretos en logs, auditorías o tickets.

La custodia externa real NO se ha verificado.

## Recuperación ante desastre

O5 respalda PostgreSQL. No demuestra que incluya
el diario de intenciones ni el almacén cifrado.

Antes de producción deberá existir un procedimiento
integral con:

- respaldo cifrado de PostgreSQL, diario y archivos;
- coordinación de instantáneas y versiones de claves;
- restauración probada en servidor diferente;
- reconciliación completa tras restaurar;
- pruebas de corte de energía y fallo del volumen;
- política de retención y borrado de respaldos.

La copia sintética no equivale a un respaldo operativo.

## RGPD — requisitos de aprobación

Pendientes de revisión jurídica y operativa:

- base jurídica y finalidad del tratamiento;
- roles y acuerdos con proveedores encargados;
- minimización de datos y permisos por workspace;
- política de conservación y plazos de supresión;
- derechos de acceso, rectificación y supresión;
- protección y retención de archivos de backup;
- trazabilidad de acceso, cambios y eliminación;
- respuesta ante incidentes y brechas;
- evaluación de riesgos y, si procede, EIPD.

No declarar conformidad RGPD hasta completar
las evaluaciones y aplicar los controles necesarios.

## Bloqueos actuales

- Antivirus operativo pendiente.
- Autorización completa de subida/descarga pendiente.
- Backups cifrados de adjuntos y diario pendientes.
- Custodia y rotación de claves reales pendientes.
- Recuperación física integral pendiente.
- Revisión RGPD pendiente.

D12_SECURITY_DOCUMENTED=YES
D12_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
