# VENCIRA · VPS de desarrollo en IONOS

Estado: **Docker operativo y UFW activo (diagnóstico aportado por el usuario). Pendientes clave Deploy Key SSH GitHub, clonación, despliegue de preview y revisión final SSH/HTTPS**.
Fuente de inventario: información del panel IONOS proporcionada por el titular (21/10/2026).
Este documento describe el objetivo y los pasos previstos, no certifica su ejecución remota.

## Inventario confirmado

| Campo | Valor |
| --- | --- |
| Proveedor | IONOS |
| Nombre | Vencira VPS |
| Host/IP pública | `93.93.112.172` |
| DNS técnico IONOS | `1yq96gr.cserverhost.cloud` |
| Centro de datos | España (UE) |
| SO | Ubuntu 24.04 |
| CPU | 4 vCore |
| RAM | 8 GB |
| Disco | 240 GB NVMe SSD |
| Tipo | Máquina virtual; `VPS 4-8-240` |
| Usuario inicial | `root` |
| Firewall IONOS | Política asignada: "Firewall Policy for My VPS"; reglas efectivas pendientes de comprobar |
| Fecha de creación | 2026-10-21 19:56:49 |

**No guardar en este repositorio** contraseña inicial de root, claves privadas SSH, secretos .env, tokens, credenciales reales ni datos personales. La IP y el DNS técnico no equivalen a credenciales.

## Objetivo de esta etapa

- VPS independiente para desarrollo y pruebas de VENCIRA; NO producción ni datos reales.
- Repositorio exclusivo privado `appvencira/vencira_app`, rama `chore/bootstrap-vencira` (PR #1 borrador).
- Docker Compose aislado `vencira_preview` con Django, PostgreSQL y Flutter Web bajo Nginx.
- API `127.0.0.1:18731`, web `127.0.0.1:18732`; PostgreSQL sin puerto expuesto.
- Acceso remoto **primero por túnel SSH**, sin abrir 18731/18732 ni 5432 en el firewall.
- Objetivo posterior `dev.vencira.es` **con HTTPS y autenticación perimetral**, previa comprobación del dominio y DNS. No publicar preview de Django en HTTP público.


## Verificación real del VPS (21/10/2026, según salida proporcionada)

- Ubuntu **24.04.5 LTS** (`noble`), arquitectura `x86_64`.
- Servicio `ssh` **active**.
- Firewall local `ufw`: **inactive**.
- La salida no incluye todavía `whoami`, memoria/disco, versión de Docker ni reglas de firewall de IONOS; no asumir que están comprobados.
- Próximo paso acordado: crear cuenta administrativa `vencira`, introducir clave SSH generada localmente, validar un segundo acceso y `sudo` antes de modificar restricciones de SSH. No activar `ufw` ni deshabilitar `root` a ciegas.

## Etapa 1: verificación SSH y host limpio

Desde un ordenador de confianza con SSH:

```bash
ssh root@93.93.112.172
```

Consultar la contraseña inicial en IONOS **sin publicarla**. Verificar huella del host mediante la consola de IONOS antes de confiar en ella.
Si falla la conexión, revisar en IONOS > Servidores & Cloud > Red > Políticas de firewall que esté permitido TCP/22 desde IP de gestión; no abrir la red innecesariamente.

Dentro del VPS:

```bash
whoami
hostnamectl
nproc
free -h
df -h /
cat /etc/os-release
uname -m
systemctl is-active ssh
ufw status
```

Nunca deshabilitar SSH por contraseña o root antes de probar una cuenta alternativa con clave.

## Etapa 2: acceso administrativo con clave

En la **máquina cliente** (Linux/macOS; adaptar ruta a Windows si procede):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -C "vencira-vps-admin" -f ~/.ssh/id_ed25519_vencira_vps
```

Elegir una passphrase segura. Si el archivo existe, no sobrescribirlo. Solo se copia al VPS el archivo `.pub`.

Desde una sesión root **del VPS**:

```bash
adduser --gecos "" vencira
usermod -aG sudo vencira
```

Desde la **máquina cliente** con `ssh-copy-id` instalado:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_vencira_vps.pub vencira@93.93.112.172
ssh -i ~/.ssh/id_ed25519_vencira_vps vencira@93.93.112.172
sudo -v
```

El acceso nuevo y sudo deben funcionar desde **una sesión independiente** antes de restringir root/contraseñas. Después comprobar `sshd -T` y configurar endurecimiento mediante `/etc/ssh/sshd_config.d/` con copia de seguridad, validación `sshd -t` y `systemctl reload ssh`, sin cerrar la sesión de emergencia. Cambiar/retirar la contraseña inicial conforme al procedimiento de IONOS.

## Etapa 3: Docker, repositorio y primer despliegue

Después de asegurar SSH y confirmar espacio/libre:
1. Actualizar Ubuntu y reiniciar si hay actualización de kernel, con reconexión verificada.
2. Instalar Docker Engine, Buildx y Compose **desde repositorio oficial de Docker para Ubuntu 24.04**; verificar `docker compose version`. Guía oficial: https://docs.docker.com/engine/install/ubuntu/
3. Evaluar permisos Docker: pertenecer al grupo `docker` equivale prácticamente a permisos root; solo para usuario administrador de confianza.
4. Crear clave **Deploy Key de solo lectura** distinta de la clave SSH administrativa, exclusivamente para `appvencira/vencira_app`.
5. Clonar rama de prueba en `/home/vencira/vencira-preview`; ejecutar `bash scripts/preview-up.sh`, luego `bash scripts/preview-seed.sh`. Nunca compartir la contraseña de prueba.
6. Validar health/ready, login y flujo crear/editar/buscar vencimiento ficticio, cambio de estado y cierre de sesión.
7. No usar `docker compose down -v`: destruye el volumen de BD. Mantener copia externa probada antes de utilizar el VPS para algo importante.

Con la preview solo en loopback, desde un equipo cliente:
```bash
ssh -i ~/.ssh/id_ed25519_vencira_vps -N \
  -L 18732:127.0.0.1:18732 vencira@93.93.112.172
```
Navegar localmente a `http://127.0.0.1:18732/`.
No publicar puertos Docker ni PostgreSQL; advertencia oficial sobre interacción Docker-UFW: https://docs.docker.com/engine/install/ubuntu/

## Firewall y DNS

IONOS permite modificar reglas en Servidores & Cloud > Red > Políticas de firewall. Mantener TCP 22 autorizado solo para IP de administración cuando sea posible. Revisar y cerrar los puertos de paneles 8443/8447 si están abiertos y no se utilizan. Reservar TCP 80/443 para un proxy HTTPS futuro, nunca exponer 18731/18732/5432. Revisar también firewall local una vez verificado el acceso SSH.

`dev.vencira.es` es **un objetivo**, no se afirma que su registro A, SSL ni DNS estén configurados. Asegurar la web y evitar datos reales antes de crear el registro A.

## Límites y pendientes

- VPS contratado ≠ configurado ni desplegado. No hay acceso remoto directo desde las herramientas conectadas a ChatGPT.
- GitHub Actions CI de una revisión no equivale a prueba del navegador real.
- No activar todavía avisos externos, correo transaccional ni datos personales de clientes.
- Antes de apertura pública: HTTPS, control de acceso adicional, MFA, límites por IP, backups externos, recuperación, revisión de RGPD, retención y seguridad.

## Diagnóstico confirmado por consola (21/10/2026)

Sesión real aportada por el usuario en la cuenta `vencira`:

- `whoami`: `vencira`.
- Docker Engine: **no instalado**; Docker Compose: **no instalado**.
- UFW: **inactive**; por tanto falta activar firewall local.
- Memoria: 7,7 GiB totales; 7,2 GiB disponibles; **sin swap**.
- Disco: 232 GiB partición raíz `/dev/vda1`, 230 GiB libres.
- Git: versión **2.43.0**.
- `sudo` solicita la contraseña de `vencira`: acceso con sudo aparentemente operativo, pendiente confirmar una operación concreta.

**Orden seguro:** revisar que funciona un nuevo acceso SSH desde Windows por clave; abrir primero TCP/22 en UFW, activarlo, comprobar un segundo SSH. Instalar luego Docker desde su repositorio apt oficial (Ubuntu noble) y verificar `sudo docker run --rm hello-world`. Aún no exponer servicios en Internet ni añadir el usuario al grupo Docker: ese grupo otorga privilegios equivalentes a root.

## Continuación de instalación (usuario confirma «done», 21/10/2026)

El usuario confirma que ha completado la creación del usuario `vencira` y el acceso con clave SSH y `sudo`, sin proporcionar logs de validación. La protección de `root`/contraseñas, firewall y Docker aún **no** se han confirmado como ejecutados.

1. **Antes de restringir SSH:** abrir acceso desde el ordenador mediante
   `ssh -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -i ~/.ssh/id_ed25519_vencira_vps vencira@93.93.112.172`.
2. Mantener abierta una sesión existente mientras se establece
   `/etc/ssh/sshd_config.d/01-vencira.conf` con:
   ```text
   PubkeyAuthentication yes
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   PermitRootLogin no
   PermitEmptyPasswords no
   ```
   Validar `sudo sshd -t`, aplicar `sudo systemctl reload ssh` y confirmar un segundo login independiente. `sshd -T` permite inspeccionar los valores efectivos. No dejar fuera al administrador.
3. UFW: `sudo ufw default deny incoming`, `sudo ufw default allow outgoing`, `sudo ufw allow 22/tcp`, `sudo ufw --force enable`. Verificar `ufw status verbose`. Revisar por separado firewall IONOS sin cerrar SSH.
4. Instalar Docker desde repositorio apt **oficial**, no script `get.docker.com`:
   https://docs.docker.com/engine/install/ubuntu/
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates curl git
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
   Types: deb
   URIs: https://download.docker.com/linux/ubuntu
   Suites: noble
   Components: stable
   Architectures: amd64
   Signed-By: /etc/apt/keyrings/docker.asc
   EOF
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   sudo systemctl enable --now docker
   sudo docker run --rm hello-world
   sudo docker compose version
   ```
5. No añadir `vencira` al grupo `docker` de forma automática: da privilegios equivalentes a root. Para la preview usar `sudo docker compose` o un mecanismo específico más adelante. **Nota**: el script `scripts/preview-up.sh` asume `docker compose` sin sudo; adaptar primero cómo ejecutar la preview y permisos de los archivos `.env` y volumen sin hacer `sudo bash scripts/preview-up.sh` a ciegas.
6. El servicio seguirá en loopback y solo se accederá por túnel SSH. No permitir 18731, 18732 ni 5432 en IONOS o UFW.

## Diagnóstico posterior: Docker y UFW verificados (21/10/2026)

Salida real aportada por el usuario, sin acceso autónomo del asistente al VPS:

- Docker Engine: **29.9.2**, funcionando.
- Docker Compose: **v5.6.1**, instalado.
- `systemctl is-active docker`: **active**.
- `sudo docker run --rm hello-world`: **ejecutado correctamente**, descarga y ejecución completadas.
- UFW: **active**; política **deny incoming**, **allow outgoing** y **deny routed**. Puerto SSH **22/tcp** abierto desde Anywhere (IPv4 e IPv6).
- El puerto 22 está abierto globalmente; limitarlo a la IP de gestión estable en IONOS y/o UFW cuando sea viable. No abrir 18731, 18732 ni 5432.
- **No está confirmado** que se hayan deshabilitado las contraseñas o el acceso root por SSH; verificar antes de afirmar endurecimiento final.

## Deploy Key de GitHub, solo lectura (pendiente de ejecución)

Objetivo: permitir al VPS clonar **solo** el repositorio privado
`appvencira/vencira_app` y la rama `chore/bootstrap-vencira`, sin capacidad de push.

Ejecutar desde sesión SSH del VPS como `vencira`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 \
  -f ~/.ssh/id_ed25519_vencira_github \
  -C "vencira-ionos-deploy"
chmod 600 ~/.ssh/id_ed25519_vencira_github
cat ~/.ssh/id_ed25519_vencira_github.pub
```

Si ya existiera el archivo, **no sobrescribirlo**. Considerar passphrase y agente SSH si las descargas son interactivas, u otra estrategia segura para despliegues automatizados. **Nunca compartir ni subir la clave privada**.

Registrar exclusivamente la clave pública en
https://github.com/appvencira/vencira_app/settings/keys

- Settings → Deploy keys → Add deploy key.
- Título `VENCIRA - IONOS VPS - Read Only`.
- Pegar clave pública de `.pub`.
- **No activar Allow write access**.

En el VPS, crear/editar `~/.ssh/config` y agregar:
```sshconfig
Host github-vencira
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_vencira_github
  IdentitiesOnly yes
```

```bash
chmod 600 ~/.ssh/config
ssh -T github-vencira
git ls-remote --heads git@github-vencira:appvencira/vencira_app.git chore/bootstrap-vencira
```

La primera conexión a GitHub debe validar la huella de host oficial
Ed25519 `SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU`
en https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints.
El aviso de GitHub de que no ofrece shell y el código de retorno 1 tras
`ssh -T` son normales si la autenticación ha tenido éxito.

**No proceder aún a clonar/arrancar la preview** hasta que `git ls-remote` confirme el acceso. Tras ello, seguir el procedimiento de `docs/SERVER_PREVIEW.md`,
adaptado a `git@github-vencira` y a permisos de Docker, puesto que el usuario
`vencira` no forma parte del grupo `docker`. No dar permisos de root
indiscriminadamente ni utilizar datos reales.

