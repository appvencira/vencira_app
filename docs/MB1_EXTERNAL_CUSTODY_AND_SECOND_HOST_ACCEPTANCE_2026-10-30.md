# MB1 — Procedimiento de custodia externa y prueba de recuperación independiente

**30/10/2026 · Estado: PENDIENTE DE PRUEBA REAL Y APROBACIÓN**

## Qué está probado

La ejecución del 30/10 confirmó restauración cifrada de PG17 efímero desde paquete separado, destrucción del origen sintético y rechazo sin claves. No acredita pérdida total del VPS, custodia externa ni freeze universal.

## Decisión de arquitectura

**No reutilizar ni mezclar** claves de MFA, O5/restic ni credenciales de servicios con las del conjunto de restauración de adjuntos. El material de ensayo MB1 es sintético: no constituye backup operativo. Separar físicamente:

1. **Destino A — almacenamiento externo del respaldo cifrado:** archivo de respaldo y manifiesto autenticado con versionado/retención y controles de acceso; sin claves de descifrado.
2. **Destino B — custodio independiente:** claves de cifrado y autenticación asociadas al identificador del respaldo, bajo gestor seguro controlado independientemente del VPS y de A. No subir claves a GitHub ni a documentación.
3. **Destino C — restaurador independiente:** segunda máquina/entorno aislado con PG17, sin acceso previo al VPS ni a los originales, que recibe bajo autorización los objetos cifrados de A y material necesario de B.

Que A y B sean dos carpetas en el mismo VPS **NO** es separación suficiente. Dos cuentas del mismo servicio pueden tampoco ser independientes ante compromiso del proveedor; validar modelo de amenaza y acceso.

## Secuencia fail-closed antes de considerar MB1 operativo

- [ ] El responsable determina y aprueba el custodio B y el destino A, con mecanismos de recuperación de cuenta documentados **fuera del VPS**.
- [ ] Se generan claves nuevas y exclusivas mediante CSPRNG para los respaldos operativos; se registra ID de clave, fecha y responsables sin transcribir secretos.
- [ ] Se conserva un catálogo autenticado de identidad, hashes, época de captura y políticas de retención, independiente del VPS.
- [ ] Se transfiere el paquete cifrado al destino A y las claves exclusivamente a B mediante canales diferentes.
- [ ] Se comprueba que A no posee claves y B no necesita acceso directo a datos de clientes; se auditan permisos reales.
- [ ] Se prepara C desde cero y se bloquea su red hacia el VPS original.
- [ ] Bajo autorización expresa se ejecuta un restore de prueba de datos **sintéticos**, usando A+B, sin acceder al VPS original.
- [ ] Se registran duración de recuperación, fallos, concordancia de PostgreSQL/objetos/diarios, recuperación de clave antigua, y resultados negativos sin claves ni catálogo.
- [ ] Se documentan destrucción segura del entorno de ensayo, custodia, retención, rotación y plan ante pérdida de custodio; el secreto nunca se adjunta al informe.
- [ ] Un auditor distinto del operador aprueba el resultado. Hasta entonces, `MB1_OPERATIONAL_RELEASE=NO`.

## Requisito previo técnico todavía sin resolver

La prueba externa solo acredita **recuperabilidad**. Para declarar un backup coherente es además obligatorio demostrar corte temporal verdadero de todos los writers SQL y filesystem, no meramente inspección de sesiones, flock cooperativo o comparación de hashes antes/después. MB1 se mantiene bloqueado hasta cerrar **ambas** dimensiones.

## No hacer

No instalar claves nuevas en DEV, no exportar claves de producción a un chat, no activar MFA, no alterar la BD persistente, no conectar restic/O5 a experimentos MB1 y no definir una fecha de release basada solo en ensayos sintéticos.

```text
MB1_E2E_SYNTHETIC_RESTORE=PASS
MB1_EXTERNAL_CUSTODY_REAL=PENDING
MB1_SECOND_HOST_RESTORE=PENDING
MB1_GLOBAL_FREEZE=PENDING
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## Implementación de ensayo con montajes separados — pendiente de validación

Se ha extendido el ejecutor E2E para conservar el paquete cifrado en el directorio temporal `RECOVERY` y las claves sintéticas en un directorio privado `KEYMEDIA` diferente. Durante restauración, Docker monta el paquete en `/capture` y el directorio de claves en `/keymedia` en modo **solo lectura**; el recuperador busca exclusivamente las claves en la ubicación designada mediante `MB1_SYNTHETIC_KEY_ROOT`. La comprobación negativa sin claves se ejecuta antes de aprovisionar `KEYMEDIA`. El trap elimina ambos directorios sintéticos al salir. Se añade `MB1_E2E_SEPARATE_READONLY_KEY_MOUNT=OK` como nuevo marcador de prueba.

**Esto no acredita custodia externa**, pues ambos directorios son locales al mismo VPS. No asegura tampoco que administradores privilegiados no puedan leer las claves. No confundir con los destinos A/B/C exigidos para la custodia real. `MB1_E2E_EXTERNAL_KEY_CUSTODY=NOT_VERIFIED` continúa vigente.

Ejecutar exclusivamente el gate integral ya conocido `bash scripts/rehearse_mb1_pg17_e2e_disposable.sh` tras `git pull --ff-only`, y comprobar además el marcador anterior y `MB1_E2E_RESULT=0`. No ejecutar ni migrar servicios persistentes.
