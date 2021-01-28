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

### Configuración de Prometheus

En la sección anterior proporcionamos a Prometheus los permisos necesarios para obtener métricas desde la API de Kubernetes. El siguiente paso antes de desplegar la aplicación es indicar qué debe monitorizar; lo conseguimos mediante un *configMap*:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitor
data:
  prometheus.rules: |-
    groups:
    - name: devopscube demo alert
      rules:
      - alert: High Pod Memory
        expr: sum(container_memory_usage_bytes) > 1
        for: 1m
        labels:
          severity: slack
        annotations:
          summary: High Memory Usage
  prometheus.yml: |-
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "alertmanager.monitor.svc:9093"

    scrape_configs:
      - job_name: 'kubernetes-apiservers'

        kubernetes_sd_configs:
        - role: endpoints
        scheme: https

        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      - job_name: 'kubernetes-nodes'

        scheme: https

        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
        - role: node

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics

      
      - job_name: 'kubernetes-pods'

        kubernetes_sd_configs:
        - role: pod

        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
      
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']

      - job_name: 'kubernetes-cadvisor'

        scheme: https

        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

        kubernetes_sd_configs:
        - role: node

        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
      
      - job_name: 'kubernetes-service-endpoints'

        kubernetes_sd_configs:
        - role: endpoints

        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name
```

El fichero de configuración de Prometheus define los *targets*, es decir, los objetivos a monitorizar.

> De nuevo, revisa la configuración si has desplegado Prometheus en un *namespace* diferente a `monitoring`. Ten en cuenta que la URL de servicios internos como *Alert Manager* incluyen el nombre del *namespace*.

El fichero de configuración `prometheus.yaml` contine la definición de los *jobs* de obtención de las métricas de los *pods* y *servicios* desplegados en el clúster:

- `kubernetes-apiservers` Obtiene métricas del servidor de API de Kubernetes
- `kubernetes-nodes` Obtiene las métricas de los nodos del clúster
- `kubernetes-pods` Obtiene métricas si el *pod* contiene las anotaciones `prometheus.io/scrape` y `prometheus.io/port`
- `kubernetes-cadvisor` Obtiene las métricas de **cAdvisor**
- `kubernetes-service-endpoints` Obtiene las métricas de los servicios anotados con `prometheus.io/scrape` y `prometheus.io/port`

El fichero `prometheus.rules` contiene la definición y configuración de las reglas para **Alert Manager**.
## Referencias

- [How Prometheus Monitoring works | Prometheus Architecture explained](https://youtu.be/h4Sl21AKiDg) en TechWorld with Nana, 24/04/2020, YouTube.

- [Setup Prometheus Monitoring on Kubernetes using Helm and Prometheus Operator | Part 1](https://youtu.be/QoDqxm7ybLc) en TechWorld with Nana, 19/07/2020, YouTube.

- [Prometheus Monitoring - Steps to monitor third-party apps using Prometheus Exporter | Part 2](https://youtu.be/mLPg49b33sA) en TechWorld with Nana, 25/09/2020, YouTube.

[^namespace]: Referencia a la documentación de Helm del comando `install`: [helm install](https://helm.sh/docs/helm/helm_install/)
