# VENCIRA — D14: preparación y autorización de lanzamiento

## Alcance

Este documento distingue las pruebas técnicas de la
autorización operativa para almacenar documentos reales.

Referencia: D13 completado, commit 0ae9181.
D14 incorpora ensayos de seguridad adicionales.

## 1. Controles técnicos

| Control | Estado |
|---|---|
| Django y PostgreSQL 17 efímero | D13 OK |
| Flutter analyze/test/build web | D13 OK |
| Migraciones y rollback experimentales | D12 OK |
| Recuperación PostgreSQL O5 en clon | D12 OK |
| Coincidencia estructural DEV/O5 | D12 OK |
| Cifrado de cuarentena sintética | D12 OK |
| fsync de archivo y directorio | D12 OK |
| Recuperación de diario y archivo sintéticos | D12 OK |
| Alteración, truncamiento y claves incorrectas | D14 test |
| Aceptación visual Android/PC real | PENDIENTE |

Las pruebas sintéticas no demuestran seguridad operativa.

## 2. Bloqueos técnicos de producción

### B01 — Antivirus real

Se requiere integrar un motor operativo de análisis,
con aislamiento, límites, errores cerrados, trazabilidad,
actualización de firmas y tratamiento de resultados.

No basta con una evidencia HMAC sintética.

### B02 — Permisos HTTP

Subida, descarga, acceso entre workspaces, asignaciones,
visibilidad por usuario, eliminación y auditoría deberán
validarse mediante tests adversariales.

Las rutas de descarga no deben habilitarse antes.

### B03 — Respaldo de adjuntos y diario

O5 actual demuestra respaldo de PostgreSQL, no de objetos.

Se requiere un backup cifrado, versionado, verificable,
con inventario de archivos, diario y metadatos. Cada ciclo
de recuperación debe permitir detectar desajustes entre BD,
archivos y diario.

La consistencia temporal debe diseñarse explícitamente:
no asumir que backups independientes capturados en momentos
distintos constituyen una instantánea consistente.

### B04 — Custodia y rotación

La clave de adjuntos no será la de MFA ni la de Restic.
Debe existir recuperación externa, control de acceso,
versionado y ensayo documentado de rotación. Perder una
clave antigua puede impedir recuperar objetos antiguos.

No almacenar ni mostrar claves en logs o GitHub.

### B05 — Recuperación integral

Restauración aislada en infraestructura independiente,
incluidos BD, objetos cifrados, diario y claves autorizadas;
pruebas de corrupción, pérdida parcial y reconciliación.

Definir objetivos RPO/RTO y criterios de aceptación.

## 3. RGPD — decisiones pendientes

Validar y documentar, con revisión jurídica cuando proceda:

- responsables, encargados y contratos;
- finalidad y base jurídica;
- categorías de datos y minimización;
- permisos por workspace y perfiles;
- transparencia y ejercicio de derechos;
- plazos de conservación y supresión;
- excepciones de conservación por obligaciones legales;
- respaldo, caducidad y borrado seguro;
- análisis de riesgos y necesidad de EIPD;
- registro de actividades de tratamiento;
- notificación y gestión de brechas;
- transferencias internacionales, si las hubiera.

No fijar automáticamente un plazo universal de retención
de pólizas: depende de finalidad y obligaciones aplicables.

## 4. Condiciones para habilitar documentos reales

Todas deben ser verdaderas:

1. B01–B05 implementados y validados.
2. Permisos adversariales superados.
3. Recuperación integral demostrada.
4. RGPD y documentación operativa revisados.
5. Dispositivos reales aceptados.
6. Plan de despliegue y rollback aprobado expresamente.
7. Autorización explícita separada de MFA.

## 5. Decisión vigente

D13_TECHNICAL_GATE=OK
D14_TEST_GATE=NOT_YET_VERIFIED
D14_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
