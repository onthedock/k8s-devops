# Crear un nuevo clúster con k3d

## Versión

```bash
$ k3d --version
k3d version v4.2.0
k3s version v1.20.2-k3s1 (default)
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
$ k3d cluster create dev-cluster -s 1 -a 1
INFO[0000] Prep: Network                                
INFO[0000] Created network 'k3d-dev-cluster'            
INFO[0000] Created volume 'k3d-dev-cluster-images'      
INFO[0001] Creating node 'k3d-dev-cluster-server-0'     
INFO[0001] Creating node 'k3d-dev-cluster-agent-0'      
INFO[0001] Creating LoadBalancer 'k3d-dev-cluster-serverlb' 
INFO[0001] Starting cluster 'dev-cluster'               
INFO[0001] Starting servers...                          
INFO[0001] Starting Node 'k3d-dev-cluster-server-0'     
INFO[0010] Starting agents...                           
INFO[0010] Starting Node 'k3d-dev-cluster-agent-0'      
INFO[0023] Starting helpers...                          
INFO[0023] Starting Node 'k3d-dev-cluster-serverlb'     
INFO[0024] (Optional) Trying to get IP of the docker host and inject it into the cluster as 'host.k3d.internal' for easy access 
INFO[0030] Successfully added host record to /etc/hosts in 3/3 nodes and to the CoreDNS ConfigMap 
INFO[0030] Cluster 'dev-cluster' created successfully!  
INFO[0030] --kubeconfig-update-default=false --> sets --kubeconfig-switch-context=false 
INFO[0030] You can now use it like this:                
kubectl config use-context k3d-dev-cluster
kubectl cluster-info
```

Validamos que el clúster se ha creado con:

```bash
$ k3d cluster list
NAME          SERVERS   AGENTS   LOADBALANCER
dev-cluster   1/1       1/1      true
```

Como los nodos de este clúster son contenedores Docker, también podemos validarlo directamente con:

```bash
$ docker ps 
CONTAINER ID   IMAGE                      COMMAND                  CREATED              STATUS              PORTS                             NAMES
311f7f0cf5dc   rancher/k3d-proxy:v4.2.0   "/bin/sh -c nginx-pr…"   About a minute ago   Up About a minute   80/tcp, 0.0.0.0:32945->6443/tcp   k3d-dev-cluster-serverlb
81521d5ea62f   rancher/k3s:v1.20.2-k3s1   "/bin/k3s agent"         About a minute ago   Up About a minute                                     k3d-dev-cluster-agent-0
d995147a0d08   rancher/k3s:v1.20.2-k3s1   "/bin/k3s server --t…"   About a minute ago   Up About a minute                                     k3d-dev-cluster-server-0
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
k3d-dev-cluster
```

## Agregar un nodo agente al clúster

*k3d* proporciona el comando `k3d node create` con el que añadiremos nuevos nodos al clúster.

Para añadir un nodo agente al clúster `dev-cluster`:

> *k3d* añade el prefijo `k3d-` y el sufijo `-0` (en realidad un índice para indicar el número de réplicas) al nombre que proporcionemos al nuevo nodo.

```bash
$ k3d cluster list
NAME          SERVERS   AGENTS   LOADBALANCER
dev-cluster   1/1       1/1      true
$ export CLUSTER_NAME=dev-cluster
$ k3d node create dev-cluster-agent-1 --cluster $CLUSTER_NAME --role agent
INFO[0000] Starting Node 'k3d-dev-cluster-agent-1-0'
```

Validamos que se ha creado el nuevo nodo con el rol de agente:

```bash
$ k3d node list
NAME                        ROLE           CLUSTER       STATUS
k3d-dev-cluster-agent-0     agent          dev-cluster   running
k3d-dev-cluster-agent-1-0   agent          dev-cluster   running
k3d-dev-cluster-server-0    server         dev-cluster   running
k3d-dev-cluster-serverlb    loadbalancer   dev-cluster   running
```

## Creación del clúster usando un fichero de configuración

A partir de la versión v4.0.0 de *k3d* [^v4] se proporciona la posibilidad de configurar como código cualquiera de las opciones soportadas vía *flags* de la CLI.

Las dos únicas líneas obligatorias en el fichero de configuración son [^required]:

```yaml
apiVersion: k3d.io/v1alpha2
kind: Simple
```

El fichero de configuración para crear un clúster con un servidor y un agente sería:

> Usamos como referencia el fichero de configuración de la documentación oficial [^required] y comentamos las opciones que no necesitamos.

```yaml
apiVersion: k3d.io/v1alpha2 # this will change in the future as we make everything more stable
kind: Simple # internally, we also have a Cluster config, which is not yet available externally
# name: mycluster # name that you want to give to your cluster (will still be prefixed with `k3d-`)
servers: 1 # same as `--servers 1`
agents:  1 # same as `--agents 1`
# kubeAPI: # same as `--api-port myhost.my.domain:6445` (where the name would resolve to 127.0.0.1)
#   host: "myhost.my.domain" # important for the `server` setting in the kubeconfig
#   hostIP: "127.0.0.1" # where the Kubernetes API will be listening on
#   hostPort: "6445" # where the Kubernetes API listening port will be mapped to on your host system
# image: rancher/k3s:v1.20.4-k3s1 # same as `--image rancher/k3s:v1.20.4-k3s1`
# network: my-custom-net # same as `--network my-custom-net`
# token: superSecretToken # same as `--token superSecretToken`
# volumes: # repeatable flags are represented as YAML lists
#   - volume: /my/host/path:/path/in/node # same as `--volume '/my/host/path:/path/in/node@server[0];agent[*]'`
#     nodeFilters:
#       - server[0]
#       - agent[*]
# ports:
#   - port: 8080:80 # same as `--port '8080:80@loadbalancer'`
#     nodeFilters:
#       - loadbalancer
# labels:
#   - label: foo=bar # same as `--label 'foo=bar@agent[1]'`
#     nodeFilters:
#       - agent[1]
# env:
#   - envVar: bar=baz # same as `--env 'bar=baz@server[0]'`
#     nodeFilters:
#       - server[0]
# registries: # define how registries should be created or used
#   create: true # creates a default registry to be used with the cluster; same as `--registry-create`
#   use:
#     - k3d-myotherregistry:5000 # some other k3d-managed registry; same as `--registry-use 'k3d-myotherregistry:5000'`
#   config: | # define contents of the `registries.yaml` file (or reference a file); same as `--registry-config /path/to/config.yaml`
#     mirrors:
#       "my.company.registry":
#         endpoint:
#           - http://my.company.registry:5000
options:
#   k3d: # k3d runtime settings
#     wait: true # wait for cluster to be usable before returining; same as `--wait` (default: true)
#     timeout: "60s" # wait timeout before aborting; same as `--timeout 60s`
#     disableLoadbalancer: false # same as `--no-lb`
#     disableImageVolume: false # same as `--no-image-volume`
#     disableRollback: false # same as `--no-Rollback`
#     disableHostIPInjection: false # same as `--no-hostip`
#   k3s: # options passed on to K3s itself
#     extraServerArgs: # additional arguments passed to the `k3s server` command; same as `--k3s-server-arg`
#       - --tls-san=my.host.domain
#     extraAgentArgs: [] # addditional arguments passed to the `k3s agent` command; same as `--k3s-agent-arg`
  kubeconfig:
    updateDefaultKubeconfig: true # add new cluster to your default Kubeconfig; same as `--kubeconfig-update-default` (default: true)
    switchCurrentContext: true # also set current-context to the new cluster's context; same as `--kubeconfig-switch-context` (default: true)
#   runtime: # runtime (docker) specific options
#     gpuRequest: all # same as `--gpus all`
```

Aunque podemos especificar el nombre del clúster en el fichero de configuración, usaremos el fichero de configuración a modo de plantilla, proporcionando valores específicos desde la línea de comandos (podemos hacer un *override* de cualquier parámetro especificado en el fichero de configuración):

```bash
$ k3d cluster create stable-cluster --config config-1s1a.yaml
INFO[0000] Using config file config-1a1s.yaml           
INFO[0000] Prep: Network                                
INFO[0000] Created network 'k3d-stable-cluster'         
INFO[0000] Created volume 'k3d-stable-cluster-images'   
INFO[0001] Creating node 'k3d-stable-cluster-server-0'  
INFO[0001] Creating node 'k3d-stable-cluster-agent-0'   
INFO[0001] Creating LoadBalancer 'k3d-stable-cluster-serverlb' 
INFO[0001] Starting cluster 'stable-cluster'            
INFO[0001] Starting servers...                          
INFO[0001] Starting Node 'k3d-stable-cluster-server-0'  
INFO[0010] Starting agents...                           
INFO[0010] Starting Node 'k3d-stable-cluster-agent-0'   
INFO[0020] Starting helpers...                          
INFO[0020] Starting Node 'k3d-stable-cluster-serverlb'  
INFO[0021] (Optional) Trying to get IP of the docker host and inject it into the cluster as 'host.k3d.internal' for easy access 
INFO[0027] Successfully added host record to /etc/hosts in 3/3 nodes and to the CoreDNS ConfigMap 
INFO[0027] Cluster 'stable-cluster' created successfully! 
INFO[0027] --kubeconfig-update-default=false --> sets --kubeconfig-switch-context=false 
INFO[0027] You can now use it like this:                
kubectl config use-context k3d-stable-cluster
kubectl cluster-info
```

Podemos validar que se ha creado el clúster:

```bash
$ k3d cluster list
NAME             SERVERS   AGENTS   LOADBALANCER
dev-cluster      1/1       2/2      true
stable-cluster   1/1       1/1      true
```

Comprobamos que se ha cambiado el contexto activo:

```bash
$ kubectl config current-context
k3d-stable-cluster
```

Para cambiar el contexto e interaccionar con el clúster de desarrollo:

```bash
$ kubectl config get-contexts
CURRENT   NAME                 CLUSTER              AUTHINFO                   NAMESPACE
          k3d-dev-cluster      k3d-dev-cluster      admin@k3d-dev-cluster        
*         k3d-stable-cluster   k3d-stable-cluster   admin@k3d-stable-cluster
$ kubectl config use-context k3d-dev-cluster
Switched to context "k3d-dev-cluster".
$ kubectl config get-contexts
CURRENT   NAME                 CLUSTER              AUTHINFO                   NAMESPACE
*         k3d-dev-cluster      k3d-dev-cluster      admin@k3d-dev-cluster      
          k3d-stable-cluster   k3d-stable-cluster   admin@k3d-stable-cluster
```

## Referencias

* [Introduction to k3d: Run K3s in Docker](https://www.suse.com/c/introduction-k3d-run-k3s-docker-src/) en el Blog de SUSE (Thorsten Klein, 01/03/2021).
* [K3S + K3D = K8S : a new perfect match for dev and test](https://en.sokube.ch/post/k3s-k3d-k8s-a-new-perfect-match-for-dev-and-test)

[^dqlite]: En realidad *k3d* (v4.x) proporciona soporte para múltiples réplicas de SQLite mediante el uso de [Dqlite](https://dqlite.io/), una versión *distribuída* de SQLite que soporta *failovers* y HA desarrollada por Canonical. Revisa la documentación [Creating multi-server clusters](https://k3d.io/usage/multiserver/)
[^v4]: [Config File](https://k3d.io/usage/configfile/) en la documentación oficial de **k3d**.
[^required]: [Required Fields](https://k3d.io/usage/configfile/#required-fields) en la documentación oficial de **k3d**.
