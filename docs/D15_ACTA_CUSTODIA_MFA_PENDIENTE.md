# VENCIRA — Acta de custodia MFA (plantilla; NO CUMPLIMENTADA)

Estado inicial: PENDIENTE. Esta plantilla nunca equivale a autorización.
No registrar claves Fernet, contraseñas, recovery codes, tokens, rutas
privadas completas, capturas de secretos ni identificadores de bóveda.

## Custodios y segregación
- Custodio A: [rol, designación aprobada, fecha]
- Custodio B: [rol, designación aprobada, fecha]
- Ambos tienen accesos independientes y no comparten credenciales: [verificado/no]
- El material de recuperación se conserva fuera del VPS y no depende de una única cuenta/proveedor: [verificado/no]
- Recuperación ante pérdida del VPS documentada: [sí/no]

## Prueba de restauración
- Entorno aislado sin secretos operativos en los registros: [sí/no]
- Identificador de acta privada (sin datos sensibles): [referencia]
- Fecha UTC: [fecha]
- Dos custodios presentes con constancia de aprobación separada: [sí/no]
- Descifrado de muestra cifrada usando material custodiado: [correcto/error]
- Integridad de muestra y pertenencia a usuario comprobadas: [sí/no]
- Material temporal destruido y verificado: [sí/no]
- Incidencias/plan de respuesta: [referencia]

## Puerta de publicación
CUSTODIA_EXTERNA_REAL=PENDING hasta revisión humana independiente.
No usar esta acta como variable de entorno, bandera o autorización automática.
Son autorizaciones distintas: (1) despliegue de esquema con MFA OFF,
(2) activación/enrolamiento tras pruebas UAT y controles efectivos.
Actualmente MFA_RELEASE_AUTHORIZED=NO.

## Evidencia comunicada de recuperación individual (27-10-2026)
El operador, administrador único, informa que creó Bitwarden con segundo factor, una exportación protegida por contraseña en medio USB independiente y verificó la recuperación del testigo Fernet desde ese respaldo local: RESTAURACION_FERNET=OK. No se ha recibido ni registrado ningún secreto. Esto acredita únicamente prueba local comunicada; no demuestra dos custodios humanos, restauración de PostgreSQL, configuración de claves en VPS ni verificación independiente de identidad. El modelo de custodio único requiere revisión y aceptación formal del riesgo antes de autorizar MFA. CUSTODIA_OPERATIVA_APROBADA=NO; MFA_RELEASE_AUTHORIZED=NO.

## Compatibilidad local comunicada (27-10-2026)
Administrador único confirma ejecución local sin VPS ni BD, recuperando material custodiado: COMPATIBILIDAD_VENCIRA_FERNET=OK, AISLAMIENTO_POR_USUARIO=OK, NO_VPS_NO_DB=1. La prueba utiliza las funciones de cifrado de VENCIRA; no se aportó clave ni token. El resultado no acredita provisión en VPS, restauración PostgreSQL ni autorización de producción. MFA_RELEASE_AUTHORIZED=NO.

## Verificación Docker sintética comunicada
El operador ejecutó en aislamiento el commit b34da22c57b41ba052270ea5e23357db5bd86bfa y confirmó MFA_DOCKER_SECRET_NONROOT=OK, MFA_FERNET_SYNTHETIC_ROUNDTRIP=OK, MFA_NO_CROSS_USER_DECRYPT=OK, FERNET_DOCKER_RESULT=0, RESULTADO_FINAL=0 y NO_DEPLOY_NO_LIVE_MIGRATION=1. Sin claves reales, servicios activos ni PostgreSQL persistente. Pendiente la provisión operativa autorizada y verificación de entrega/identidad; MFA_RELEASE_AUTHORIZED=NO.

## Validación de override Compose opcional
El operador comunica la validación estática del commit db5568ac7d96fdd6b58190f112822de82f294c4f: MFA_COMPOSE_OPTIONAL_MOUNT=OK, MFA_ENROLLMENT_DISABLED=OK, NO_DEPLOY_NO_MIGRATION=1 y RESULTADO_FINAL=0. No se han instalado secretos reales ni montado claves en contenedores activos. Persisten los requisitos de verificación externa de identidad, entrega segura y autorización independiente para activar MFA. MFA_RELEASE_AUTHORIZED=NO.
