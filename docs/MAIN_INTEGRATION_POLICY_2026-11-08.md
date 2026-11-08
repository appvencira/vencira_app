# Integración directa en `main` — VENCIRA

Fecha: 2026-11-08.

## Decisión de trabajo

La rama principal `main` es el destino del código de VENCIRA. No crear más
ramas de desarrollo para continuar las macrofases. Los cambios futuros se
integrarán en `main` cuando estén verificados contra esa misma rama, con
commits pequeños, verificables y reversibles. **Integrar código en GitHub no
es desplegar a DEV/producción**.

## Estado auditado del historial

- `main` y `feature/m3-android-local-notifications` han divergido.
  Comparación al revisar: **3945+ commits** en el historial candidato
  no incorporados a `main`, **19 commits** exclusivos en `main`.
  El recuento podrá evolucionar con nuevos commits.
- La PR #17 es draft, base
  `feature/mb1-m104-transition-contract-batch`, head
  `feature/m3-android-local-notifications`: **no mergeable** en la
  revisión. La PR #18 (hacia `main`) tampoco es mergeable.
- No hacer un merge ciego, `force push`, ni crear un commit de merge
  utilizando el árbol de una sola rama: podría borrar cambios de la
  otra rama aun conservando nominalmente sus padres.
- La primera integración directa debe comparar contenido/dependencias
  real de `main` antes de mover código. Los tests ejecutados en
  una rama antigua **no garantizan** que pasen en `main`.

## Puertas de seguridad

- `MFA_RELEASE_AUTHORIZED=NO`
- `NO_DEPLOY_NO_LIVE_MIGRATION=1`
- Nada de cambios a `config.urls` o `main.dart` que abran emisión
  nativa o recuperación real sin los gates apropiados.
- Ningún `docker compose up`, `migrate` sobre bases persistentes,
  publicación de APK ni activación de MFA como efecto lateral de
  actualizar GitHub.
- I8-H–I8-L tienen resultados de laboratorio reportados PASS en
  sus ámbitos; aún faltan Flutter HTTPS de recuperación hacia PG17
  aislado, Android físico para recovery y revisión de integración
  `main`.

## Regla para avanzar

En lugar de trasladar miles de commits de golpe, integrar **en la
propia `main`** cambios autocontenidos que no sobreescriban los 19
commits exclusivos. Antes de cada cambio, revisar la versión actual,
su dependencia y los tests necesarios. Si se detecta un conflicto,
dejarlo expresamente pendiente; no presentar una integración documental
como equivalente a código funcional integrado.

Este documento deja constancia de la nueva política y **no declara
resuelta la divergencia**.
