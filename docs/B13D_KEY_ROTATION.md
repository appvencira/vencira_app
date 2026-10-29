# VENCIRA B13D — Rotación y revocación Ed25519

Contrato experimental, sin despliegue.

- Registro explícito de claves públicas identificadas.
- Vigencia temporal y revocación fail-closed.
- Una clave desconocida o incorrecta impide aceptar
  una evidencia nueva.
- La firma continúa verificándose en B13B/B13C.
- No se almacenan ni se cargan claves privadas
  en el registro de confianza.
- La revocación no borra evidencias históricas.
- La recepción HMAC existente permanece intacta.
- No se habilitan descargas ni transiciones CLEAN.

Limitaciones pendientes:
- Registro todavía facilitado por el llamador de ensayo.
- Identificador de clave no incluido en el payload
  firmado ni persistido como campo de auditoría.
- No hay aprovisionamiento operacional ni aislamiento
  verificado de procesos.
- No se ha definido política de revalidación
  retrospectiva ante compromiso de una clave.

B13D_OPERATIONAL_RELEASE=NO
C_FICHA_RELEASE_AUTHORIZED=NO
MFA_RELEASE_AUTHORIZED=NO
NO_DEPLOY_NO_LIVE_MIGRATION=1
