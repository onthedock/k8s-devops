# Proceso de instalación del clúster

## Provisionar la infraestructura

En estos momentos, la infraestructura del clúster son máquinas virtuales creadas usando Vagrant (con VirtualBox).

El fichero `Vagrantfile` es un bucle que genera tantas máqunas como se indiquen en la variable `NodeCount`.

Las máquinas usan la imagen `ubuntu/focal64` y establecen el `hostname`y la IP `192.168.1.101-192.168.192.1.10#{i}`.

> Quizás sería mejor especificar la IP como `192.168.1.#{100+i}`, lo que permitiría cualquier número de nodos entre 1 y 154, mientras que ahora sólo se permiten 9 nodos, con `i` entre 1 y 9.

Las máquinas virtuales tienen 1vCPU y 1024 MB de RAM.

El fichero `Vagrantfile` también tienen vario *scripts* que realizan la configuración en las máquinas provisionadas:

- habilitar la autenticación en SSH usando usuario y password (se podría eliminar)
- crear el usuario `operador` y establecer el password como `admin`
- establecer el password del usuario `root` a  `admin`
- copiar la clave SSH `id_rsa.pub` del equipo local a las máquinas virtuales
- copiar la clave SSH al fichero `authorized_keys` del usuario `operador`
- configura `sudo` para el usuario `operador` sin necesidad de proporcionar el password (para la instalación de **k3sup**).

> Todo está **terriblemente hardcodeado**, por lo que estaría bien parametrizar el *script* y que todos estos valores fueran variables establecidas al principio del *script*. Hay que tener en cuenta que el usuario `operador` es el que se usa después en la instalación de **k3sup**.

## Instalación de Kubernetes

Para la instalación de Kubernetes uso **k3sup**, que automatiza el proceso de instalación de un clúster multinodo basado en K3s.

En el *script* de instalación de **k3sup** es donde se indica el número de servidores y el número de agentes del clúster; **k3sup** se encarga de obtener el *token* para unir los *agents* al clúster y descarga el fichero `kubeconfig` para por conectarse tras la instalación.

> Hasta donde sé, de momento **k3sup** no realiza instalaciones con HA del clúster de Kubernetes.

## Configuración del clúster

Antes de instalar aplicaciones en el clúster, habría que instalar una *StorageClass* y así eliminar la dependencia de [`local-path`](https://github.com/rancher/local-path-provisioner/blob/master/README.md#usage), que es la que usa K3s por defecto.

En [Volumes and Storage](https://rancher.com/docs/k3s/latest/en/storage/) se indica que K3s soporta [Longhorn](https://longhorn.io/docs/) (AMD64 y ARM64 (experimental)).

Probablemente la mejor manera de tener Longhorn instalado tras la creación del clúster sea usar la capacidad de K3s de *autoinstalar* los *manifests* en la carpeta `/var/lib/rancher/k3s/server/manifests`, como se indica en [Helm](https://rancher.com/docs/k3s/latest/en/helm/).

> He copiado el fichero YAML descargado desde `https://raw.githubusercontent.com/longhorn/longhorn/v1.1.2/deploy/longhorn.yaml` en `/var/libr/rancher/k3s/server/manifests/` y he reiniciado el nodo server... Tras esperar unos minutos, se ha creado el *namespace* y se han desplegado los *pods* relacionados con Longhorn en el *namespace* `longhorn-system`.

Tras la instalación de Longhorn, `local-path` sigue siendo la *storageClass* por defecto:

```bash
$ kubectl get storageclass
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  150m
longhorn               driver.longhorn.io      Delete          Immediate              true                   7m9s
```

En la documentación de Kubernetes [](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/#changing-the-default-storageclass) tenemos instrucciones sobre cómo convertir la *StorageClass* `longhorn` en la *StorageClass* por defecto del clúster.

Para evitar errores, la documentación recomienda primero eliminar la anotación de la *StorageClass* por defecto y después, añadir la anotación a la nueva *StorageClass*:

```bash
$ kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

storageclass.storage.k8s.io/local-path patched
```

Después, *parcheamos* la *StorageClass* y añadir la anotación `storageclass.kubernetes.io/is-default-class` con el valor `true`:

```bash
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Indicar una *StorageClass* como *default* **no elimina la anotación de la *StorageClass* que estuviera como *default* en el clúster**:

```bash
$ kubectl get sc
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io      Delete          Immediate              true                   48m
local-path           rancher.io/local-path   Delete          WaitForFirstConsumer   false                  3h11m
```

Podemos acceder al *Dashboard* de Longhorn mediante *port-forward*:

```bash
$ kubectl get svc -n longhorn-system
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
longhorn-backend    ClusterIP   10.43.93.162    <none>        9500/TCP    11m
longhorn-frontend   ClusterIP   10.43.32.224    <none>        80/TCP      11m
csi-attacher        ClusterIP   10.43.109.181   <none>        12345/TCP   6m46s
csi-provisioner     ClusterIP   10.43.107.234   <none>        12345/TCP   6m46s
csi-resizer         ClusterIP   10.43.16.205    <none>        12345/TCP   6m45s
csi-snapshotter     ClusterIP   10.43.144.90    <none>        12345/TCP   6m45s
$ kubectl port-forward svc/longhorn-frontend 8080:80
Error from server (NotFound): services "longhorn-frontend" not found
❯ k port-forward svc/longhorn-frontend 8080:80 -n longhorn-system
Forwarding from 127.0.0.1:8080 -> 8000
Forwarding from [::1]:8080 -> 8000
...
```

> #ToDo -> Configurar un *Ingress* para el *Dashboard* de Longhorn.

## Siguientes pasos

Ahora tenemos el clúster preparado, pero vacío. El siguiente paso es empezar a instalar las aplicaciones.

Una opción es instalar ArgoCD. Una vez listo ArgoCD, desplegamos el *custom resource* que define una aplicación en ArgoCD, que básicamente indica de dónde obtener los ficheros necesarios para desplegar la aplicación (*manifests* o *Helm Charts*) y dónde deben desplegarse.

Quizás la mejor opción es que los ficheros de definición de esas aplicaciones también se encuentren en GitHub (todavía tengo que mirar cómo organizarlos, si un repositorio por aplicación o diferentes "carpetas" por aplicación en el repo). De esa forma, la instalación de las aplicaciones en un "clúster vacío" siempre partirían de la última versión guardada en GitHub. Con este método, también podría elegir qué aplicacines instalar, simplemente, configurando el CR de la aplicación en ArgoCD para que se desplieque automáticamente...

Para hacer pruebas, sin la dependencia de GitHub, puedo usar el mismo mecanismo, pero apuntando a un repositorio "local" con Gitea, desplegado en el clúster antes de "publicarlo" en el repo de GitHub.

Otra opción sería usar ArgoCD para desplegar Gitea en el clúster y desplegar las aplicaciones desde ahí; sin embargo, tras desplegar Gitea, está vacío y debería, de algún modo, realizar el clonado de los CRs de ArgoCD para subirlos a Gitea... Por tanto, si al final del día debo pasar siempre por GitHub, me parece más *limpio* que todo lo "publicado" esté en GitHub.

Eso significa que tengo que avanzar en la línea de:

- automatizar la instalación de ArgoCD (que seguramente se puede desplegar como una *Helm Chart*)
- aprender cómo desplegar aplicaciones usando los *custom resources* de ArgoCD.

El flujo para desplegar aplicaciones sería algo como:

- primero, desplegamos los componentes de la aplicación de forma manual, vía `kubectl` o con *Helm*. (Sobre este clúster o sobre un clúster más sencillo, de desarrollo o sobre este mismo clúster, en un *namespace* de desarrollo)
- una vez validado el proceso de instalación, configuración, etc..., generar la aplicación en ArgoCD para que se despliegue automáticamente en plan GitOps.

Para personalizar la instalación de *charts* de terceros, un opción es generar una *umbrella chart* y colocar la *chat* que queremos desplegar y un fichero *values.yaml* que sobrescribe los valores por defecto de la *chart* original.
