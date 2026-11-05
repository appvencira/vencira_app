# VENCIRA — Progreso G14 y pendientes (05/11/2026)

Estado basado en pruebas locales comunicadas. La aprobación de laboratorio no equivale a autorización de producción.

## Validado en laboratorio
- [x] G14-A: control de admisión.
- [x] G14-B: contrato de evidencia no confiable.
- [x] G14-C: atomicidad de operación candidata.
- [x] G14-D1: verificación bloqueada sin emisor.
- [x] G14-D2: diagnóstico y reproducción del riesgo de metadatos reutilizados (riesgo no resuelto para el emisor de bajo nivel).
- [x] G14-D3: composición sin MFA y carreras de contraseña y revocación.
- [x] G14-D4: coordinación de activación de MFA con bloqueo de cuenta.
- [x] G14-D5: 108 pruebas PostgreSQL 17, incluidos códigos de uso único y época MFA.
- [x] G14-D6: inventario estático validado, 12 archivos y 104 candidatos de revisión.

## Parcial
- [~] G14-D7: clasificación de 104 candidatos. Revisión de recuperación administrativa, enrolamiento y rotación realizada, sin auditoría completa.
- [~] Beta Android: ensayos físicos G13 positivos en su alcance. No representan aprobación del conjunto de gates.
- [~] Producto Web/Backend: desarrollo y validaciones previas en DEV; aceptación integral de funcionalidades no acreditada.

## Pendiente
- [ ] G14-D8 (propuesto): ensayos PostgreSQL de rotación frente a revocación y apertura administrativa frente a emisión.
- [ ] G14-D9 (propuesto): completar revisión del grafo de bloqueos MFA y procedimientos administrativos.
- [ ] Emisor confiable con contraseña y MFA verificadas en servidor, sin aceptar evidencia afirmada por un llamante.
- [ ] Custodia de secretos y procedimiento de recuperación administrativa operativo y autorizado.
- [ ] Reconciliación de gates de beta G0–G9, revisión integral de funcionalidades y aceptación visual.
- [ ] Permiso de release, despliegue controlado y controles posteriores.

## Reglas
No activar rutas de login nativo ni liberar el emisor de laboratorio.
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED

## Evidencias
- G14-D5: G14_D5_N1=0; G14_D5_BUILD=0; G14_D5_PG17=0; 108 tests PG17.
- G14-D6: HEAD 0f5af40d; G14_D6_TESTS=0; G14_D6_N1=0; G14_D6_INVENTORY=0; 12 ficheros, 104 candidatos.
- G14-D7: docs/G14_D7_MFA_WRITER_REVIEW_2026-11-05.md

Actualizar casillas únicamente al recibir una prueba verificable. Sin porcentaje global hasta reconciliar aceptación funcional y seguridad.
