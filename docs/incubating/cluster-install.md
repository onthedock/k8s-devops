# Proceso de instalación del clúster

## Provisionar la infraestructura

En estos momentos, la infraestructura del clúster son máquinas virtuales creadas usando Vagrant (con VirtualBox).

El fichero `Vagrantfile` es un bucle que genera tantas máqunas como se indiquen en la variable `NodeCount`.

Las máquinas usan la imagen `ubuntu/focal64` y establecen el `hostname`y la IP `192.168.1.101-192.168.192.1.10#{i}`.

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

```bash
wget -O longhorn-v1.1.2-install.yaml https://raw.githubusercontent.com/longhorn/longhorn/v1.1.2/deploy/longhorn.yaml
```

> He copiado el fichero YAML descargado desde `https://raw.githubusercontent.com/longhorn/longhorn/v1.1.2/deploy/longhorn.yaml` en `/var/libr/rancher/k3s/server/manifests/` y he reiniciado el nodo server... Tras esperar unos minutos, se ha creado el *namespace* y se han desplegado los *pods* relacionados con Longhorn en el *namespace* `longhorn-system`.

Tras la instalación de Longhorn, `local-path` sigue siendo la *storageClass* por defecto:

```bash
$ kubectl get storageclass
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  150m
longhorn               driver.longhorn.io      Delete          Immediate              true                   7m9s
```

> #ToDo Automatizar la configuración de la *storageClass* Longhorn por defecto en el clúster.

En la documentación de Kubernetes [Changing de default storage class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/#changing-the-default-storageclass) tenemos instrucciones sobre cómo convertir la *StorageClass* `longhorn` en la *StorageClass* por defecto del clúster.

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

## Siguientes pasos (brainstorming)

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

### Instalación de ArgoCD

La instalación de ArgoCD se realiza aplicando un único manifiesto, por lo que una buena opción sea instalarlo conjuntamente con la *storageClass* durante el arranque del clúster de K3s.

La versión 2.x de ArgoCD introduce un modo *core* que sólo instala lo básico y que le permite ser más ligero y eficiente. En el modo *core* no se instala la UI ni el modo multi-tenant de ArgoCD, lo que reduce el número de componentes a instalar.

Además introduce un modo de instalación que sólo requiere permisos a nivel de *namespace* (y no a nivel de clúster); en este modo ArgoCD sólo puede desplegar aplicaciones en *otros* clústers, lo que es ideal para entornos exclusivos de CI/CD, por ejemplo.

Para no complicar las cosas, de momento usaría la opción *tradicional* de instalación de ArgoCD, pero la opción de ArgoCD-Core encaja en mi escenario, con un solo *tenant*. Además, elimina la necesidad de disponer de un elemento de SSO para autenticar usuarios para la consola de ArgoCD, lo que está bien. Parece que la gestión de ArgoCD se realiza exclusivamente a través de la API de Kubernetes, lo que está bien, pero en la sesión de presentación se usa la herramienta de línea de comando `argocd`, por lo que, como decía, tengo que probarlo antes de asumirlo como opción por defecto.

Volviendo a la instalación de ArgoCD, y con la nueva filosofía de instalar versiones específicas de los productos, descargo el instalador de ArgoCD de la última versión disponible, 2.1.0.

Todas las *releases* disponibles se encuentran en [Argo-CD Releases](https://github.com/argoproj/argo-cd/releases):

```bash
kubectl create namespace argocd
wget -O argocd-v2.1.0-install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v2.1.0/manifests/install.yaml
```

Copio el *manifest* al nodo *server*, lo muevo a la carpeta `/var/lib/rancher/k3s/server/manifests` y reinicio el nodo.

No se ha creado el *namespace* `argocd`, por lo que es probable que la instalación de los componentes no se haya realizado :(

He modificado el fichero de instalación para incluir la creación del *namespace*  `argocd` y vuelvo a intentarlo. No tengo claro si colocando el *manifest* sólo del *namespace* funcionaría, ya que no hay ninguna seguridad de que los *manifests* en la carpeta de `.../manifests/` de K3s se apliquen en ningún orden concreto...

Ahora sí que se ha creado el *namespace*. Los *crds* también se han creado... Por lo que esperaré un rato hasta que se empiecen a crear los *pods* en el *namespace* `argocd`.

> Como el *namespace* `argocd` no existía, se han creado los recursos en el *namespace* `default`. En vez de intentar arreglarlo manualmente, intento reproducir una instalación "limpia" usando el *manifest* ya modificado para incluir el nombre del *namespace*. Destruyo el clúster y vuelvo a crearlo.

Por cierto, que he probado a crear el clúster usando `vagrant up && ./k3s-cluster-install.sh` y ha funcionado.

```bash
scp ~/repos/k8s-devops/docs/incubating/bootstrap/*.yaml operador@192.168.1.101:/home/operador
[operador@k3s-1:~$] sudo mv *.yaml /var/lib/rancher/k3s/server/manifests
```

Ok, he vuelto a crear el clúster, pero el problema está en que los recursos en el *manifest* de instalación de ArgoCD no incluyen el *namespace*, por lo que se crean en el *namespace* `default`. Está claro que está pensado para que se aplique desde la línea de comando usando `kubectl apply -f argocd-install.yaml -n argocd`, como indica la documentación.

Para solucionarlo, he generado el fichero de nuevo, usando el comando:

```bash
$ kubectl apply -f argocd-v2.1.0-install.yaml \
  -n argocd --dry-run=client  -o yaml \
  | tee argocd-v2.1.0-install-namespace-argocd.yaml
```

De esta forma, `kubectl` procesa el fichero original, en el que no se ha indicado el *namespace* para ningún recursos y lo *procesa* como si fuera a aplicarse en el *namespace* `argocd`. La salida del comando la vuelco al fichero con los recursos asignados al *namespace* `argocd`:

> Antes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
spec:
...
```

> Después

Revisando con detalle el objeto generado por `kubectl apply --dry-run=client` vemos que es de tipo `kind: List`; aplicando el fichero directamente desde la CLI, funciona, pero parece que no acaba de funcionar cuando se tiene que *autodesplegar* como `addon` por K3s.

```yaml
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app.kubernetes.io/component":"server ...
        <-- removed --> 
    labels:
      app.kubernetes.io/component: server
      app.kubernetes.io/name: argocd-server
      app.kubernetes.io/part-of: argocd
    name: argocd-server
    namespace: argocd
  spec:
  ...
```

Como puede observarse, los elementos limitados al *namespace* reciben la clave `namespace: argocd` (al margen de las anotaciones que aplica Kuberentes), por lo que este sencillo método permite generar el *manifest* corregido, ajustando los recursos al *namespace*  `argocd` sin complicaciones.

## Aplicaciones

> Sigo avanzando, con el despligue manual de ArgoCD hasta que pueda volver a dedicarle algo de tiempo y ver porqué falla...

> Para establecer la contraseña `argocdadmin`:

  ```bash
  kubectl -n argocd patch secret argocd-secret \
      -p '{"stringData": {
        "admin.password": "$2a$10$iF4kFuR9l9EqPhvuyVYg8.iIHTyjQPfbh9.K0ZsL9fDWb91pvcySG",
        "admin.passwordMtime": "'$(date +%FT%T%Z)'"
      }}'
  ```

Para desplegar una aplicación usando ArgoCD, tenemos que crear un *custom resource* que describa la aplicación a desplegar. El *cr* define de dónde obtener los *manifests* o la *Helm Chart*.

Para configurar de forma declarativa una aplicación en ArgoCD, se usa el *CR* `Application`:

> El *namespace* en el que se despliega la aplicación debe existir previamente en el clúster.

En el siguiente ejemplo, desplegamos la aplicación `guestbook` desde el repositorio de Kubernetes:

```yaml hl_lines="2"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-all-in-one
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/kubernetes/examples.git
    targetRevision: HEAD
    path: guestbook/all-in-one
  destination:
    server: https://kubernetes.default.svc
    namespace: demo-argocd
```

Todas las aplicaciones pueden estar en el mismo repositorio, ya que en el campo `path` se puede indicar en qué *carpeta* dentro del repositorio. También podemos especifica la `targetRevision: HEAD`, por si queremos desplegar una *revision* concreta, por ejemplo una rama correspondiente a una PR (supongo).

Hay un par de cosas a tener en cuenta; por un lado el tema del *finalizer*. Por defecto, al borrar una aplicación de ArgoCD **[no se realiza el borrado de los recursos definidos](https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/#applications)**; si queremos que se realice el borrado en cascada, tenemos que añadir como *finalizer* a ArgoCD:

```yaml
metadata:
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

Para el caso específico de *Helm Charts*, hay que especificar obligatoriamente `chart`en vez de `spec.source`:

```yaml
spec:
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo
```

Los *custom resources* de tipo `Application` de ArgoCD se despliegan en el *namespace* `argocd` (o donde se haya desplegado ArgoCD).
