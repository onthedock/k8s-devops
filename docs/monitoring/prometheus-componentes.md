# Recursos desplegados junto a Prometheus

Hemos desplegado Prometheus usando una *Helm chart*; esta *chart* despliega diferentes componentes.

Empezamos inspeccionando los recursos desplegados en el *namespace* `monitoring` con:

```bash
$ kubectl -n monitoring get all
NAME                                                READY   STATUS    RESTARTS   AGE
pod/prometheus-node-exporter-9v8sq                  1/1     Running   0          7h51m
pod/prometheus-kube-state-metrics-95d956569-z9wck   1/1     Running   0          7h51m
pod/prometheus-pushgateway-5d6884b99-7zzpz          1/1     Running   0          7h51m
pod/prometheus-alertmanager-58b5b9d6d8-d9vnc        2/2     Running   0          7h51m
pod/prometheus-server-6b687c4b87-j97mr              2/2     Running   0          7h51m

NAME                                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/prometheus-node-exporter        ClusterIP   None            <none>        9100/TCP   7h51m
service/prometheus-server               ClusterIP   10.43.15.137    <none>        80/TCP     7h51m
service/prometheus-alertmanager         ClusterIP   10.43.190.169   <none>        80/TCP     7h51m
service/prometheus-pushgateway          ClusterIP   10.43.237.227   <none>        9091/TCP   7h51m
service/prometheus-kube-state-metrics   ClusterIP   10.43.225.40    <none>        8080/TCP   7h51m

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/prometheus-node-exporter   1         1         1       1            1           <none>          7h51m

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/prometheus-kube-state-metrics   1/1     1            1           7h51m
deployment.apps/prometheus-pushgateway          1/1     1            1           7h51m
deployment.apps/prometheus-alertmanager         1/1     1            1           7h51m
deployment.apps/prometheus-server               1/1     1            1           7h51m

NAME                                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/prometheus-kube-state-metrics-95d956569   1         1         1       7h51m
replicaset.apps/prometheus-pushgateway-5d6884b99          1         1         1       7h51m
replicaset.apps/prometheus-alertmanager-58b5b9d6d8        1         1         1       7h51m
replicaset.apps/prometheus-server-6b687c4b87              1         1         1       7h51m
```

## Componentes desplegados

Como vemos, tenemos cinco componentes desplegados:

* *node-exporter* es un *exporter* de Prometheus para las métricas de los nodos del clúster. El  *node exporter* se encarga de proporcionar las métricas relativas a los nodos del clúster en el formato requerido por Prometheus en el *endpoint* `/metrics`. El *node-exporter* se despliega como un *daemon-set* de manera que haya una réplica en cada nodo *worker*.
* *kube-state-metrics* se encarga de obtener las métricas de la API de Kubernetes.
* *push-gateway* es un elemento de la arquitectura de Prometheus que permite recoger métricas de *jobs* y otros procesos de corta duración. El *job* en este caso puede enviar usando *push* las métricas al *gateway* en el momento que se ejecuta. El *push-gateway* almacena las métricas hasta que son recogidas por el proceso de *scraping* de Prometheus.
* *alertmanager* proporciona la funcionalidad para enviar alertas cuando alguna de las métricas definidas supera un determinado umbral.
* *server* este es el servidor de Prometheus en sí.

Como vemos en el apartado de los servicios, todos son del tipo `ClusterIP`, por lo que los componentes sólo son accesibles internamente dentro del clúster.

## Otros recursos creados

Además de los recursos listados mediante `kubectl get all`, tenemos dos *configMap* y *tokens* asociados a las *serviceAccount* de los diferentes componentes.

### *configMap*s

#### *configMap* `prometheus-server`

Revisando el contenido del *configMap* `cm/prometheus-server` mediante `kubectl -n monitoring describe cm/prometheus-server` vemos que contiene el fichero de configuración de Prometheus:

```yaml
Name:         prometheus-server
Namespace:    monitoring
Labels:       app=prometheus
              app.kubernetes.io/managed-by=Helm
              chart=prometheus-13.2.1
              component=server
              heritage=Helm
              release=prometheus
Annotations:  meta.helm.sh/release-name: prometheus
              meta.helm.sh/release-namespace: monitoring

Data
====
alerting_rules.yml:
----
{}

alerts:
----
{}

prometheus.yml:
----
global:
  evaluation_interval: 1m
  scrape_interval: 1m
  scrape_timeout: 10s
rule_files:
- /etc/config/recording_rules.yml
- /etc/config/alerting_rules.yml
- /etc/config/rules
- /etc/config/alerts
scrape_configs:
- job_name: prometheus
  static_configs:
  - targets:
    - localhost:9090
...

recording_rules.yml:
----
{}

rules:
----
{}

Events:  <none>
```

Este fichero contiene información global sobre la frecuencia de *scraping* de métricas de los *targets* (por defecto).
A continuación tenemos la ubicación de los ficheros de reglas (y alertas), seguido por la configuración de los diferentes *jobs* de obtención de métricas (para cada *target*).

Revisando los *jobs* podemos hacernos una idea de los diferentes *targets* incluidos en el despliegue por defecto vía Helm de Prometheus: `prometheus`, `kubernetes-apiservers`, `kubernetes-nodes`, etc...

Puedes consultar los detalles del fichero de [configuración de Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) en la web de la documentación oficial de Prometheus.

#### *configMap* `prometheus-alertmanager`

También podemos examinar el *configMap* que contiene la configuración de **Alert Manager**.

```yaml
Name:         prometheus-alertmanager
Namespace:    monitoring
Labels:       app=prometheus
              app.kubernetes.io/managed-by=Helm
              chart=prometheus-13.2.1
              component=alertmanager
              heritage=Helm
              release=prometheus
Annotations:  meta.helm.sh/release-name: prometheus
              meta.helm.sh/release-namespace: monitoring

Data
====
alertmanager.yml:
----
global: {}
receivers:
- name: default-receiver
route:
  group_interval: 5m
  group_wait: 10s
  receiver: default-receiver
  repeat_interval: 3h

Events:  <none>
```
