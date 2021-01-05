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

