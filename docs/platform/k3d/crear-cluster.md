# Crear un nuevo clúster con k3d

## Versión

```bash
$ k3d --version
k3d version v5.4.9
k3s version v1.25.7-k3s1 (default)
```

## Descripción

Para crear un nuevo clúster, usamos el comando `k3d cluster create $CLUSTER_NAME`.

Podemos especificar muchas otras opciones, como el número de nodos *master/server* y nodos *agent/worker*. Puedes consultar las opciones disponibles usando el comando `k3d cluster create --help`.

A continuación vamos a crear un clúster desde la línea de comando.

## Creación *manual* del clúster

*k3s* usa por defecto SQLite3 como base de datos para mantener el estado del clúster; en esta situación disponer de múltiples nodos no nos proporciona HA, por lo que vamos a seleccionar únicamente un nodo servidor/master [^dqlite].

Inicialmente creamos sólo un nodo agente. Más adelante crearemos nodos adicionales y los añadiremos al clúster.

Para crear un clúster llamado `dev-cluster` con un nodo servidor y un nodo agente, usamos el comando:

```bash
$$ k3d cluster create demo-cluster --servers 1 --agents 1
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-demo-cluster'
INFO[0000] Created image volume k3d-demo-cluster-images
INFO[0000] Starting new tools node...
INFO[0001] Creating node 'k3d-demo-cluster-server-0'
INFO[0001] Pulling image 'ghcr.io/k3d-io/k3d-tools:5.4.9'
INFO[0003] Pulling image 'docker.io/rancher/k3s:v1.25.7-k3s1'
INFO[0005] Starting Node 'k3d-demo-cluster-tools'
INFO[0023] Creating node 'k3d-demo-cluster-agent-0'
INFO[0023] Creating LoadBalancer 'k3d-demo-cluster-serverlb'
INFO[0024] Pulling image 'ghcr.io/k3d-io/k3d-proxy:5.4.9'
INFO[0036] Using the k3d-tools node to gather environment information
INFO[0037] HostIP: using network gateway 172.18.0.1 address
INFO[0037] Starting cluster 'demo-cluster'
INFO[0037] Starting servers...
INFO[0037] Starting Node 'k3d-demo-cluster-server-0'
INFO[0046] Starting agents...
INFO[0047] Starting Node 'k3d-demo-cluster-agent-0'
INFO[0056] Starting helpers...
INFO[0057] Starting Node 'k3d-demo-cluster-serverlb'
INFO[0064] Injecting records for hostAliases (incl. host.k3d.internal) and for 3 network members into CoreDNS configmap...
INFO[0068] Cluster 'demo-cluster' created successfully!
INFO[0068] You can now use it like this:
kubectl cluster-info
```

Validamos que el clúster se ha creado con:

```bash
$ k3d cluster list
NAME           SERVERS   AGENTS   LOADBALANCER
demo-cluster   1/1       1/1      true
```

Como los nodos de este clúster son contenedores Docker, también podemos validarlo directamente con:

```bash
$ docker ps
CONTAINER ID   IMAGE                            COMMAND                  CREATED              STATUS              PORTS                             NAMES
de2a9e200126   ghcr.io/k3d-io/k3d-proxy:5.4.9   "/bin/sh -c nginx-pr…"   About a minute ago   Up About a minute   80/tcp, 0.0.0.0:41753->6443/tcp   k3d-demo-cluster-serverlb
e22006910048   rancher/k3s:v1.25.7-k3s1         "/bin/k3d-entrypoint…"   About a minute ago   Up About a minute                                     k3d-demo-cluster-agent-0
0cb8f1af7040   rancher/k3s:v1.25.7-k3s1         "/bin/k3d-entrypoint…"   About a minute ago   Up About a minute                                     k3d-demo-cluster-server-0
```

Como vemos, además de los nodos servidor y agente, se despliega un tercer contenedor que nos proporciona un balanceador.

El puerto asignado a la API de Kubernetes se asigna al azar; si queremos especificar un puerto determinado usaremos la opción `--api-port`:

### Conectar al clúster usando `kubectl`

La configuración de conexión con el nuevo clúster se añade automáticamente al fichero `KUBECONFIG` (que por defecto se ubica en `$HOME/.kube.config`).

Puedes ejecutar el comando manualmente:

```bash
k3d kubeconfig merge $NOMBRE_CLUSTER --kubeconfig-switch-context
```

Comprueba cuál es el contexto activo mediante:

```bash
$ kubectl config current-context
k3d-demo-cluster
```

## Agregar un nodo agente al clúster

*k3d* proporciona el comando `k3d node create` con el que añadiremos nuevos nodos al clúster.

Para añadir un nodo agente al clúster `demo-cluster`:

> *k3d* añade el prefijo `k3d-` y el sufijo `-0` (en realidad un índice para indicar el número de réplicas) al nombre que proporcionemos al nuevo nodo.

```bash
$ k3d cluster list
NAME           SERVERS   AGENTS   LOADBALANCER
demo-cluster   1/1       1/1      true
$ export CLUSTER_NAME=demo-cluster
$ k3d node create $CLUSTER_NAME-agent-1 --cluster $CLUSTER_NAME --role agent
INFO[0000] Adding 1 node(s) to the runtime local cluster 'demo-cluster'...
INFO[0000] Using the k3d-tools node to gather environment information
INFO[0000] Starting new tools node...
INFO[0001] Starting Node 'k3d-demo-cluster-tools'
INFO[0003] HostIP: using network gateway 172.18.0.1 address
INFO[0004] Starting Node 'k3d-demo-cluster-agent-1-0'
INFO[0010] Successfully created 1 node(s)!
```

Validamos que se ha creado el nuevo nodo con el rol de agente:

```bash
$ $ k3d node list
NAME                         ROLE           CLUSTER        STATUS
k3d-demo-cluster-agent-0     agent          demo-cluster   running
k3d-demo-cluster-agent-1-0   agent          demo-cluster   running
k3d-demo-cluster-server-0    server         demo-cluster   running
k3d-demo-cluster-serverlb    loadbalancer   demo-cluster   running
```

## Creación del clúster usando un fichero de configuración

A partir de la versión v4.0.0 de *k3d* [^v4] se proporciona la posibilidad de configurar como código cualquiera de las opciones soportadas vía *flags* de la CLI.

Las dos únicas líneas obligatorias en el fichero de configuración son [^required]:

```yaml
apiVersion: k3d.io/v1alpha4 # Versión 5.4.9
kind: Simple
```

El fichero de configuración para crear un clúster con un servidor y un agente sería:

> Usamos como referencia el fichero de configuración de la documentación oficial [^required].
> Como el *schema* todavía está en *alpha*, puede haber cambios y es preferible referirse a la documentación oficial.

```yaml
apiVersion: k3d.io/v1alpha4 # this will change in the future as we make everything more stable
kind: Simple                # internally, we also have a Cluster config, which is not yet available externally
# metadata:
#   name: demo                # name that you want to give to your cluster (will still be prefixed with `k3d-`)
servers: 1                  # same as `--servers 1`
agents:  1                  # same as `--agents 1`
registries:                 # define how registries should be created or used
  create: # creates a default registry to be used with the cluster; same as `--registry-create registry.localhost`
    name: registry.localhost
    host: 0.0.0.0
    hostPort: "5000"
  config: |
    mirrors:
      "registry.localhost:5000":
         endpoint:
          -  "http://registry.localhost:5000"
```

Aunque podemos especificar el nombre del clúster en el fichero de configuración, usaremos el fichero de configuración a modo de plantilla, proporcionando valores específicos desde la línea de comandos (podemos hacer un *override* de cualquier parámetro especificado en el fichero de configuración):

```bash
$ k3d cluster create demo --config k3d-cluster-1s1a+registry.yaml
INFO[0000] Using config file k3d-cluster-1s1a+registry.yaml (k3d.io/v1alpha4#simple)
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-demo'
INFO[0000] Created image volume k3d-demo-images
INFO[0000] Creating node 'registry.localhost'
INFO[0000] Successfully created registry 'registry.localhost'
INFO[0000] Starting new tools node...
INFO[0000] Starting Node 'k3d-demo-tools'
INFO[0001] Creating node 'k3d-demo-server-0'
INFO[0001] Creating node 'k3d-demo-agent-0'
INFO[0001] Creating LoadBalancer 'k3d-demo-serverlb'
INFO[0001] Using the k3d-tools node to gather environment information
INFO[0002] HostIP: using network gateway 172.20.0.1 address
INFO[0002] Starting cluster 'demo'
INFO[0002] Starting servers...
INFO[0002] Starting Node 'k3d-demo-server-0'
INFO[0013] Starting agents...
INFO[0014] Starting Node 'k3d-demo-agent-0'
INFO[0024] Starting helpers...
INFO[0024] Starting Node 'registry.localhost'
INFO[0025] Starting Node 'k3d-demo-serverlb'
INFO[0033] Injecting records for hostAliases (incl. host.k3d.internal) and for 4 network members into CoreDNS configmap...
INFO[0041] Cluster 'demo' created successfully!
INFO[0042] You can now use it like this:
kubectl cluster-info
```

Podemos validar que se ha creado el clúster:

```bash
$ kubectl cluster-info
Kubernetes master is running at https://0.0.0.0:44675
CoreDNS is running at https://0.0.0.0:44675/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:44675/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Validar k3d *registry*

En la configuración de despliegue de k3d hemos incluido un *registry*:

```bash
$ docker ps
CONTAINER ID   IMAGE                            COMMAND                  CREATED          STATUS          PORTS                             NAMES
7d465f5c35e4   ghcr.io/k3d-io/k3d-proxy:5.4.9   "/bin/sh -c nginx-pr…"   40 minutes ago   Up 28 minutes   80/tcp, 0.0.0.0:44675->6443/tcp   k3d-demo-serverlb
73e5ac7066ad   rancher/k3s:v1.25.7-k3s1         "/bin/k3d-entrypoint…"   40 minutes ago   Up 28 minutes                                     k3d-demo-agent-0
4a9745c0f3d7   rancher/k3s:v1.25.7-k3s1         "/bin/k3d-entrypoint…"   40 minutes ago   Up 28 minutes                                     k3d-demo-server-0
8ce590b73979   registry:2                       "/entrypoint.sh /etc…"   40 minutes ago   Up 28 minutes   0.0.0.0:5000->5000/tcp            registry.localhost
```

> Como no hemos configurado certificados para el *registry* desplegado en k3d, debemos incluirlo en Docker como *registro inseguro*: [Test an insecure registry
](https://docs.docker.com/registry/insecure/)

Desplegamos un contenedor con [nginx](https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-docker/) localmente:

```bash
$ docker run --name test-nginx -p 80:80 -d nginx
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
f1f26f570256: Pull complete
84181e80d10e: Pull complete
1ff0f94a8007: Pull complete
d776269cad10: Pull complete
e9427fcfa864: Pull complete
d4ceccbfc269: Pull complete
Digest: sha256:f4e3b6489888647ce1834b601c6c06b9f8c03dee6e097e13ed3e28c01ea3ac8c
Status: Downloaded newer image for nginx:latest
da29a0c11411227d8de5e142172d72093c8f668bb83844d67a93f04dc8cb336f
```

Validamos que se ha desplegado y que está sirviendo la página por defecto:

```bash
$ docker ps | grep 'test-nginx'
da29a0c11411   nginx                            "/docker-entrypoint.…"   2 minutes ago    Up 2 minutes    0.0.0.0:80->80/tcp, :::80->80/tcp   test-nginx

$ curl -s localhost:80 | grep -i 'welcome'
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

Tenemos la imagen de `nginx` descargada localmente:

```bash
$ docker images | grep 'nginx'
nginx                                                       latest         ac232364af84   2 days ago     142MB
```

Etiquetamos la imagen para que referencie el *registry* desplegado en k3d (al que hemos llamado `registry`):

```bash
$ docker tag nginx:latest registry.localhost:5000/xaviaznar/nginx:v1.23
$ docker images | grep -i 'nginx'
nginx                                                       latest         ac232364af84   2 days ago     142MB
registry.localhost:5000/xaviaznar/nginx                     v1.23          ac232364af84   2 days ago     142MB
```

Subimos la imagen al *registry* en k3d:

```bash
$ docker push registry.localhost:5000/xaviaznar/nginx:v1.23
The push refers to repository [registry.localhost:5000/xaviaznar/nginx]
a1bd4a5c5a79: Pushed 
597a12cbab02: Pushed 
8820623d95b7: Pushed 
338a545766ba: Pushed 
e65242c66bbe: Pushed 
3af14c9a24c9: Pushed 
v1.23: digest: sha256:557c9ede65655e5a70e4a32f1651638ea3bfb0802edd982810884602f700ba25 size: 1570
```

Creamos un *deployment* (usando como referencia [Creating and exploring an nginx deployment
](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/#creating-and-exploring-an-nginx-deployment)), pero **haciendo referencia a la imagen local**:

```yaml
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.localhost:5000/xaviaznar/nginx:v1.23
        ports:
        - containerPort: 80
```

Y lo aplicamos:

```bash
$ kubectl apply -f nginx/deployment.yaml
deployment.apps/nginx created
```

Para validar que está funcionando, usamos [port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/):

```bash
$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
helloweb-85bc5c5556-jch9p   1/1     Running   0          26m
nginx-785dc69d4f-kk8md      1/1     Running   0          2m45s
nginx-785dc69d4f-pv9db      1/1     Running   0          2m45s
$ kubectl port-forward pod/nginx-785dc69d4f-kk8md 8080:80
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

En otra terminal:

```bash
$ curl -s localhost:8080 | grep -i 'welcome'
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
```

Finalmente, validamos que los *pods* se han desplegado usando la imagen desde el *registry* en k3d:

```bash
$ kubectl describe pod nginx-785dc69d4f-kk8md | grep -i 'image'
    Image:          registry.localhost:5000/xaviaznar/nginx:v1.23
    Image ID:       registry.localhost:5000/xaviaznar/nginx@sha256:557c9ede65655e5a70e4a32f1651638ea3bfb0802edd982810884602f700ba25
  Normal  Pulling    9m38s  kubelet            Pulling image "registry.localhost:5000/xaviaznar/nginx:v1.23"
  Normal  Pulled     9m29s  kubelet            Successfully pulled image "registry.localhost:5000/xaviaznar/nginx:v1.23" in 9.187628895s (9.188175627s including waiting)
```

## Referencias

* [Introduction to k3d: Run K3s in Docker](https://www.suse.com/c/introduction-k3d-run-k3s-docker-src/) en el Blog de SUSE (Thorsten Klein, 01/03/2021).
* [K3S + K3D = K8S : a new perfect match for dev and test](https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test)

[^dqlite]: En realidad *k3d* (v4.x) proporciona soporte para múltiples réplicas de SQLite mediante el uso de [Dqlite](https://dqlite.io/), una versión *distribuída* de SQLite que soporta *failovers* y HA desarrollada por Canonical. Revisa la documentación [Creating multi-server clusters](https://k3d.io/usage/multiserver/)
[^v4]: [Config File](https://k3d.io/v5.4.9/usage/configfile/) en la documentación oficial de **k3d**.
[^required]: [Required Fields](https://k3d.io/v5.4.9/usage/configfile/#required-fields) en la documentación oficial de **k3d**.
