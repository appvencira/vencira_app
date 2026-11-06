# VENCIRA — Integración progresiva hacia main (06/11/2026)

## Objetivo aprobado por el titular

Consolidar periódicamente en `main` el desarrollo de VENCIRA **sin exigir que todas las funciones estén terminadas o activas**. El criterio de aceptación de cada lote es que el código sea coherente, compilable cuando corresponda, aislado de componentes no autorizados y reversible. La integración Git **no equivale** a despliegue DEV/prod ni a activar autenticación o aplicar migraciones.

## Evidencia de GitHub al preparar el plan

- Comparación `main...feature/m3-android-local-notifications`: divergencia; rama de desarrollo **3653 commits por delante**, **2 detrás** (conteo de comparación, no lista completa de commits).
- HEAD de `main` observado en comparación: `5bb4707cf5118c625d769c40aa8aec9d1370155c`.
- PR #17: **draft**, base `feature/mb1-m104-transition-contract-batch` (NO `main`), `mergeable=false`, 253 ficheros cambiados indicados en la PR y 1098 commits en su alcance.
- Diferencias exclusivas de `main` detectadas en la comparación inversa: `clients/flutter/lib/ui/control_assessment_card.dart` y `scripts/c2_deploy_readiness_readonly.sh`. Se deben conservar; no sobreescribir sin revisión.
- Las estadísticas de comparación pueden estar truncadas para conjuntos masivos (la consulta devolvió 300 entradas); no asumir que esta sea una enumeración exhaustiva de archivos.
- `dev.vencira.es` sigue siendo un despliegue distinto de Git: comprobación del operador: `/` 200; `/api/health/` 200; `/api/ready/` 200; `/accounts/login/` 200; `/api/v1/me/` 403 anónimo; `/privacidad` y `/condiciones` 200, TLS verificado (`curl ssl_verify_result=0`). Esto NO valida una release beta.

## Ruta de integración

1. **I0, esta PR:** publicar este plan en una rama nacida de `main`; no tocar código operativo. Establecer inventario de dependencias y contratos.
2. **I1, solo módulos independientes:** seleccionar cambios sin dependencias ocultas: tests, documentación o soporte aislado. Revisar cada import, cambio de configuración/CI y compatibilidad con el estado real de `main`. Portar en PR pequeñas con cambios explícitos, sin arrastrar indiscriminadamente historia y rutas.
3. **I2, funcionalidades web y API:** reconciliar los dos ficheros exclusivos de `main`; seleccionar verticales de negocio completos (API, widgets, permisos, tests y migraciones) según su presencia actual, asegurando que cada PR compile y no requiera ejecutar migraciones persistentes.
4. **I3, Android:** incorporar código nativo desacoplado y sus pruebas; los laboratorios G8/G12/G13/G15 siguen diferenciados de la app real y no se conectan automáticamente a `main.dart` o a URLs operativas.
5. **I4, autenticación MFA y sesión:** mantener aislado G14-E1/E2/E3 hasta disponer de emisor de confianza atómico, auditoría, custodia, pruebas y autorización explícita. Está prohibido usar el `bool` de verificación E1 como grant de emisión. No eludir los bloqueos previos del conector.
6. **I5, aceptación y lanzamiento:** tras integración de código, pruebas de usuario, privacidad, firma APK, recuperación y puertas de seguridad; el despliegue y las migraciones requieren procedimiento/decisión separados.

## Condiciones de cada PR de integración

- Descripción precisa de los archivos y dependencias incorporados.
- Gates y tests proporcionados según el alcance; no repetir baterías históricas sin modificaciones relevantes.
- No se mergea por un marcador de éxito de laboratorio: las pruebas deben ejecutarse para el HEAD correspondiente.
- Ningún cambio de comportamiento de `dev.vencira.es` por el mero merge.
- `MFA_RELEASE_AUTHORIZED=NO`, `MB1_RELEASE_AUTHORIZED=NO`, `C_FICHA_RELEASE_AUTHORIZED=NO`, `NO_DEPLOY_NO_LIVE_MIGRATION=1` hasta que existan autorizaciones nuevas y explícitas.

## Estado

`I0=PLAN_PREPARADO`. Las PR siguientes son las que realmente moverán código de producto hacia `main`. No se atribuye integración de código funcional a esta PR documental.
