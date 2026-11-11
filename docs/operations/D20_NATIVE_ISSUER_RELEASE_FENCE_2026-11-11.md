# D20 — Política de habilitación del emisor nativo (fail-closed)

**Fecha:** 11/11/2026. **Rama:** main. **Estado:** código publicado, pendiente de resultado VPS.

## Cambio concreto

Después de D19 PASS (contrato JSON estricto y pruebas PG17), se ha extraído una política de preparación de emisor a `backend/native_mobile_service/native_operational_issuer_gate.py`, sin exponerla como vista web ni conectarla al emisor de laboratorio.

La política evalúa controles independientes:
- Entorno de producción y registro de app operacional.
- Política bearer habilitada en vistas nativas autorizadas.
- Autorización explícita del emisor y rutas móviles.
- Custodia de claves de producción revisada.
- Verificación MFA por emisor de confianza.
- Recuperación de cuenta y revocación verificadas.
- Presupuesto antiabuso y auditoría.
- HTTPS nativo comprobado en dispositivo físico.

**No existe una credencial de activación derivada de esta evaluación.** `operational_readiness_missing` solo devuelve nombres de controles ausentes. `assert_operational_issuer_unavailable` deniega incondicionalmente incluso si un test sobrescribe todos los flags como `True`. No registra URLs, no toca DB, no importa `candidate_two_step_issuer`, no emite tokens. Esto es una barrera de preparación, **NO la implementación del emisor real**.

El nuevo `test_native_operational_issuer_gate.py` verifica los casos de evidencia incompleta/malformada, condiciones del release y rechazo incluso con flags todos habilitados. Se incorpora al script aislado `native_i8k_recovery_http_pg17_isolated.sh`, que sigue probando recuperación/atomicidad/I8-K con PG17 efímero, y produce `NATIVE_I8K_D20_ISSUER_REVIEW_GATE=PASS` solo tras completar la suite. `main_d20_native_operational_issuer_fence_gate.sh` agrupa auditoría estática D18 + regresión I8-K una sola vez.

## Commits

- `3db0ad5b`: nuevo módulo `native_operational_issuer_gate.py`.
- `a529b10d`: tests de preparación, cierre y no bypass.
- `882362dc`: incorpora tests D20 a I8-K PG17.
- `21107c42`: gate D20 agrupado.

## Termius — único gate D20

```bash
cd ~/vencira-main-check-20261108
git fetch origin refs/heads/main:refs/remotes/origin/main
git merge --ff-only origin/main

bash -n scripts/main_d20_native_operational_issuer_fence_gate.sh
echo "D20_SYNTAX=$?"
sudo -v
bash scripts/main_d20_native_operational_issuer_fence_gate.sh
echo "D20_SHELL_RESULT=$?"
git status --short
```

Marcadores:
```text
D20_MAIN_SYNC=PASS
D18_STATIC_FENCE_GATE=PASS
D20_OPERATIONAL_ROUTING_FENCE=PASS
NATIVE_I8K_D20_ISSUER_REVIEW_GATE=PASS
NATIVE_I8K_PG17_HTTP_RECOVERY_GATE=PASS
NATIVE_I8K_DEV_CONTAINERS_UNCHANGED=OK
NATIVE_I8K_LOCAL_RESULT=0
D20_PG17_ISSUER_POLICY=PASS
D20_CREDENTIAL_ISSUER_ENABLED=NO
D20_OPERATIONAL_ROUTES_ENABLED=NO
D20_RESULT=0
D20_SHELL_RESULT=0
```

El gate NO activa servicios ni requiere repetir D12-D19. Las pruebas backend I8-K construyen su imagen efímera y restauran la red y contenedores de laboratorio. La base DEV operativa permanece intacta.

## Trabajo sustantivo pendiente

**D20 no completa el emisor operacional.** Aún hay que construir la separación verificable entre el issuer candidato con claves y TOTP de test y el nuevo issuer operativo: la obtención de claves desde custodia externa autorizada; verificación server-side de password/MFA, generación y recuperación bajo locks PG17; políticas de rotación y auditoría, permisos por workspace y bearer estricto; integración Android bajo salida controlada; pruebas de errores, revocación y rollback. Evitar reutilizar endpoints `test_*` o flags de candidato fuera del laboratorio. No activar ni desplegar sin nueva autorización.

`MFA_RELEASE_AUTHORIZED=NO`
`NO_DEPLOY_NO_LIVE_MIGRATION=1`
