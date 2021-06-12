# **k3d** - *k3s in Docker*

**[k3d](https://k3d.io/)** (*k3s in Docker*) permite crear clúster basados en **k3s** en los que cada nodo se ejecuta como un contenedor en Docker.

Una de las ventajas de **k3d** es que permite crear clústers rápidamente, del mismo modo que desplegamos contenedores. El único requerimiento para usar **k3d** es disponer de Docker instalado en la máquina.

## Instalación

La instalación de **k3d** requiere tener instalado Docker.

El proceso de instalación se detalla en [k3d.io](https://k3d.io/):

```bash
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
```

La versión instalada es:

```bash
$ k3d --version
k3d version v4.2.0
k3s version v1.20.2-k3s1 (default)
```
