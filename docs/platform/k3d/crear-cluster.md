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

## Referencias

* [Introduction to k3d: Run K3s in Docker](https://www.suse.com/c/introduction-k3d-run-k3s-docker-src/) en el Blog de SUSE (Thorsten Klein, 01/03/2021).
* [K3S + K3D = K8S : a new perfect match for dev and test](https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test)

[^dqlite]: En realidad *k3d* (v4.x) proporciona soporte para múltiples réplicas de SQLite mediante el uso de [Dqlite](https://dqlite.io/), una versión *distribuída* de SQLite que soporta *failovers* y HA desarrollada por Canonical. Revisa la documentación [Creating multi-server clusters](https://k3d.io/usage/multiserver/)
[^v4]: [Config File](https://k3d.io/v5.4.9/usage/configfile/) en la documentación oficial de **k3d**.
[^required]: [Required Fields](https://k3d.io/v5.4.9/usage/configfile/#required-fields) en la documentación oficial de **k3d**.
