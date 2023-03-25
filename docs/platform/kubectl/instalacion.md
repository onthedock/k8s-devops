# Instalación de `kubectl`

## Versión

```bash
$ kubectl version --client --short
Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.
Client Version: v1.26.3
Kustomize Version: v4.5.7
```

## Descripción

`kubectl` es la herramienta de línea de comandos *por defecto* para interaccionar con Kubernetes a través de su API.

Puedes encontrar la página de documentación oficial en *Kubernetes* [Command line tool (kubectl)](https://kubernetes.io/docs/reference/kubectl/).

## Instalación

En la documentación oficial se indica cómo realizar la instalación de `kubectl` para diferentes sistemas operativos: [Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/), [Mac OS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/) y [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/).

La versión de `kubectl` y la del clúster (o clústers) con los interaccionas deben diferir como máximo en **una versión *minor***. Esto significa que para `kubectl` v1.26 se puede comunicar con clústers v1.25, v1.26 y v1.27.

En Linux, aunque `kubectl` se puede instalar a través del gestor de paquetes del sistema, esto puede provocar que el cliente `kubectl` se actualice más allá de esa diferencia de una versión minor con respecto a los clústers de Kubernetes (que suelen actualizarse más lentamente).

Para evitar problemas inesperados debidos a las diferencias entre la versión de `kubectl` y la del clúster de Kubernetes, es recomendable realizar la instalación (y actualización) de `kubectl` de forma manual.

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

> - `-L` (o `--location`) permite seguir redirecciones (3xx)
> - `-O` (o `--remote-name`) indica el nombre de salida del contenido descargado
> - `-s` (o `--silent`) activa el modo "silencioso"

Ejecutando el comando anterior, descargamos el binario de `kubectl` para la última versión estable:

```bash
$ curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   138  100   138    0     0    586      0 --:--:-- --:--:-- --:--:--   584
100 45.8M  100 45.8M    0     0  5021k      0  0:00:09  0:00:09 --:--:-- 5087k
```

Podemos convertirlo en ejecutable y usarlo directamente (en "modo portable", sin necesidad de instalarlo), pero lo habitual es instalarlo a nivel de sistema.

Siguiendo las instrucciones de la documentación oficial:

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Validamos la versión instalada:

```bash
$ kubectl version --client --short
Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.
Client Version: v1.26.3
Kustomize Version: v4.5.7
```
