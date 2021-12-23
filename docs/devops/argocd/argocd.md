# ArgoCD

[Argo CD](https://argoproj.github.io/argo-cd/) es una herramienta **declarativa** de *despliegue continuo* para Kubernetes.

> Este documento se ha probado con la versión 2.1.7 de ArgoCD.

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
$ kubectl apply -f argocd-namespace.yaml
namespace/argocd created
```

> La creación del *Namespace* desde el *script* `argocd_deploy.sh` se realiza mediante `kubectl create namespace argocd` (si el *Namespace* no existe). 

### Uso de un *namespace* diferente a `argocd`

En el fichero `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` a partir del cual se instalan los componentes de Argo CD, el *namespace* `argocd` está *hardcodeado* para los objetos:

* *ClusterRoleBinding* > `argocd-application-controller`
* *ClusterRoleBinding* > `argocd-server`

Es necesario modificar el nombre del *namespace* en estos recursos si se despliega Argo CD en un *namespace* diferente a `argocd`.

## Despliegue de los componentes de ArgoCD

Siguiendo las instrucciones de la documentación [Getting Started](https://argoproj.github.io/argo-cd/getting_started/), el despliegue de ArgoCD se realiza aplicando el fichero `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`.

Descargamos el fichero como referencia y revisamos las versiones de las diferentes imágenes que se instalan:

* `ghcr.io/dexidp/dex:v2.27.0` [DEX](https://dexidp.io/) - A Federated OpenID Connect Provider
* `quay.io/argoproj/argocd:v2.1.7` [Argo CD](https://argoproj.github.io/argo-cd/) - A declarative, GitOps continuous delivery tool for Kubernetes
* `redis:6.2.4-alpine` [Redis](https://redis.io/) - Open source (BSD licensed), in-memory data structure store, used as a database, cache, and message broker

> Para no modificar el fichero original generado por el proyecto de ArgoCD, dejamos el parámetro *imagePullPolicy* como *Always*, aunque sería interesante cambiarlo por `IfNotPresent`.

Desplegamos ArgoCD:

```bash
kubectl -n argocd apply -f argocd-install-stable-v2.1.7.yaml 
```

Al cabo de unos minutos:

```bash
$ kubectl get deploy -n argocd
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
argocd-redis         1/1     1            1           13m
argocd-dex-server    1/1     1            1           13m
argocd-repo-server   1/1     1            1           13m
argocd-server        1/1     1            1           13m
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

Para exponer la consola usando un *Ingress*, debemos activar el acceso *inseguro* (deshabilitando TLS).

### Configuración mediante variables de entorno

En la versión 2.1.17 de ArgoCD, podemos observar cómo se han incluido variables de entorno para realizar la configuración del servidor `argocd-server`, en vez de tener que modificar el fichero *original* de despliegue de ArgoCD.

```yaml
...
containers:
  - command:
    - argocd-server
    env:
    - name: ARGOCD_SERVER_INSECURE
      valueFrom:
        configMapKeyRef:
          key: server.insecure
          name: argocd-cmd-params-cm
          optional: true
    - name: ARGOCD_SERVER_BASEHREF
      valueFrom:
        configMapKeyRef:
          key: server.basehref
          name: argocd-cmd-params-cm
          optional: true
...
```

Como vemos, la variable `ARGOCD_SERVER_INSECURE` se puede configurar a través de un *ConfigMap*.

> La documentación oficial no está actualizada y sigue indicando que debe añadirse el *flag* `--insecure` al comando `argocd-server`: [Ingress Configuration: Traefik (v2.2)](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#traefik-v22).

La versión 2.1.17 de ArgoCD permite realizar la configuración de `argocd-server` a través de la variable de entorno `ARGOCD_SERVER_INSECURE` obtenida del *ConfigMap* `argocd-cmd-params-cm`.

Todas las opciones de configuración que pueden incluirse en el *ConfigMap* se encuentran en [argocd-cmd-params-cm.yaml](https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/argocd-cmd-params-cm.yaml)

```yaml hl_lines="12"
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  ## Server properties
  # Run server without TLS
  server.insecure: "true"  
```

Tras realizar la modificación, debemos reiniciar el *Deployment* para que los contenedores se creen de nuevo con la variable de entorno definida:

```bash
kubectl -n argocd rollout restart deploy argocd-server
```

### Configuración mediante el *flag* `--insecure`

**Es preferible realizar la configuración a través del *ConfigMap* en vez de modificar el fichero de despliegue para incluir el *flag*.**

La documentación de Argo CD proporciona [instrucciones para configurar Traefik (v2.2)](https://argoproj.github.io/argo-cd/operator-manual/ingress/#traefik-v22) donde se indica:

> The API server should be run with TLS disabled. Edit the `argocd-server` deployment to add the `--insecure` flag to the argocd-server command.

Es necesario modificar el *deployment* de *argocd-server* para incluir `--insecure` al comando ejecutado:

```yaml hl_lines="7"
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

Es necesario reiniciar los pods de `argocd-server` para que los cambios sean efectivos:

```bash
kubectl -n argocd rollout restart deploy argocd-server
```

## Ingress de acceso a la consola de ArgoCD

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

Desplegamos el *Ingress*:

```bash
kubectl -n argocd apply -f argocd-ingress-traefik.yaml 
```

> Puede ser necesario realizar un *rollout restart* del *deployment* `argocd-server`: `kubectl -n argocd rollout restart deploy argocd-server`.

En resumen, se ha modificado:

* Se ha añadido la configuración `server.insecure: "true"` en el *ConfigMap* `argocd-cmd-params-cm`.
* (Es posible conseguir el mismo resultado mediante la inclusión del *flag* `--insecure` en el *deployment* `argocd-server`)
* La creación del recurso *Ingress*

Tras estas modificaciones, podemos acceder a la consola de Argo CD a través de `http://argocd.dev.lab`.
