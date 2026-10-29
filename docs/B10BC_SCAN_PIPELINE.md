# VENCIRA — B10B/C: circuito de escaneo experimental

## Flujo probado

1. Comprobar que la ficha documental está en cuarentena.
2. Verificar tamaño y SHA-256 del contenido sintético.
3. Invocar el adaptador de ClamAV, sustituido en los tests
   por resultados controlados de escaneo.
4. Aceptar únicamente retorno limpio.
5. Construir evidencia HMAC de ensayo.
6. Comprobar el fingerprint de la ficha y persistir evidencia
   bajo barrera PG17 compartida.
7. Mantener el documento en cuarentena.

Fallos del escáner, infecciones, alteración de bytes,
cambio de metadatos o repetición de evidencia bloquean
el registro limpio.

## Límites de seguridad

El firmante y el escáner se inyectan en el proceso de
ensayo. Esto NO representa aislamiento de servicio.

No se utiliza ClamAV real en estas pruebas: el adaptador
existente ya fue ensayado por separado anteriormente.

Los bytes de ensayo se proporcionan en memoria; falta
integrar lectura y descifrado controlado del almacén.

El fingerprint se vuelve a comprobar al persistir,
pero aún no constituye un protocolo completo de
control de acceso al contenido.

No hay transición automática a CLEAN, descarga,
eliminación HTTP ni documentos reales.

## Siguiente objetivo

- Integración con almacén cifrado de cuarentena.
- Aislamiento de servicio firmante y motor ClamAV.
- Autorización de lectura bajo revisión de seguridad.
- Tests HTTP de endpoints cerrados y compatibilidad Flutter.

B10BC_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
