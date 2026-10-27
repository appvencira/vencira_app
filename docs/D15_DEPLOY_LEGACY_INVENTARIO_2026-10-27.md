# VENCIRA — Clasificación de 16 desplegadores históricos (27-10-2026)

Revisión textual en rama integration/local-e2e-prep. Los 16 scripts se inventariaron con `scripts/audit_mfa_legacy_deploy_readonly.py`: el 16/16 indica ausencia de invocación explícita de la puerta MFA, **no** vulnerabilidad explotable demostrada. Clasificación estática; no se ha ejecutado ningún despliegue.

## Categorías operativas

**Solo web_preview, sin recreación declarada de API ni migraciones: 4**
- deploy_macro_a_ui_web_guarded.sh
- deploy_macro_b_premium_ui_web_guarded.sh
- deploy_o8c_spacing_web_only.sh
- deploy_o9b3_web_guarded.sh

**API + web_preview, con comprobación de migraciones pero sin aplicación de esquema declarada: 7**
- deploy_c2_no_migrations.sh
- deploy_macro_b_api_web_guarded.sh
- deploy_macro_b_history_api_web_guarded.sh
- deploy_o7_o8_no_migrations.sh
- deploy_o8b_no_migrations.sh
- deploy_o9a_no_migrations.sh
- deploy_whitepaper_alignment_no_migrations.sh

**API + web_preview y migración explícita de etapa histórica: 5**
- deploy_macro_a_0018_guarded.sh (objetivo 0018)
- deploy_o8c_0015_guarded.sh (objetivo 0015)
- deploy_o9b_0016_guarded.sh (objetivo 0016)
- deploy_operativa_o2.sh (histórica 0013)
- deploy_operativa_o3.sh (histórica 0014)

Los scripts operativa_o2/o3 usan plan de migración y recrean API; nunca tratarlos como web-only.

## Interpretación para MFA

- Ninguno invoca obligatoriamente `mfa_deploy_entry_readonly.sh` ni `mfa_s1_release_readonly.sh`; estos gates protegen solamente su entrada concreta, no cualquier ruta de despliegue.
- Varios scripts comprueban que backend y compose no difieren de un commit antiguo. Eso puede bloquear candidatos nuevos, pero no constituye una política exhaustiva de publicación MFA.
- Un `migrate --check` protege contra desfase de esquema al arrancar el API, **no** prueba que un rollback de imagen aplique MFA a cuentas existentes.
- Hasta completar un **preflight común en todos los entrypoints relevantes** y ensayo de rollback en clon, no reutilizar scripts históricos para aplicar migraciones 0019–0026, publicar API con MFA ni efectuar rollback hacia versión sin enforcement.
- Recomendación: designar único entrypoint de despliegue futuro, capaz de distinguir web-only, API y esquema; incluir chequeos fail-closed de estado de cuentas MFA, rutas de sesión y compatibilidad de rollback. Deshabilitar administrativamente los scripts anteriores para MFA mediante procedimiento operativo, con inspección independiente de su integración antes de autorizar producción.

## Estado

AUDITORIA_ESTATICA_LEGACY=HECHA
PROTECCION_TRANSVERSAL_DE_16_SCRIPTS=PENDIENTE
ROLLOUT_MFA_AUTORIZADO=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
