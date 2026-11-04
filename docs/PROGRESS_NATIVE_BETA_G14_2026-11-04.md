# VENCIRA — Progreso verificado y próximo bloque (04/11/2026)

> Corte basado en salida física aportada por operador el 04/11 y revisión del código de la rama `feature/m3-android-local-notifications`. No es autorización de despliegue.

## Indicadores que no deben confundirse

| Indicador | Valor | Base y límite |
| --- | --- | --- |
| G13 Android físico | **100 % (18/18 marcadores)** | Fase 1 (9/9) + fase 2 (9/9) sobre Django temporal, CA efímera y Android físico; confirma solo laboratorio |
| Cierre de gates G0–G9 para beta nativa | **1/10 = 10 % de gates plenamente cerrados** | G0 cerrado, G1–G9 NO-GO operativos; no es porcentaje de código ni tiempo restante |
| Autorización de despliegue nativo | **NO** | G1/G2/G3 externos sin resolver, G4/G5 no integrados con issuer, G9 pendiente |
| % global del producto VENCIRA | **No calculable con evidencia actual** | Heterogeneidad de tareas, no existe inventario ponderado de requisitos con aceptación y release |

## Matriz de aceptación de beta nativa (no confundir candidato con cierre)

| Gate | Comprobación disponible | Bloqueante que impide marcar PASS operativo |
| --- | --- | --- |
| G0 Aislamiento | PASS de laboratorio | Conservar segregación de rutas y claves |
| G1 MFA | Prototipos y ensayos MFA test-only | Custodia externa y recuperación administrativa real y autorizada |
| G2 MB1 | Ensayos de captura, restauración y fence parcial | GLOBAL_FREEZE=NOT_VERIFIED y writer coverage completo |
| G3 C-FICHA | Ensayos aislados ClamAV y migraciones | Autorización de adjuntos, custodia, gates reales |
| G4 Sesiones/recursos | Candidato PG17, Bearer aislado y tests de permisos | Emisor autenticado y acoplado a permisos operativos, sin rutas reales |
| G5 Antifraude | Throttle, IP confiable, auditoría y keyring candidatos | Integración transaccional, clave externa, proxy real, rotación, pruebas |
| G6 Incertidumbre | Política fail-closed y laboratorio físico G13 | Integración contra sesión operativa bajo issuer autorizado |
| G7 Cliente nativo | UI test-only y APK Android G13 completada | Integración de app real, iOS, aceptación y UX de recuperación |
| G8 Aislamiento | Tests de usuario/workspace y DRF candidato | Auditoría completa de endpoints de lectura/escritura, adjuntos |
| G9 Release | Runbooks, preflights y ensayos parciales | Rollback/DR, observabilidad, autorizaciones expresas y corte |

### Evidencia G13 cerrada

Fase 1: `G13_ANDROID_TLS_CERT_VERIFIED=OK`, `G13_ANDROID_UNTRUSTED_CA_DENIED=OK`, `G13_ANDROID_REAL_FIRST_ISSUE=OK`, `G13_ANDROID_DJANGO_LOGOUT_REVOKED=OK`, `G13_ANDROID_REVOKE_FAULT_FENCED=OK`, `G13_ANDROID_REVOKE_RETRY_CONFIRMED=OK`, `G13_ANDROID_MFA_TLS_COMMITTED=OK`, `G13_ANDROID_UNKNOWN_ISSUANCE_FENCED=OK`, `G13_ANDROID_FORCE_STOP_REQUIRED=1`.

Fase 2: `G13_ANDROID_NEW_PROCESS=OK`, `G13_ANDROID_TLS_CONNECTION_AFTER_RESTART=OK`, `G13_ANDROID_DURABLE_MARKER_SURVIVED=OK`, `G13_ANDROID_G9_RECOVERY_REQUIRED=OK`, `G13_ANDROID_SERVER_RECOVERY_COMMITTED=OK`, `G13_ANDROID_RECOVERED_SESSION_REVOKED=OK`, `G13_ANDROID_CORRUPT_MARKER_BLOCKED=OK`, `G13_ANDROID_STORAGE_CLEANED=OK`, `G13_ANDROID_REAL_HTTPS_RESULT=0`.

Hubo desconexión local de Termius tras cierre forzado; se recuperó el túnel y la fase 2 completó sin repetir fase 1. **No se ha probado persistencia del túnel en segundo plano**. La evidencia de G13 figura detallada en `G13_ANDROID_USB_REAL_TLS_2026-11-04.md`.

## Próximo bloque: G14 — contrato de integración del emisor, aún sin activación

1. **Mapa de límites:** distinguir `native_sessions_lab` (solo test), `native_mobile_service` (test-only candidate), autenticación web SessionAuthentication y rutas operativas. No introducir vistas públicas en `config.urls`.
2. **Un único origen de autorización de emisión:** antes de llamar a `issue_verified_candidate_session` comprobar en misma operación lógica contraseña/MFA fiable, `auth_generation`, estado de usuario, memberships y versión de credencial. El método actual recibe `verified_mfa` como parámetro y no es un emisor confiable.
3. **Admisión de intentos:** aplicar `consume_candidate_auth_attempt` con identidad de cuenta normalizada y política de IP verificada por proxy de un salto, antes de verificar secretos. Probar fallo de clave, ausencia de IP confiable, cuota por cuenta/IP, concurrencia, usuario inexistente y bloqueo malicioso.
4. **Auditoría:** emitir eventos mínimos e idempotentes sin tokens ni PII; retención y purga test-only; demostrar que fallos de transacción no dejan emisión sin auditoría exigible.
5. **Recuperación G6:** incertidumbre obliga a marcador duradero, recuperación completa y revocación atómica; no reintento automático del refresh gastado.
6. **Pruebas:** SQLite y PG17 desechable, carreras, origen no autorizado, MFA no completado, fallos durante emisión/rollback, roles cruzados, entorno fuera de test, URLConf operativo sin rutas nativas y JWT/Bearer ilegítimo denegados.
7. **Límites:** ninguna migración en base persistente, secrets sintéticos, ninguna conexión real de credenciales ni Caddy, no merge del PR. Habilitación productiva exige primero G1/G2/G3, custodia real, seguridad de recursos G8 y gate G9.

### Resultado de esta revisión

**G14_SPEC_READY=YES; G14_ADMISSION_CANDIDATE=CODE_PUBLISHED; G14_ISSUER=NOT_IMPLEMENTED; G14_TESTS=NOT_RUN.** El plan no incrementa por sí solo el contador de gates operativos.

## Próxima aceptación necesaria

Desarrollar el contrato G14 en una rama test-only, publicar código y pruebas en GitHub y pedir una **única ejecución de gate en PG17 efímero** solo cuando el código esté completo. No repetir Android G13 por cambios exclusivos de backend sin relación con el protocolo del teléfono.

```
NO_DEPLOY_NO_LIVE_MIGRATION=1
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
GLOBAL_FREEZE=NOT_VERIFIED
```


## G14 — Subbloque A publicado (candidato de preadmisión, NO emisor)

Archivos nuevos:
- `backend/native_mobile_service/g14_admission.py`: **solo test-only**; exige claves de auditoría y cuota, consume límites por cuenta/IP y registra la denegación mínima dentro de una única transacción. La admisión permite únicamente proseguir a una verificación FUTURA, nunca emite token ni demuestra MFA.
- `backend/native_mobile_service/test_g14_admission.py`: ocho pruebas sintéticas de cuota, auditoría saneada, claves ausentes, UUID contradictorio/rollback, proxy multihop rechazado, aislamiento de entorno.
- `scripts/n1_identity_pg17_ephemeral.sh --candidate` y `.github/workflows/m3-product-contracts.yml`: incluyen las nuevas pruebas en PG17/SQLite desechables.
- `scripts/n1_static_security_gate.py`: exige que G14 no importe el emisor ni esté expuesto desde URLs operativas.

**Código publicado, pero el gate integral G14 todavía NO se ha ejecutado.** El cierre de gates G0–G9 permanece 1/10. Próximo paso: N1 estático y lote PG17 efímero antes de cualquier trabajo de emisor confiable. No reutilizar estas pruebas como autorización de autenticación operativa.

### Lote local único requerido para validar el subbloque

Desde `~/vencira-m3-localcheck`, tras `git fetch` y `git merge --ff-only FETCH_HEAD`, ejecutar `python3 scripts/n1_static_security_gate.py` y `bash scripts/m3_native_http_contract_batch.sh` bajo un subshell, sin `exit` que cierre la consola de Termius. Anotar HEAD preciso, `N1_STATIC_GATE_RESULT`, `M3_HTTP_RESULT`, resultados PG17 y Flutter; no imprimir logs con material secreto.


## 04/11/2026 — G14-A local integral PASS

Recibo aportado por el operador:
```
G14_N1_RESULT=0
G14_BATCH_RESULT=0
N1_STATIC_g14_admission_test_only=OK
N1_STATIC_GATE_RESULT=OK
M3_HTTP_STATIC=0
M3_HTTP_BUILD=0
M3_HTTP_PG17_LAB=0
G5_CANDIDATE_PG17_RESULT=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
```
Ruta local: `/home/vencira/vencira-m3-results/m3-http-contract-20261104T211959Z`. No se facilitó el SHA del checkout exacto; el recibo acredita el código ejecutado y que G14-A estaba incluido según N1. No asumir CI PASS ni atribuir nuevos commits a este lote.

**G14_A_VALIDATION=PASS (local integrado); G14_B_ISSUER=NOT_VALIDATED; G14_OPERATIONAL=NO.** G13 físico 100% (18/18); gates de liberación operativos cerrados 1/10, sin variación. No se ha modificado la DB operativa.

### Continuidad inmediata

Verificar diseño de emisor G14-B antes de permitir emisión: MFA real y custodia siguen bloqueados; no integrar vistas HTTP ni reutilizar una aserción booleana de MFA como prueba confiable. Completar revisión de desafíos MFA, carrera contra cambio de contraseña y rollback auditable con PostgreSQL17 desechable, y pruebas de denegación. No liberar hasta cumplir G1/G2/G3/G9. G14-B no cuenta como aprobado por el lote de G14-A.


## G14-B — Contrato de requisitos del emisor publicado (04/11/2026)

**Código disponible en PR #17, sin tests ejecutados todavía:**

- `backend/native_mobile_service/g14_issuance_contract.py`: objeto inmutable `IssuanceSecurityEvidence` y `missing_issuance_requirements()`, que marca como requisitos pendientes usuario activo, versión de credenciales, generación de revocación, cuarentena, presupuesto G5, auditoría, y MFA/época cuando corresponda. Es **solo un evaluador de requisitos**. Un caller podría falsificar sus booleanos: NO supone evidencia criptográfica, ni autorización de emisión, ni autenticación.
- `backend/native_mobile_service/test_g14_issuance_contract.py`: diez casos de evaluación y fallo cerrado de requisitos.
- `scripts/n1_identity_pg17_ephemeral.sh --candidate` y `.github/workflows/m3-product-contracts.yml`: incluyen las pruebas G14-B, manteniendo PG17 y SQLite desechables.
- `scripts/n1_static_security_gate.py`: prohíbe que el evaluador invoque al emisor o al verificador de contraseñas, y que se importe desde URLConfs operativos.

**Bloqueo material a resolver en G14-C:** construir y probar un verificador real y confiable del lado servidor (contraseña y segundo factor, con custodia MFA autorizada), convertir sus resultados en una transición atómica bajo lock de cuenta y no confiar jamás en booleanos recibidos de un caller no autorizado. Demostrar concurrencia, revocación, rollback y auditoría. El objeto G14-B jamás deberá usarse por sí solo para invocar `issue_verified_candidate_session`.

**Estado:** `G14_A_VALIDATION=PASS`, `G14_B_POLICY_CODE=PUBLISHED`, `G14_B_TESTS=PENDING`, `G14_C_TRUSTED_ISSUER=NOT_IMPLEMENTED`, `NATIVE_RELEASE=NO`. Las 10 pruebas son nuevas desde el último lote del operador; el PASS de G14-A no las cubre.


## 04/11/2026 — G14-B PASS y G14-C subbloque transaccional publicado

**Validación local comunicada sobre HEAD exacto `473b4259e`:**
```
G14_B_N1=0
G14_B_BATCH=0
N1_STATIC_g14_admission_test_only=OK
N1_STATIC_g14_issuer_policy_untrusted_evidence_only=OK
N1_STATIC_GATE_RESULT=OK
G5_CANDIDATE_PG17_RESULT=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
```
G14-A y G14-B **PASS de laboratorio**, no emisores operativos ni pruebas de custodia MFA.

**Nuevo G14-C subbloque: pruebas de atomicidad**, añadidas después de ese PASS:
- `backend/native_mobile_service/test_g14_issuance_atomicity.py`: cinco casos para comprobar que la emisión candidata y `auth_verified` pueden agruparse en una misma transacción: caso feliz, ausencia de clave de auditoría, UUID reutilizado con contenido incompatible, excepción antes de commit y protección de generación frente a revocación global.
- Integración en `n1_identity_pg17_ephemeral.sh --candidate`, SQLite/PG17 GitHub Actions y N1 estático.
- **No se ha creado un emisor nuevo ni se ha expuesto HTTP**. Estas pruebas usan el emisor de laboratorio existente desde un `TestCase`; el hecho de pasar no demuestra que una futura vista HTTP haya verificado contraseñas o TOTP de forma fiable.
- `G14_C_ATOMICITY_TESTS=PENDING`: código publicado, pendiente lote local posterior al HEAD `473b4259e`.

**Condición crítica antes de otro avance:** no aceptar argumentos `verified_mfa` de fuentes no confiables ni booleanos del evaluador G14-B como prueba criptográfica. El verificador confiable, la custodia autorizada de MFA, carreras reales y revisión de permisos seguirán pendientes incluso si estas cinco pruebas pasan. No liberar, migrar ni habilitar rutas reales.


## 04/11/2026 — G14-C PASS local y siguiente frontera G14-D

Resultado comunicado por operador al ejecutar lote integral tras la incorporación de los cinco tests de atomicidad:
```
G14_C_N1=0
G14_C_BATCH=0
N1_STATIC_g14_admission_test_only=OK
N1_STATIC_g14_issuer_policy_untrusted_evidence_only=OK
N1_STATIC_g14_atomicity_only_in_disposable_tests=OK
N1_STATIC_GATE_RESULT=OK
G5_CANDIDATE_PG17_RESULT=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
```
El último renglón suministrado fue `M3_HT,TP_RESULT=0`, que **no es una etiqueta válida**; no atribuir `M3_HTTP_RESULT=0` textual a esta salida. El código de salida del batch `G14_C_BATCH=0` confirma finalización correcta. SHA exacto de este checkout no incluido.

**G14_A_VALIDATION=PASS; G14_B_POLICY=PASS; G14_C_ATOMICITY=PASS (laboratorio); G14_D_TRUSTED_ISSUER=PENDING; PRODUCTION_RELEASE=NO.**

El siguiente trabajo debe distinguir *evidencia declarativa* de verificación autoritativa real: la estructura `IssuanceSecurityEvidence` de G14-B no acredita contraseña/MFA. Para G14-D preparar un verificador aislado del lado servidor, con revalidación bajo lock y ensayos negativos (contraseña inválida, MFA habilitado no completado, generación obsoleta, carrera con cambio de contraseña/revocación, auditoría rollback, aislamiento en `VENCIRA_ENV=test`). No exponer vistas, no modificar `config.urls` o autenticación DRF operativa, no migrar la DB persistente. MFA con custodia real sigue bloqueado hasta autorización.


## 04/11/2026 — G14-D1 verificador candidato con lock (PUBLICADO, PENDING TEST)

Nuevo `backend/native_mobile_service/g14_locked_verifier.py`:
- `verify_candidate_password_only` opera solo si el gate del servicio candidato `VENCIRA_ENV=test` está abierto.
- Usa `select_for_update` sobre el usuario activo, `check_password` en servidor, lectura de `UserMfaState` y `require_mobile_identity_gate` para cuarentena y credencial actual.
- **Rechaza siempre** cuentas con MFA activo. No comprueba TOTP, no invoca `issue_verified_candidate_session`, no emite bearer/refresh ni añade rutas.
- Devuelve identificador de usuario y generación de revocación solo como **metadatos no transferibles** para el laboratorio; no son un comprobante firmado ni autorizan la emisión posterior, especialmente tras soltar el lock.
- Pruebas: `test_g14_locked_verifier.py` con ocho casos positivos/negativos para contraseña errónea, cuenta inexistente, cambio de contraseña, MFA activado, revocación, cuenta inactiva, gate cerrado y entradas inválidas. Integradas en el runner PG17 efímero, CI SQLite/PG17 y N1.

**No confundir con G14-D completo**: sigue faltando emparejar admisión G14-A, autenticación+MFA autoritativa y emisor en una única transición revisada, con lock hasta commit y custodia MFA real. Ninguna vista operativa ni endpoint ha sido habilitado, ni hay mutaciones en BD persistente.

```
G14_A_VALIDATION=PASS
G14_B_POLICY=PASS
G14_C_ATOMICITY=PASS
G14_D1_LOCKED_VERIFIER=CODE_PUBLISHED_TEST_PENDING
G14_D_TRUSTED_ISSUER=NOT_IMPLEMENTED
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## G14-D1 — Validación local integral PASS (04/11/2026)

El operador ha comunicado:
```
G14_D1_N1=0
G14_D1_BATCH=0
N1_STATIC_g14_admission_test_only=OK
N1_STATIC_g14_issuer_policy_untrusted_evidence_only=OK
N1_STATIC_g14_atomicity_only_in_disposable_tests=OK
N1_STATIC_g14_locked_verifier_test_only_no_issuer=OK
N1_STATIC_GATE_RESULT=OK
G5_CANDIDATE_PG17_RESULT=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
```

**G14_D1_VALIDATION=PASS**, sobre checkout local del operador (SHA exacto no proporcionado en esta salida); pruebas SQLite/PG17/Flutter integradas, según runner. No atribuir CI verde sin recibo. El verificador G14-D1 no crea sesiones y su metadata de salida no puede considerarse evidencia transferible de credenciales verificadas.

**G14-D2 permanece NO IMPLEMENTADO:** verificador MFA autoritativo, custodia autorizada y consumo transaccional de segundo factor, vínculo de emisión y auditoría sin aceptar `verified_mfa` externo, control de carreras/revocación y contrato de recuperación G6. No activar rutas ni migrar producción.

```
G14_A=PASS
G14_B=PASS
G14_C=PASS
G14_D1=PASS
G14_D2=NOT_IMPLEMENTED
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```


## G14-D2 — Riesgo TOCTOU acreditado en código y pruebas negativas publicadas (04/11/2026)

Se ha identificado **un bloqueo de diseño material**: `g14_locked_verifier.verify_candidate_password_only` devuelve usuario/generación tras liberar la transacción. `issue_verified_candidate_session` revalida generación, estado MFA, recuperación y versión de credencial en el momento de emisión, pero **no exige prueba de que el caller ha verificado la contraseña**. Por ello, una emisión posterior con argumentos fabricados es posible dentro del candidato test-only, aunque la contraseña haya cambiado tras la verificación D1. No es un bypass expuesto públicamente: la app candidata está restringida a `VENCIRA_ENV=test` y no hay rutas de autenticación operativas. Sin embargo, integrar este patrón en una vista real sería inseguro.

**Regresiones nuevas, publicadas y aún pendientes de ejecución:** `backend/native_mobile_service/test_g14_untrusted_evidence.py` (4 casos): denegación por generación de revocación antigua, demostración explícita del hueco entre comprobación de contraseña y emisor de bajo nivel, denegación de una emisión no-MFA tras activar MFA y ausencia de URLConf emisor en `config.urls`. Incorporadas al lote PG17 efímero, SQLite CI y N1 estático. La demostración de la emisión después de cambiar contraseña **no equivale a prueba de seguridad superada**: es precisamente la reproducción del riesgo que debe eliminar un futuro emisor confiable.

**Estado correcto:** `G14_D1_VALIDATION=PASS`, `G14_D2_RISK_REPRODUCER=CODE_PUBLISHED_TEST_PENDING`, `G14_D2_TRUSTED_ISSUER=BLOCKED`. Para cerrar D2, el único componente facultado para llamar a la emisión debe comprobar contraseña/TOTP de forma autoritativa bajo el bloqueo correspondiente y completar emisión+auditoría en la misma transacción, con revocación y MFA; no aceptar metadatos, booleanos G14-B ni `verified_mfa` del caller como credencial. No abrir endpoints ni usar la BD persistente. La custodia externa MFA continúa pendiente.


## 04/11/2026 — G14-D2 regresión negativa PASS (HEAD confirmado)

Operador informa HEAD `6f1117ee` y:

```
G14_D2_N1=0
G14_D2_BATCH=0
N1_STATIC_g14_admission_test_only=OK
N1_STATIC_g14_issuer_policy_untrusted_evidence_only=OK
N1_STATIC_g14_atomicity_only_in_disposable_tests=OK
N1_STATIC_g14_locked_verifier_test_only_no_issuer=OK
N1_STATIC_g14_d2_untrusted_evidence_negative_contract=OK
N1_STATIC_GATE_RESULT=OK
G5_CANDIDATE_PG17_RESULT=0
M3_HTTP_G4_PG17=0
M3_HTTP_FLUTTER=0
M3_HTTP_RESULT=0
```

**Resultado: G14_D2_NEGATIVE_REGRESSION=PASS.** La prueba deliberadamente evidencia una emisión candidata posible después del cambio de contraseña si se invoca el emisor de bajo nivel sin acreditar posesión reciente: pasar el test **no corrige el defecto TOCTOU** ni concede autorización de emisor operativo. `G14_D2_TRUSTED_ISSUER=NOT_IMPLEMENTED`.

**Siguiente cierre técnico exigible:** diseñar un único boundary transaccional que haga las verificaciones autoritativas dentro del mismo bloqueo que la emisión, con registro de auditoría y consumo TOTP, sin aceptar evidencia booleana ni identidad aportada como prueba. Necesita pruebas de carrera real PG17, acceso por defecto denegado, MFA real en laboratorio, bloqueo por cuarentena y revisión externa de custodia. No integrar HTTP, no desplegar ni migrar producción.
