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
