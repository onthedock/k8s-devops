# Instalación de Docker Engine

## Instalación de Docker Engine en Ubuntu 22 LTS

Seguimos las instrucciones oficiales de la página [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

En primer lugar, nos aseguramos de desinstalar cualquier versión anterior que haya en el sistema:

```bash
$ sudo apt-get remove docker docker-engine docker.io containerd runc
[sudo] password for operador:
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
E: Unable to locate package docker-engine
```

> Las imágenes se almacenan en `/var/lib/docker` y no se eliminan al desinstalar Docker.

### Prerequisitos

Actualizar el índice y los paquetes necesarios para que `apt` puede acceder al repositorio a través de HTTPS:

```bash
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg
```

Actualizar la clave GPG de Docker:

```bash
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Incluir el repositorio a la lista de fuentes de `apt`:

```bash
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Validamos que se ha creado el fichero:

```bash
$ cat /etc/apt/sources.list.d/docker.list 
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu   jammy stable
```

### Instalación

Para instalar Docker Engine, ejecuta:

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Tras la instalación, comprobamos que Docker se ha instalado correctamente:

```bash
$ docker -v
Docker version 23.0.1, build a5ee5b1
```

Obtén información completa de Docker Engine en el sistema mediante:

```bash
$ sudo docker info
Client:
 Context:    default
 Debug Mode: false
 Plugins:
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.10.2
    Path:     /usr/libexec/docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v2.16.0
    Path:     /usr/libexec/docker/cli-plugins/docker-compose
  scan: Docker Scan (Docker Inc.)
    Version:  v0.23.0
    Path:     /usr/libexec/docker/cli-plugins/docker-scan

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 23.0.1
 Storage Driver: overlay2
  Backing Filesystem: extfs
  Supports d_type: true
  Using metacopy: false
  Native Overlay Diff: true
  userxattr: false
 Logging Driver: json-file
 Cgroup Driver: systemd
 Cgroup Version: 2
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: io.containerd.runc.v2 runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 1e1ea6e986c6c86565bc33d52e34b81b3e2bc71f
 runc version: v1.1.4-0-g5fd4c4d
 init version: de40ad0
 Security Options:
  apparmor
  seccomp
   Profile: builtin
  cgroupns
 Kernel Version: 5.15.0-67-generic
 Operating System: Ubuntu 22.04.2 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 1
 Total Memory: 969.5MiB
 Name: k3d-ubuntu22-lts
 ID: f55122bd-f813-4ce8-b43c-525a5945cee1
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

### Gestionar Docker con un usuario no-root

Docker requiere el uso de permisos elevados, por lo que si quieres gestionar contenedores con tu usuario no-root, debes seguir las instrucciones descritas en [Linux post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/)

> Esto supone un riesgo de seguridad!!

En primer lugar, crear el grupo `docker` (es probable que ya exista, pues se crea durante el proceso de instalación de Docker Engine):

```bash
$ sudo groupadd docker
groupadd: group 'docker' already exists
```

Añade el usuario al grupo `docker`; para añadir tu usuario actual:

```bash
sudo usermod -aG docker $USER
```

> Para que los cambios tengan efecto, debes iniciar sesión de nuevo.
