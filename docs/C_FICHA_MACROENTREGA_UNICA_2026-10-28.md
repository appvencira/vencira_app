# VENCIRA — C-FICHA, macroentrega única

Fecha 28-10-2026. Rama integration/local-e2e-prep. Objetivo: terminar el sistema de adjuntos de pólizas SIN fragmentar ensayos por fichero y SIN desplegar prematuramente.

## Base ya validada que NO se repite individualmente
- Ficha y contratos existentes del whitepaper §6.
- Metadatos 0027, cifrado sintético, scope owner/asignado/tenant, preinspección.
- Firma/verificación de veredictos sintéticos, adaptador ClamAV simulado.
- ClamAV real detectó EICAR en un contenedor aislado.
- PG17 temporal 0027 y pruebas integradas comunicadas con resultado 0.
- Ninguna base productiva migrada; MFA sigue bloqueado.

## Entrega de código incorporada en este bloque
- API de metadatos de adjuntos con comprobación de organización y visibilidad de anotación, devolviendo estado de operaciones desactivadas. No se exponen rutas privadas ni hashes/identificadores de objeto.
- Endpoints POST upload, GET download y DELETE: rechazados de forma explícita.
- Pantalla premium de documentos en ficha con bloqueo visible ES/CA, pruebas visuales móviles 320/375/768.
- Pruebas API cross-workspace, asignación, anónimo, bloqueo de modificaciones.
- Gate PostgreSQL17 temporal + Flutter actualizado para validar de una vez el código nuevo.

**No se declara completo ni listo para producción.** La macroentrega solicitada agrupa el trabajo pero el circuito operativo necesita garantías aún no construidas.

## Criterios obligatorios antes de activar adjuntos
1. Servidor de escaneo clamd realmente aislado y actualizado, comunicación Unix validada; verificaciones completas PDF/JPEG/PNG, límites memoria y fallo cerrado.
2. Pipeline de cuarentena a CLEAN con atestación verificable emitida por servicio separado, persistencia auditada y revocación por cambio de contenido, actualización de firmas y caducidad de resultados.
3. Almacén privado cifrado independiente de MFA, montaje read-only cuando procede, credenciales custodias, recuperación junto a snapshots O5, cuotas, restauración y eliminación segura según RGPD.
4. API real de subida, listado, descarga y eliminación con CSRF, tenant/asignación, revisión archivo/cliente, límites, idempotencia, atomicidad BD/objetos, bloqueos carreras y medidas ante objetos huérfanos.
5. Flutter documentos, galería/cámara/selector, progreso, borrado y errores, ES/CA y validación Android/PC; no leer contactos masivamente.
6. Resolver migración 0027 que depende de 0026 MFA, sin aplicar nunca MFA a producción por vía indirecta.
7. Auditoría adversaria y gate integrado final PG17 + Flutter + escáner real y restauración de claves/backup, seguida de autorizaciones expresas para publicación y cargas reales.

## Estado
C_FICHA_BACKEND_API_METADATA_ONLY=CODE_READY_UNTESTED
C_FICHA_FLUTTER_LOCKED_UI=CODE_READY_UNTESTED
C_FICHA_OPERATIONAL_UPLOAD_DOWNLOAD=BLOCKED
C_FICHA_MACRO_GATE=PREPARED_UNRUN
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1

## Gate integral comunicado por operador — SUPERADO
Candidato validado `09987ca6f3d8410c002a9e75a670dce4b61ce761`. Resultados: `C_FICHA_MIGRATIONS_MATCH_MODELS=OK`, `C_FICHA_PG17_EPHEMERAL=OK`, `C_FICHA_SCHEMA_0027_WITH_MFA_DEPENDENCY=OK`, `C_FICHA_PG17_INTEGRATED_TESTS=OK`, `C_FICHA_FLUTTER_ANALYZE_TEST_BUILD=OK`, `C_FICHA_PUBLIC_UPLOAD_DOWNLOAD=DISABLED`, `C_FICHA_LIVE_MIGRATION_0027=NOT_AUTHORIZED`, `CLEANUP=OK`, `C_FICHA_PG17_GATE_RESULT=0`, `MFA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1`, `RESULTADO_FINAL=0`. Log privado local `/tmp/vencira-c-ficha-pg17.3Bt4So9e.log`. Validación de componentes existentes: no equivale a completar el circuito operativo ni autoriza migraciones. No repetir este gate salvo modificaciones relevantes.
