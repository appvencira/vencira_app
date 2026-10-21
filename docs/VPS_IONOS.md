# VENCIRA · VPS de desarrollo en IONOS

Estado: **VPS creado, pendiente de acceso SSH verificado y despliegue**.
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
