# **k3d** - *k3s in Docker*

**[k3d](https://k3d.io/)** (*k3s in Docker*) permite crear clúster basados en **k3s** en los que cada nodo se ejecuta como un contenedor en Docker.

Una de las ventajas de **k3d** es que permite crear clústers rápidamente, del mismo modo que desplegamos contenedores. El único requerimiento para usar **k3d** es disponer de Docker instalado en la máquina.

## Instalación

La instalación de **k3d** requiere tener instalado Docker.

El proceso de instalación se detalla en [k3d.io](https://k3d.io/):

> No es seguro instalar **nada** directamente desde internet. Revisa el contenido del script <https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh> o instala "a ciegas" por tu cuesta y riesgo.

```bash
$ wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
Preparing to install k3d into /usr/local/bin
[sudo] password for operador: 
k3d installed into /usr/local/bin/k3d
Run 'k3d --help' to see what you can do with it.
```

La versión instalada es:

```bash
$ k3d --version
k3d version v5.4.9
k3s version v1.25.7-k3s1 (default)
```
