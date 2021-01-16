# Monitorización con el operador de Prometheus

Referencia: [Introduction to the Prometheus Operator on Kubernetes](https://youtu.be/LQpmeb7idt8) por Marcel Dempers en YouTube, 25/12/2019.

La manera tradicional de desplegar Prometheus es crear un *namespace*, desplegar Prometheus mediante un *deployment*, que desplega un *pod* de Prometheus (porque especificamos `1` como número de réplicas).

Prometheus se configura a través de un *configMap* en el que se *apunta* a todos los recursos que queremos monitorizar. Esto significa que el fichero de configuración de Prometheus crece rápidamente y de forma monolítica. Esto lleva a que el pod de monitorización de Prometheus requiera una gran cantidad de recursos para poder realizar el monitorizado de todos los recursos en los que estamos interesados, llegando a convertirse en un *cuello de botella*.

Sin embargo, Prometheus se diseñó como una herramienta de monitorización distribuida, por lo que no sería descabellado incluso desplegar un Prometheus por *namespace*, o quizás uno para monitorizar los recursos del clúster y otro para los microservicios desplegados, etc...

El problema en este caso es la gestión de los múltiples ficheros de configuración de todas las instancias de Prometheus.

## Prometheus Operator

Aquí es donde aparece el **operador* de Prometheus, que se encarga de gestionar los *configMaps* de las diferentes instancias de Prometheus desplegadas en el clúster.

Al desplegar el operador de Prometheus, se generan en el clúster un *CRD* (*custom resource definitions*) de tipo `Prometheus`.

De esta forma, cuando creamos un *namespace*, podemos indicar que queremos una instancia de Prometheus y el operador se encarga de desplegar un *service account*, la instancia de Prometheus, etc. En este caso, en vez de configurar los *endpoints* que queremos monitorizar unos determinados servicios (por ejemplo, la API de Kubernetes, etc)

Otro componente que se introduce es el *Service Monitor*; definimos un *service monitor* para cada grupo de servicios que queremos monitorizar. Estos grupos se definen usando los selectores típicos de Kubernetes, mediante etiquetas para identifican los servicios monitorizados por el *service monitor*.

De esta forma, la configuración de Prometheus consiste en identificar de qué *service monitors* debe obtener información (usando *selectors* basados en etiquetas) que a su vez seleccionan los servicios a monitorizar (también usando etiquetas).

Así, cuando desplegamos un microservicio, podemos etiquetarlo para indicar que debe ser monitorizado por un *service monitor* y por una determinada instancia de Prometheus que se va a encargar de monitorizarlo. De esta forma podemos gestionar la monitorización de un gran número de microservicios de forma sencilla.

## Despliegue

Código para Kubernetes 1.18.4 en Referencia: [Github](https://github.com/marcel-dempers/docker-development-youtube-series/tree/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator) por Marcel Dempers. El código está basado en la documentación sobre el [operador de Prometheus](https://coreos.com/operators/prometheus/docs/latest/user-guides/getting-started.html) en la web de CoreOS.

El repositorio sigue activo en GitHub: [prometheus-operator/prometheus-operator](https://github.com/prometheus-operator/prometheus-operator).

> El autor, Marcel Dempers dice que no le gustan las *Helm Charts* porque tienen a estar *over engineered* y que la guía de instalación le permite conocer qué es lo que despliega y desplegar únicamente lo que es necesario (por lo que esta guía sólo contiene los YAMLs mínimos para que Prometheus funcione).

### *Namespace* `monitoring` y resto de recursos

En primer lugar, creamos el *namespace* `monitoring`; si usamos un *namespace* diferente, tenemos que modificarlo en el fichero de definición de los *Role Binding*.

Creamos el fichero de definición del *namespace* y lo creamos:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: monitoring
```

A continuación aplica todos los ficheros YAML de la carpeta [`prometheus-operator`](https://github.com/marcel-dempers/docker-development-youtube-series/tree/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator) del repositorio de GitHub.

#### *ClusterRoleBinding*

```yaml
---
# https://github.com/marcel-dempers/docker-development-youtube-series/blob/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator/cluster-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: controller         # No aparece en la documentación de CoreOS
    app.kubernetes.io/name: prometheus-operator     # No aparece en la documentación de CoreOS
    app.kubernetes.io/version: v0.40.0              # No aparece en la documentación de CoreOS
  name: prometheus-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-operator
subjects:
- kind: ServiceAccount
  name: prometheus-operator
  namespace: monitoring
```

#### *ClusterRole*

```yaml
---
# https://github.com/marcel-dempers/docker-development-youtube-series/blob/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator/cluster-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: controller         # No aparece en la documentación de CoreOS
    app.kubernetes.io/name: prometheus-operator     # No aparece en la documentación de CoreOS
    app.kubernetes.io/version: v0.40.0              # No aparece en la documentación de CoreOS
  name: prometheus-operator
rules:
- apiGroups:
  - monitoring.coreos.com
  resources:
  - alertmanagers
  - alertmanagers/finalizers
  - prometheuses
  - prometheuses/finalizers
  - thanosrulers
  - thanosrulers/finalizers
  - servicemonitors
  - podmonitors
  - prometheusrules
  verbs:
  - '*'
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
  - delete
- apiGroups:
  - ""
  resources:
  - services
  - services/finalizers
  - endpoints
  verbs:
  - get
  - create
  - update
  - delete
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - authentication.k8s.io
  resources:
  - tokenreviews
  verbs:
  - create
- apiGroups:
  - authorization.k8s.io
  resources:
  - subjectaccessreviews
  verbs:
  - create
```

#### *ServiceAccount*

```yaml
---
# https://github.com/marcel-dempers/docker-development-youtube-series/blob/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller       # No aparece en la documentación de CoreOS
    app.kubernetes.io/name: prometheus-operator   # No aparece en la documentación de CoreOS
    app.kubernetes.io/version: v0.40.0            # No aparece en la documentación de CoreOS
  name: prometheus-operator
```

#### *Deployment*

```yaml
---
# https://github.com/marcel-dempers/docker-development-youtube-series/blob/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-operator/deployment.yaml
apiVersion: apps/v1                    # En la documentación de CoreOs extension/v1beta1 (más antigua)
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: prometheus-operator
    app.kubernetes.io/version: v0.40.0
  name: prometheus-operator
spec:
  replicas: 1
    selector:
      matchLabels:
        app.kubernetes.io/component: controller
        app.kubernetes.io/name: prometheus-operator
    template:
      metadata:
        labels:
          app.kubernetes.io/component: controller
          app.kubernetes.io/name: prometheus-operator
          app.kubernetes.io/version: v0.40.0
      spec:
        containers:
        - args:
          - --kubelet-service=kube-system/kubelet
          - --logtostderr=true
          - --config-reloader-image=jimmidyson/configmap-reload:v0.3.0
          - --prometheus-config-reloader=quay.io/coreos/prometheus-config-reloader:v0.40.0
          image: quay.io/coreos/prometheus-operator:v0.40.0
          name: prometheus-operator
          ports:
          - containerPort: 8080
            name: http
          # resources:
          #   limits:
          #     cpu: 200m
          #     memory: 200Mi
          #   requests:
          #     cpu: 100m
          #     memory: 100Mi
          securityContext:
            allowPrivilegeEscalation: false
        - args:
          - --logtostderr
          - --secure-listen-address=:8443
          - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
          - --upstream=http://127.0.0.1:8080/
          image: quay.io/coreos/kube-rbac-proxy:v0.4.1
          name: kube-rbac-proxy
          ports:
          - containerPort: 8443
            name: https
          securityContext:
            runAsUser: 65534
        nodeSelector:
          beta.kubernetes.io/os: linux
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
        serviceAccountName: prometheus-operator
```

Aplicamos el fichero de definición del operador de Prometheus, y tras unos instantes, comprobamos que el *pod* del operador se encuentra activo y corriendo con normalidad:

```bash
$ kubectl get pods -n monitoring
NAME                                  READY   STATUS    RESTARTS   AGE
prometheus-operator-f546c795d-t96cn   2/2     Running   3          2d23h
```

Una vez tenemos el operador desplegado, podemos decidir cómo queremos organizar las diferentes instancias de Prometheus en el clúster: una por equipo y una para monitorizar el clúster, un Prometheus específico para la API de Kuberntes, etc...

Podemos usar *node affinity* para desplegar Prometheus en nodos específicos, por ejemplo, ya que puede llegar a ser una aplicación con grandes necesidades de memoria y nos puede interesar "aislarlo" en nodos específicos, etc.

Si queremos desplegar un Prometheus *stand-alone*, lo que haríamos es crear un CR de tipo Prometheus, a desplegar en el *namespace* de destino. También tendríamos que desplegar un *service monitor*, indicando de qué *namespace* queremos obtener métricas, definiendo un selector para identificar qué queremos obtener y cómo. Para ello, nuestra aplicación debe exponer las métricas en los endpoints indicados y estar etiquetada convenientemente para que Prometheus pueda identificarla aplicación... Como en mi caso no tengo la aplicación de demo desplegada en el clúster, no tiene mucho sentido seguir en esta línea.

Revisaré si en otros vídeos del autor se indica cómo desplegar Prometheus para monitorizar el propio clúster de Kubernetes (API server, etc) y así obtener datos sin necesidad de desplegar aplicaciones de test.

## Node-exporter

Queremos monitorizar CPU, RAM, etc y otras métricas de los nodos Linux que forman parte del clúster.

Tenemos el operador de Prometheus desplegado en el clúster y vamos a desplegar una instancia en el *namespace* `monitoring`. Vamos a desplegar un *DaemonSet* llamado *node-exporter*, de manera que se despliega un pod por nodo del clúster. Este *pod* recoge las métricas de los nodos (sin usar la API de Kubernetes).

El siguiente paso es enlazar Prometheuse con node-exporter. Para ello creamos un *service monitori* que es lo que obtendrá las métricas desde los pods de *node-exporter*.

En primer lugar, desplegamos el operador de Prometheus (cosa que ya hemos descrito más arriba).

Una vez desplegado, tenemos a nuestra disposición dos nuevos CRDs de tipo `Prometheus` y `ServiceMonitor`.

> El código de esta sección se encuentra en [.../1.18.4/prometheus-cluster-monitoring/](https://github.com/marcel-dempers/docker-development-youtube-series/tree/master/monitoring/prometheus/kubernetes/1.18.4/prometheus-cluster-monitoring)

El autor aplica toda la carpeta:

> La creación de los objetos definidos por CRDs del operador de Prometheuse falla. La API de Kubernetes no los reconoce; mediante `kubectl api-resources` comprobamos que no se han creado al desplegar el operador de Prometheus.
