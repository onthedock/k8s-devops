# Prometheus

> **Versiones**
>
> - k3d: 3.4.0
> - Kubernetes: 1.19.4
> - Helm version: 3.4.2
> - Prometheus Helm Chart: 13.2.1
> - Prometheus: 2.24

## Instalación de Prometheus usando Helm Charts

La instalación de Prometheus usando Helm se realiza mediante una *chart* mantenida por la comunidad alojada en GitHub: [Prometheus Community Kubernetes Helm Charts](https://github.com/prometheus-community/helm-charts).

> La [*chart* para Prometheus](https://github.com/helm/charts/tree/master/stable/prometheus) en el repo de Helm está *deprecated* .

Como requerimiento para poder usar la *helm chart*, es necesario tener Helm instalado (en nuestro caso, ya lo está):

```yaml
$ helm version
version.BuildInfo{Version:"v3.4.2", GitCommit:"23dd3af5e19a02d4f4baa5b2f242645a1a3af629", GitTreeState:"clean", GoVersion:"go1.14.13"}
```

Añadimos el repositorio de la *chart* para Prometheus:

```bash
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
"prometheus-community" has been added to your repositories
```

Como indica la documentación de la *chart*, ya podemos usar `helm search repo prometheus-community` para ver las *charts* disponibles.

> Atención, la *chart* para `prometheus-community/prometheus-operator` está *deprecated*.

Para instalar Prometheus, seguimos las instrucciones de la *chart*: [`prometheus`](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus):

> Requiere Kubernetes 1.16+ y Helm 3+.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
helm repo update
```

Una ver actualizados los repositorios de Charts de Helm, lanzamos la instalación de Prometheus:

> OJO! Si no se especifica el *namespace*, Prometheus se despliega en el *namespace* `default`.

```bash
$ helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace
NAME: prometheus
LAST DEPLOYED: Sun Jan 17 13:12:21 2021
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.monitoring.svc.cluster.local


Get the Prometheus server URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace monitoring port-forward $POD_NAME 9090


The Prometheus alertmanager can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-alertmanager.monitoring.svc.cluster.local


Get the Alertmanager URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=prometheus,component=alertmanager" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace monitoring port-forward $POD_NAME 9093
#################################################################################
######   WARNING: Pod Security Policy has been moved to a global property.  #####
######            use .Values.podSecurityPolicy.enabled with pod-based      #####
######            annotations                                               #####
######            (e.g. .Values.nodeExporter.podSecurityPolicy.annotations) #####
#################################################################################


The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
prometheus-pushgateway.monitoring.svc.cluster.local


Get the PushGateway URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace monitoring -l "app=prometheus,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace monitoring port-forward $POD_NAME 9091

For more information on running Prometheus, visit:
https://prometheus.io/
```

Con la opción `--create-namespace` Helm crea el *namespace* sólo si no existe [^namespace].

Podemos revisar qué recursos se crear en el *namespace* `monitoring`:

```bash
$ kubectl get all -n monitoring
NAME                                                READY   STATUS    RESTARTS   AGE
pod/prometheus-node-exporter-9v8sq                  1/1     Running   0          3m51s
pod/prometheus-kube-state-metrics-95d956569-z9wck   1/1     Running   0          3m51s
pod/prometheus-pushgateway-5d6884b99-7zzpz          1/1     Running   0          3m51s
pod/prometheus-alertmanager-58b5b9d6d8-d9vnc        2/2     Running   0          3m51s
pod/prometheus-server-6b687c4b87-j97mr              2/2     Running   0          3m51s

NAME                                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/prometheus-node-exporter        ClusterIP   None            <none>        9100/TCP   3m51s
service/prometheus-server               ClusterIP   10.43.15.137    <none>        80/TCP     3m51s
service/prometheus-alertmanager         ClusterIP   10.43.190.169   <none>        80/TCP     3m51s
service/prometheus-pushgateway          ClusterIP   10.43.237.227   <none>        9091/TCP   3m51s
service/prometheus-kube-state-metrics   ClusterIP   10.43.225.40    <none>        8080/TCP   3m51s

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/prometheus-node-exporter   1         1         1       1            1           <none>          3m51s

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/prometheus-kube-state-metrics   1/1     1            1           3m51s
deployment.apps/prometheus-pushgateway          1/1     1            1           3m51s
deployment.apps/prometheus-alertmanager         1/1     1            1           3m51s
deployment.apps/prometheus-server               1/1     1            1           3m51s

NAME                                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/prometheus-kube-state-metrics-95d956569   1         1         1       3m51s
replicaset.apps/prometheus-pushgateway-5d6884b99          1         1         1       3m51s
replicaset.apps/prometheus-alertmanager-58b5b9d6d8        1         1         1       3m51s
replicaset.apps/prometheus-server-6b687c4b87              1         1         1       3m51s
```

Podemos validar que Prometheus está activo mediante `port-forward` al puerto 9090 y accediendo a `http://localhost:9090` a través del navegador:

```bash
$ kubectl -n monitoring get pods 
NAME                                            READY   STATUS    RESTARTS   AGE
prometheus-node-exporter-9v8sq                  1/1     Running   0          12m
prometheus-kube-state-metrics-95d956569-z9wck   1/1     Running   0          12m
prometheus-pushgateway-5d6884b99-7zzpz          1/1     Running   0          12m
prometheus-alertmanager-58b5b9d6d8-d9vnc        2/2     Running   0          12m
prometheus-server-6b687c4b87-j97mr              2/2     Running   0          12m
$ kubectl -n monitoring port-forward pod/prometheus-server-6b687c4b87-j97mr 9090
Forwarding from 127.0.0.1:9090 -> 9090
Forwarding from [::1]:9090 -> 9090

```

## Despliegue de Prometheus (sin Helm)

En esta sección usamos como referencia el artículo [How to Setup Prometheus Monitoring On Kubernetes Cluster](https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)

### *Namespace*

> En esta sección ya tenemos Prometheus desplegado (usando Helm) y Grafana, por lo que creamos un nuevo *namespace* llamado `monitor`.

El primer paso es crear un *namespace*;

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: monitor
```

### *ClusterRole*

El siguiente paso es definir los permisos de lectura a este *namespace* para que Prometheus puede obtener métricas de la API de Kubernetes.

> En el fichero creamos tanto el *ClusterRole* como el *ClusterRoleBinding*, que asigna los permisos definidos a la cuenta `default`. Si quisiéramos usar otra cuenta, deberíamos crearla primero. El *ClusterRoleBinding* asocia los permisos a una cuenta en un *namespace* concreto, por lo que debes ajustar el nombre del *namespace*.

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitor
```

Al aplicar este fichero, obtenemos:

```bash
$ kubectl apply -f prometheus.yaml 
namespace/monitor unchanged
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRole is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRole
clusterrole.rbac.authorization.k8s.io/prometheus created
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRoleBinding
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
```

Actualizamos el fichero de definición del *ClusterRole* y del *crb*:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitor  
```

Y ahora no tenemos ningún *warning*:

```bash
$ kubectl apply -f prometheus.yaml 
namespace/monitor unchanged
clusterrole.rbac.authorization.k8s.io/prometheus configured
clusterrolebinding.rbac.authorization.k8s.io/prometheus configured
```
## Referencias

- [How Prometheus Monitoring works | Prometheus Architecture explained](https://youtu.be/h4Sl21AKiDg) en TechWorld with Nana, 24/04/2020, YouTube.

- [Setup Prometheus Monitoring on Kubernetes using Helm and Prometheus Operator | Part 1](https://youtu.be/QoDqxm7ybLc) en TechWorld with Nana, 19/07/2020, YouTube.

- [Prometheus Monitoring - Steps to monitor third-party apps using Prometheus Exporter | Part 2](https://youtu.be/mLPg49b33sA) en TechWorld with Nana, 25/09/2020, YouTube.

[^namespace]: Referencia a la documentación de Helm del comando `install`: [helm install](https://helm.sh/docs/helm/helm_install/)
