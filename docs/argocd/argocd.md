# ArgoCD

[Argo CD](https://argoproj.github.io/argo-cd/) es una herramienta **declarativa** de *despliegue contínuo* para Kubernetes.

## Espacio de nombres

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: argocd
```

Creamos el *namespace*:

```bash
$ kubectl apply -f argocd.yaml
namespace/argocd created
```

### Uso de un *namespace* diferente a `argocd`

En el fichero `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` a partir del cual se instalan los componentes de Argo CD, el *namespace* `argocd` está *hardcodeado* para los objetos:

* *ClusterRoleBinding* > `argocd-application-controller`
* *ClusterRoleBinding* > `argocd-server`

Es necesario modificar el nombre del *namespace* en estos recursos si se despliega Argo CD en un *namespace* diferente a `argocd`.

## Despliegue de los componentes de ArgoCD

Siguiendo las instrucciones de la documentación [Getting Started](https://argoproj.github.io/argo-cd/getting_started/), el despliegue de ArgoCD se realiza aplicando el fichero `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`.

Descargamos el fichero como referencia y revisamos las versiones de las diferentes imágenes que se instalan:

* quay.io/dexidp/dex:v2.25.0 [DEX](https://dexidp.io/) - A Federated OpenID Connect Provider
* argoproj/argocd:v1.8.1 [Argo CD](https://argoproj.github.io/argo-cd/) - A declarative, GitOps continuous delivery tool for Kubernetes
* redis:5.0.10-alpine [Redis](https://redis.io/) - Open source (BSD licensed), in-memory data structure store, used as a database, cache, and message broker

Modificamos el parámetro *imagePullPolicy* para cambiarlo a *IfNotPresent* (en vez de *Always*).

Añdimos el contenido del fichero de instalación de ArgoCD al fichero despliegue (para tener unificada la creación del *namespace* y la del despliegue de la herramienta):

```bash
$ kubectl -n argocd apply -f docs/argocd/deploy/argocd.yaml 
namespace/argocd unchanged
Warning: apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-redis created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-redis created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-redis created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-secret created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server created
service/argocd-server-metrics created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
statefulset.apps/argocd-application-controller created
```

Al cabo de unos minutos:

```bash
$ kubectl -n argocd get pods
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-redis-6fb68d9df5-6c5wg         1/1     Running   0          4m53s
argocd-server-547d9bb879-tx2pb        1/1     Running   0          4m53s
argocd-dex-server-86dc95dfc5-rxn6w    1/1     Running   0          4m53s
argocd-application-controller-0       1/1     Running   0          4m53s
argocd-repo-server-5fb8df558f-5drdq   1/1     Running   0          4m53s
```

## Acceso a la consola de ArgoCD

Todos los servicios expuestos por Argo CD son de tipo ClusterIP.

```bash
$ kubectl -n argocd get svc
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
argocd-dex-server       ClusterIP   10.43.162.56    <none>        5556/TCP,5557/TCP,5558/TCP   6m56s
argocd-metrics          ClusterIP   10.43.37.202    <none>        8082/TCP                     6m56s
argocd-redis            ClusterIP   10.43.166.102   <none>        6379/TCP                     6m56s
argocd-repo-server      ClusterIP   10.43.55.47     <none>        8081/TCP,8084/TCP            6m56s
argocd-server           ClusterIP   10.43.57.82     <none>        80/TCP,443/TCP               6m56s
argocd-server-metrics   ClusterIP   10.43.98.38     <none>        8083/TCP                     6m56s
```

Para exponer la consola usando un *Ingress*, la documentación de Argo CD proporciona [instrucciones para configurar Traefik (v2.2)](https://argoproj.github.io/argo-cd/operator-manual/ingress/#traefik-v22) donde se indica:

> The API server should be run with TLS disabled. Edit the argocd-server deployment to add the --insecure flag to the argocd-server command.

Es necesario modificar el *deployment* del *argocd-server* para incluir `--insecure` al comando ejecutado:

```yaml
...
      containers:
      - command:
        - argocd-server
        - --staticassets
        - /shared/app
        - --insecure # Required to expose Argo CD console using Traefik 2.2 Ingress (https://argoproj.github.io/argo-cd/operator-manual/ingress/#traefik-v22)
        image: argoproj/argocd:v1.8.1
        imagePullPolicy: IfNotPresent
        name: argocd-server
...
```

Podemos configurar Traefik usando un *ingress* o mediante el CRD *IngressRoute* proporcionado por Traefik.

En nuestro caso, usamos el primero:

```yaml
---
apiVersion: networking.k8s.io/v1 # Kubernetes 1.19+
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    kubernets.io/ingress.class: traefik
  name: argocd
spec:
  rules:
  - host: "argocd.dev.lab"
    http:
      paths:
        - path: "/"
          pathType: Prefix
          backend:
            service:
              name: argocd-server
              port:
                number: 80
```

Al aplicar los cambios introducidos en el fichero y aplicarlos:

```bash
 k -n argocd apply -f argocd.yaml 
namespace/argocd unchanged
Warning: apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io unchanged
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io unchanged
serviceaccount/argocd-application-controller unchanged
serviceaccount/argocd-dex-server unchanged
serviceaccount/argocd-redis unchanged
serviceaccount/argocd-server unchanged
role.rbac.authorization.k8s.io/argocd-application-controller unchanged
role.rbac.authorization.k8s.io/argocd-dex-server unchanged
role.rbac.authorization.k8s.io/argocd-redis unchanged
role.rbac.authorization.k8s.io/argocd-server unchanged
clusterrole.rbac.authorization.k8s.io/argocd-application-controller unchanged
clusterrole.rbac.authorization.k8s.io/argocd-server unchanged
rolebinding.rbac.authorization.k8s.io/argocd-application-controller unchanged
rolebinding.rbac.authorization.k8s.io/argocd-dex-server unchanged
rolebinding.rbac.authorization.k8s.io/argocd-redis unchanged
rolebinding.rbac.authorization.k8s.io/argocd-server unchanged
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller unchanged
clusterrolebinding.rbac.authorization.k8s.io/argocd-server unchanged
configmap/argocd-cm unchanged
configmap/argocd-gpg-keys-cm unchanged
configmap/argocd-rbac-cm unchanged
configmap/argocd-ssh-known-hosts-cm unchanged
configmap/argocd-tls-certs-cm configured
secret/argocd-secret unchanged
service/argocd-dex-server unchanged
service/argocd-metrics unchanged
service/argocd-redis unchanged
service/argocd-repo-server unchanged
service/argocd-server unchanged
service/argocd-server-metrics unchanged
deployment.apps/argocd-dex-server unchanged
deployment.apps/argocd-redis unchanged
deployment.apps/argocd-repo-server unchanged
deployment.apps/argocd-server configured
statefulset.apps/argocd-application-controller unchanged
ingress.networking.k8s.io/argocd created
```

> Puede ser necesario realizar un *rollout restart* del *deployment* `argocd-server`: `kubectl -n argocd rollout restart deploy argocd-server`.

En resumen, se ha modificado:

* La definición del *deployment* `argocd-server` para incluir el *flag* `--insecure`
* La creación del recurso *Ingress*

Tras estas modificaciones, podemos acceder a la consola de Argo CD a través de `http://argocd.dev.lab`.
