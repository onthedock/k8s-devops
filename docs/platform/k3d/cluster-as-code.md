# Creación del clúster usando un fichero de configuración

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

[^v4]: [Config File](https://k3d.io/v5.4.9/usage/configfile/) en la documentación oficial de **k3d**.
[^required]: [Required Fields](https://k3d.io/v5.4.9/usage/configfile/#required-fields) en la documentación oficial de **k3d**.
