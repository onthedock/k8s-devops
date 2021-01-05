# Prometheus

[Prometheus](https://prometheus.io/) es un solución de monitorización *open-source* que proporciona métricas y un sistema de alertas.

## *Namespace* para la monitorización

Empezamos con la definición del objeto del *namespace* para Prometheus. En este *namespace* también desplegaremos *Graphana*, por lo que denominamos al *namespace* de forma genérica:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
    name: monitoring
```

Tras aplicar el fichero, tenemos el *namespace* `monitoring` creado:

```bash
$ kubectl apply -f prometheus.yaml 
namespace/monitoring created
```

## Permisos para Prometheus

Los espacios de nombres se han diseñado para limitar los permisos de los diferentes roles, por lo que si queremos obtener información de forma global en el clúster, debemos proporcionar a Prometheus acceso a todos los recursos en el clúster.

### Rol global (*clusterrole*)

Un fichero básico que proporciona acceso global al clúster es:

```yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
    name: prometheus
rules:
    - apiGroups: [""]
      resources:
        - nodes
        - services
        - endpoints
        - pods
      verbs:
        - get
        - list
        - watch
    - apiGroups:
        - extensions
      resources:
        - ingresses
      verbs:
        - get
        - list
        - watch
```

### *Service account*

Creamos una *service account* a la que aplicar el rol creado en el apartado anterior:

```yaml
---
kind: ServiceAccount
apiVersion: v1
metadata:
    name: prometheus
    namespace: monitoring
```

```bash
$ kubectl -n monitoring apply -f docs/prometheus/deploy/prometheus.yaml 
namespace/monitoring unchanged
clusterrole.rbac.authorization.k8s.io/prometheus unchanged
serviceaccount/prometheus created
```

Comprobamos que se ha creado correctamente:

```bash
$ kubectl -n monitoring get sa
NAME         SECRETS   AGE
default      1         25m
prometheus   1         3m19s
```

### *ClusterRoleBinding*

Aunque hemos creado el *ClusterRole* (que define los permisoso) y la *ServiceAccount*, no están relacionados de ninguna forma.

Para ello necesitamos un *ClusterRoleBinding*:

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
```

Aplicamos el fichero para crearlo:

```bash
$ kubectl -n monitoring apply -f docs/prometheus/deploy/prometheus.yaml 
namespace/monitoring unchanged
clusterrole.rbac.authorization.k8s.io/prometheus unchanged
serviceaccount/prometheus unchanged
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
```

Validamos que se ha creado correctamente:

```bash
$ kubectl describe clusterrolebinding prometheus
Name:         prometheus
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  prometheus
Subjects:
  Kind            Name        Namespace
  ----            ----        ---------
  ServiceAccount  prometheus  monitoring
```

Con estos permisos garantizamos que Prometheus tiene permisos sobre todo el clúster desde el *namespace* `monitoring`.

## Configuración vía *ConfigMap*

En este apartado se configura cómo debe Prometheus obtener información sobre el clúster (*scraping*), por lo que debe ajustarse a la situación de cada clúster.

### Reglas globales

> El artículo de la referencia divide la configuración de Prometheus en diferentes bloques en el artículo; en mi caso haré algo parecido, pero intentando mantener el *orden lógico* del fichero *configMap*.

```yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
    name: prometheus-config
data:
    prometheus.yaml: |
        global:
            scrape_interval: 30s # Tailor to your cluster's needs
...
```

### Modo de recogida de información

El servicio de descubrimiento expone los nodos que componen el clúster de Kubernetes. El *kubelet* se ejecuta en cada nodo y proporciona información relevante para la monitorización.

#### Obtención de datos del *kubelet*

```yaml
... (continued)
        scrape_configs:
            - job_name: 'kubelet'
              kubernetes_sd_configs:
                - role: node
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                insecure_skip_verify: true # Required with Minikube
...
```

#### Obtención de datos de **cAdvisor** (información a nivel de contenedor)

El *kubelet* sólo proporciona información acerca de sí mismo pero no de los contenedores. Para obtener información a nivel de contenedor, necesitamos usar un **exporter**. **cAdvisor** ya está incluido y sólo necesitamos indicar la ruta de donde obtener la información; esta ruta **metrics_path** es `/metrics/cadvisor` es todo lo que necesita Prometheus para obtener datos sobre los contenedores:

```yaml
... (continued)
            - job_name: 'cadvisor'
              kubernetes_sd_configs:
                  - role: node
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                insecure_skip_verify: true # Required with Minikube
              metrics_path: /metrics/cadvisor
...
```

#### Obtención de datos del *API Server*

Usaremos los *endpoints* para obtener información de la aplicación a través de llamadas a la API de Kubernetes:

```yaml
... (continued)
      - job_name: 'k8sapiserver'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true # Required with Minikube
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels:
            - __meta_kubernetes_namespace
            - __meta_kubernetes_service_name
            - __meta_kubernetes_enpdpoint_port_name
            action: keep
            regex: default;kubernetes;https
...
```

#### Obtención de datos de los *pods* (excepto de los *API Servers*)

Obtenemos información de todos los *pods* que respaldan los servicios de Kubernetes (excepto las métricas del *API server*):

```yaml
... (continued)
      - job_name: 'k8services'
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels:
            - __meta_kubernetes_namespace
            - __meta_kubernetes_service_name
            action: drop
            regex: default;kubernetes
          - source_labels:
            - __meta_kubernetes_namespace
            action: keep
            regex: default
          - source_labels:
            - __meta_kubernetes_service_name
            target_label: job
...
```

#### Obtención de datos de los *pods*

Descubre todos los puertos de los pods con el nombre *metrics* usando el nombre del contenedor como etiqueta para el *job*:

```yaml
... (continued)
    - job_name: 'k8spods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels:
            - __meta_kubernetes_pod_container_port_name
            action: keep
            regex: metrics
        - source_labels:
            - __meta_kubernetes_pod_container_name
            target_label: job
```

Una vez creadas las diferentes reglas en el *configMap*, lo creamos:

```bash
$ kubectl -n monitoring apply -f docs/prometheus/deploy/prometheus.yaml 
namespace/monitoring unchanged
clusterrole.rbac.authorization.k8s.io/prometheus unchanged
serviceaccount/prometheus unchanged
clusterrolebinding.rbac.authorization.k8s.io/prometheus unchanged
configmap/prometheus-config created
```

## Despliegue de Prometheus

Ahora que tenemos la configuración definida y guardada en un *configMap*, desplegamos Prometheus usando un *deployment*:

```yaml
---
kind: Deployment
apiVersion: apps/v1beta2
metadata:
  name: prometheus
spec:
  selector:
    matchLabels:
      app: prometheus
  replicas: 1
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:v2.23.0 # Latest stable release (the article uses 2.1.0)
          ports:
            - name: default
              containerPort: 9090
          volumeMounts:
            - name: prometheus-config
              mountPath: /etc/prometheus
      volumes:
        - name: prometheus-config
          configMap:
            name: prometheus-config
```

Pero tras desplegar el *deployment*, el *pod* tiene algún problema y no arranca:

```bash
$ kubectl -n monitoring get deploy
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
prometheus   0/1     1            0           5m23s
$ kubectl -n monitoring get pods
NAME                          READY   STATUS             RESTARTS   AGE
prometheus-57cb865687-qv8j8   0/1     CrashLoopBackOff   5          6m5s
$ kubectl -n monitoring describe pod prometheus-57cb865687-qv8j8
...
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  6m23s                 default-scheduler  Successfully assigned monitoring/prometheus-57cb865687-qv8j8 to k3d-devcluster-server-0
  Normal   Pulling    6m22s                 kubelet            Pulling image "prom/prometheus:v2.23.0"
  Normal   Pulled     6m4s                  kubelet            Successfully pulled image "prom/prometheus:v2.23.0" in 18.932546631s
  Normal   Pulled     4m31s (x4 over 6m2s)  kubelet            Container image "prom/prometheus:v2.23.0" already present on machine
  Normal   Created    4m31s (x5 over 6m3s)  kubelet            Created container prometheus
  Normal   Started    4m30s (x5 over 6m3s)  kubelet            Started container prometheus
  Warning  BackOff    72s (x24 over 6m1s)   kubelet            Back-off restarting failed container
```

:(

## Referencias

- [How To Monitor Kubernetes With Prometheus](https://phoenixnap.com/kb/prometheus-kubernetes-monitoring), 24/02/2020.
