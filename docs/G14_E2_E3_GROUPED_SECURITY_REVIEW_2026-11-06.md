# G14-E2/E3 — Revisión de frontera transaccional y plan de aceptación agrupada

Fecha: 2026-11-06. Rama: `feature/m3-android-local-notifications`. PR #17 permanece DRAFT.

**Estado:** especificación y revisión de código, NO implementación de emisor. No acredita pruebas nuevas. G15 queda cerrado conforme a `HANDOFF_ANDROID_G15_CLOSED_2026-11-06.md`.

## 1. Hechos observados en fuentes

| Pieza | Hecho verificable | Consecuencia |
|---|---|---|
| `g14_e1_locked_mfa_verifier.verify_candidate_password_and_totp` | `transaction.atomic()` local, bloquea usuario y MFA, consume TOTP; devuelve `True/False`. | El resultado no puede emplearse como autorización transferible de emisión. La transacción puede haber terminado antes de crear sesión. |
| `session_store.issue_verified_candidate_session` | Recibe `user_id`, `verified_mfa`, `mfa_epoch`, `expected_generation` de su llamante, toma lock de usuario y persiste digests de sesión. | Su comprobación de identidad no verifica password/TOTP; sigue siendo emisor **test-only**. |
| `session_store.rotate_candidate_refresh` | Bloquea sesión, registra refresh gastado y rota digests; replay conocido revoca el dispositivo y la excepción se eleva tras terminar el bloque atómico. | Política de respuesta ambigua: no reintentar refresh incierto; validar carreras contra revocación. |
| `session_store.revoke_all_candidate_devices` | Bloquea usuario, incrementa generation y revoca sesiones. | Emisión/revocación debe serializar en una misma identidad y orden. |
| `scripts/g14_trusted_issuer_boundary.py` | Auditoría AST con un llamante interno permitido; detecta algunos usos directos, importados y `getattr` literales. | No es prueba de flujo de datos, bloqueo de dinámicos o autorización HTTP. |

## 2. Contrato obligatorio de E2 (sin excepciones por facilidad de test)

1. **Entrada:** identificador de login, contraseña, segundo factor y contexto de transporte saneado. Rechazar parámetros afirmativos como `user_id`, `verified_mfa`, epoch o generación aportados por el cliente.
2. **Preadmisión:** validaciones de formato, rate limit y registro de denegación HMAC de identidad pseudonimizada sin registrar credenciales, TOTP, refresh ni secretos. Precisar tratamiento de reintentos, concurrencia y errores de reloj; la denegación no puede convertirse en emisión.
3. **Transacción de aceptación:** adquirir `User.select_for_update` como primer lock de identidad; bajo ese lock comprobar cuenta activa y hash actual de contraseña; adquirir `UserMfaState.select_for_update`; confirmar estado MFA vigente, ausencia de recuperación pendiente, versión de credencial y generation coherentes; consumir factor de uso único; crear `MobileDeviceSession` y auditoría de éxito en **la misma transacción**. Conservar locks hasta commit. Todos los identificadores/epochs proceden de las filas bloqueadas. Los commits parciales de verificación y emisión son inadmisibles.
4. **Auditoría y rollback:** si falla persistir sesión o evento positivo, la operación entera revierte incluido el consumo MFA. Prohibido simular auditoría con un log no transaccional y considerarlo confirmación atómica. Las denegaciones necesitan política separada y persistencia de cuotas: no asumir que su escritura sobrevive a un rollback del mismo `atomic`.
5. **Prueba perdida tras commit:** no reusar factor ni regenerar otra sesión por retry ciego; definir respuesta segura sin prometer exactly-once al cliente. El receptor puede desconocer si hubo commit; la recuperación tiene que ser explícita y auditable.
6. **Respuesta:** igualar los errores de contraseña, factor, estado y ausencia de cuenta hacia el cliente; diferenciar internamente fallos criptográficos/de custodia sin exponerlos ni alterar la política fail-closed.
7. **Aislamiento:** `VENCIRA_ENV=test`, `VENCIRA_NATIVE_SERVICE_CANDIDATE` y denegación de rutas públicas siguen siendo condiciones necesarias, nunca suficientes. No activar `main.dart`/login nativo ni abrir endpoint.

**No reutilizar `verify_candidate_password_and_totp(...)=True` como credencial de emisión.** Un `atomic` externo alrededor de funciones antiguas no basta por sí solo: comprobar dependencias y efectos, semántica de las denegaciones y orden real de locks con pruebas PostgreSQL.

## 3. E3 — matriz de carreras y resultados aceptables

| Carrera/fallo | Aceptación exigida |
|---|---|
| Dos logins con mismo TOTP | Máximo uno consuma el paso; máximo una emisión positiva; sin doble auditoría. |
| Dos logins con mismo código de recuperación | A lo sumo un consumo y una emisión. |
| Emisión vs cambio de contraseña | El token anterior al cambio queda inválido por versión/fence; el posterior exige credencial actual. |
| Emisión vs cambio/desactivación de MFA | Epoch/fence coherente; ningún token con MFA obsoleto sigue válido. |
| Emisión vs apertura o finalización de recuperación | Serialización de locks y rechazo de emisión durante el estado de recuperación no permitido. |
| Emisión vs revocación global | Resultado linealizable con generación; ningún token anterior a la revocación sobrevive. |
| Rotación refresh vs rotación refresh del mismo token | Solo una rotación útil; el replay observado activa revocación persistente con orden correcto. |
| Rotación refresh vs revocación global | Ningún refresh devuelto permite usar sesión tras revocación; sin deadlock. |
| Fallo al crear sesión, guardar auditoría o consumir factor | Rollback completo del éxito y sin tokens válidos; error uniforme al cliente. |
| Timeout o respuesta perdida **después** de commit | No reusar TOTP, no reintentar refresh ambiguo; flujo de reautenticación definido sin doble emisión. |
| Denegaciones concurrentes y límite de abuso | Los contadores/ventana no se pierden por rollback del éxito; rechazo bajo contención. |
| Error de custodia/Fernet o HMAC | Fail-closed, sin publicación de causas, secretos ni datos reales. |

Para demostrar las carreras usar **dos conexiones PostgreSQL 17 efectivamente independientes**, barreras de sincronización y aserciones sobre filas finales, digests y eventos; no reemplazar el ensayo por mocks secuenciales. Un timeout artificial debe tener límites y capturar deadlocks sin bloquear CI indefinidamente.

## 4. Gate conjunto propuesto E2+E3 (solo cuando exista implementación revisable)

**Preflight:** inspección del diff, ausencia de endpoint público y de secretos/credenciales, commit/HEAD exactos, custodia de claves disponible solo en fixture efímera; revisión humana independiente de seguridad.

**Ejecución agrupada:** suites unitarias dirigidas nuevas E2/E3 + N1/AST + una pasada PostgreSQL 17 efímero (red interna, sin puertos publicados) + comprobación de CI asociada al SHA. No repetir G13/G15, ni las 139 regresiones E1D3 como campaña independiente: si el runner general las incluye, registrar esa cobertura una sola vez.

**Criterio de salida:** ninguna infracción de lock-order, replay, reversión de auditoría o emisión con evidencia afirmada; flujo de denegación probado; ausencia de rutas operativas; registro de riesgos residuales y aprobación humana explícita. Sin una sola de estas condiciones: `E2=NO_GO` y `E3=NO_GO`.

## 5. Secuencia de implementación y revisión (no ejecutada)

- **E2-A:** diseñar interfaz interna que nunca acepte afirmaciones de MFA y esquema transaccional del evento de éxito; aclarar mecanismo de auditoría y rate limiting antes de conectar tokens.
- **E2-B:** revisión de locks de escritores de MFA/recuperación y generación; formular invariantes que no dependen del orden de callbacks externos.
- **E2-C:** implementación del emisor y suite negativa en rama aislada, **solo si lo permiten expresamente los controles de seguridad del conector**; no crear vías alternativas para eludir bloqueos previos.
- **E3-A/B:** contención real de emisión/recovery y de refresh/revocación en PG17 temporal; ensayo de fallo inyectado y respuesta ambigua.
- **E3-C:** evaluación independiente, informe con SHA, evidencias y decisión NO_GO/GO **solo para laboratorio**. No inferir autorización de beta/release.

## 6. Bloqueos y límites vigentes

Los intentos de publicar la integración MFA E2 fueron bloqueados por el conector anteriormente. No hay publicación de emisor, ni pruebas E2/E3 nuevas, ni evidencia de CI en este lote. Las pruebas E1D3 (139 PG17 PASS local) y F0 (9 unit + N1 PASS local) son previas.

```
G15_LAB=COMPLETE_WITH_SCOPE_LIMITS
G14_E1D3=PASS_LOCAL_139_PG17
G14_F0=PASS_LOCAL_STATIC
G14_E2_ISSUER=NOT_IMPLEMENTED
G14_E3_RACES=NOT_EXECUTED
MFA_RELEASE_AUTHORIZED=NO
MB1_RELEASE_AUTHORIZED=NO
C_FICHA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
```

## 2026-11-06 — E3-R1/R2: nuevas carreras de refresh (pendientes de ejecutar)

Commit de código: `e269963d003b3c82ac5eb2a73c518d0a92320635`. Se añadieron **dos** `TransactionTestCase` a la suite **ya registrada** `native_mobile_service.test_pg17_races`:

- `test_refresh_racing_account_revocation_cannot_restore_session`: dos conexiones y barrera; refresh y revocación global compiten; la generación final es 1, no quedan sesiones no revocadas, y cualquier access/refresh devuelto termina denegado.
- `test_refresh_racing_password_change_cannot_keep_old_credential`: dos conexiones y barrera; refresh compite con cambio de contraseña bajo lock de usuario; ni access antiguo ni token devuelto deben seguir autenticando después del cambio.

No hay cambios en emisor, backend operativo, migrations, URL, secretos o CI: el runner `--candidate` y el workflow PG17 ya incluyen esta suite. **Estas son carreras del almacén de sesiones candidato SIN MFA**, y no prueban E2 ni las carreras de emisión con TOTP.

**Estado: `E3_REFRESH_CODE=PUBLISHED`, `E3_REFRESH_PG17=NOT_RUN`.** Una vez sincronizado el HEAD, ejecutar una validación agrupada PG17 efímera para ambos casos y, si procede, el runner general una sola vez; no repetir G13/G15. Un posible fallo de estas regresiones debe conservarse como evidencia y bloquear la aceptación: no debilitar aserciones para lograr verde.
