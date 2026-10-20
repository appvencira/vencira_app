# Primera prueba de VENCIRA en servidor Linux — entorno aislado

## Alcance y límites

Esta guía prepara el proyecto para ejecutar una **preview técnica en un servidor del usuario** que ya tenga Docker y Docker Compose. No se ha desplegado remotamente a través de GitHub: las herramientas conectadas a este proyecto no disponen de sesión SSH al servidor.

**No apta para producción.** Únicamente datos sintéticos, sin usuarios reales ni avisos externos.

El despliegue:
- Usa exclusivamente el repositorio privado `appvencira/vencira_app`, rama `chore/bootstrap-vencira`.
- Docker Compose con nombre **`vencira_preview`**, red y volumen propios. No toca MASBITCOIN ni contenedores ajenos.
- Puertos **127.0.0.1:18731** (Django) y **127.0.0.1:18732** (Flutter+proxy). No escuchar en 0.0.0.0 ni abrir puertos del router.
- PostgreSQL 17 sin puertos públicos.
- Build Flutter Web en una imagen multi-stage usando SDK 3.44.0; el host **no necesita Flutter instalado**.
- Acceso solo mediante **túnel SSH** de tu equipo al host de pruebas.

## Requisitos del servidor

Docker Engine y Docker Compose 2.x, Git, Python 3, acceso Git autorizado al **nuevo** repositorio privado de VENCIRA, espacio suficiente para la imagen de Flutter, y puertos 18731/18732 sin usar. El SDK de build Docker puede requerir varios GB de espacio temporal; comprobar espacio libre antes de iniciarlo. No abrir cortafuegos.

Si Git no autentica el nuevo repositorio, **no copiar credenciales ni claves de otra cuenta**: configurar una clave de despliegue de solo lectura dedicada a `appvencira/vencira_app` o iniciar sesión con la cuenta appvencira.

## Primer arranque (servidor)

En una cuenta Unix propia, sin usar `sudo` globalmente sobre servicios ajenos:

```bash
mkdir -p "$HOME/vencira-preview"
cd "$HOME/vencira-preview"
git clone --branch chore/bootstrap-vencira --single-branch git@github.com:appvencira/vencira_app.git .
df -h .
docker compose version
ss -ltn | grep -E ':(18731|18732)[[:space:]]' || true
bash scripts/preview-up.sh
bash scripts/preview-seed.sh
```

La última orden imprime **usuario y contraseña temporal de demostración**. Copiarla solo a tu gestor de contraseñas; al volver a ejecutar `preview-seed.sh` se cambia la contraseña. No copiarla a tickets ni al repositorio.

Para comprobar:
```bash
curl -fsS http://127.0.0.1:18732/api/health/
curl -fsS http://127.0.0.1:18732/api/ready/
curl -I http://127.0.0.1:18732/
docker compose -p vencira_preview -f compose.yaml -f compose.preview.yaml ps
```

## Abrir desde tu ordenador mediante túnel SSH

En una consola **del ordenador desde el que navegarás** (no la del servidor):

```bash
ssh -N -L 18732:127.0.0.1:18732 USUARIO@HOST_SERVIDOR
```

Sustituye USUARIO y HOST_SERVIDOR por tu acceso SSH habitual al servidor elegido, no por credenciales GitHub. Mientras ese comando esté conectado, abre:

```text
http://127.0.0.1:18732
```

Inicia sesión como `vencira_demo` usando la contraseña impresa en el servidor. Comprueba que aparecen los seis contratos **ficticios**, sus vencimientos y plazos de preaviso. Prueba **Añadir vencimiento** y **Editar vencimiento** con referencias sintéticas.

**Importante:** el proxy en loopback y el túnel SSH no equivalen a seguridad de producción; no poner datos reales ni cambiar DNS de `vencira.es`.

## Actualizaciones, rollback y parada

Para actualizar la preview conservando la base de pruebas:

```bash
cd "$HOME/vencira-preview"
git fetch origin chore/bootstrap-vencira
git status --short
git pull --ff-only
bash scripts/preview-up.sh
```

Para parar sin borrar la base de datos: `bash scripts/preview-down.sh`.

Para volver a un commit anterior de la **rama de pruebas**: conservar el hash bueno, hacer `git switch --detach HASH_VALIDADO` y ejecutar `bash scripts/preview-up.sh`. Verificar compatibilidad de migraciones antes de cualquier rollback real; un rollback de código NO revierte la base de datos. Evitar `docker compose down -v` (borra el volumen).

## Checklist de primera aceptación

- [ ] La preview arranca y ambos healthcheck responden.
- [ ] El formulario de login funciona y no hay acceso anónimo a datos privados.
- [ ] Se muestran únicamente los vencimientos sintéticos de la organización de pruebas.
- [ ] Altas y ediciones desde Flutter funcionan (POST/PATCH con CSRF).
- [ ] No se infiere el plazo contractual de preaviso y se rechazan fechas incoherentes.
- [ ] Cambiar de organización no mezcla los resultados.
- [ ] No se producen envíos ni notificaciones.
- [ ] Los servicios existentes del host siguen activos sin alteraciones.

## Para pasar de preview a producción

Por separado: VPS/entorno propio si procede, TLS, protección de acceso, MFA, gestión real de usuarios, supresión/retención RGPD, motor de entregas, copias externas y recuperación probada. No reutilizar credenciales, claves ni base de datos de esta preview.
