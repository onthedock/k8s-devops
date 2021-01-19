# Grafana

Grafana es una herramienta de código abierto para la visualización de *dashboards*. Los datos mostrados provienen de fuentes de datos como Prometheus, AWS CloudWatch, etc.

Este tutorial explica cómo configurar Grafana en un clúster de Kubernetes. Puedes crear *dashboards* para las métricas de Kubernetes a través de Prometheus.

## Configurar Prometheus como fuente de datos

El nombre de la URL en la que podemos conectar con Prometheus se compone del nombre del servicio con el que está desplegado Prometheus, seguido del nombre del *namespace* en el puerto en el que es accesible el servicio.

```bash
$ kubectl get svc -n monitoring
NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
prometheus-node-exporter        ClusterIP   None            <none>        9100/TCP   2d6h
prometheus-server               ClusterIP   10.43.15.137    <none>        80/TCP     2d6h
prometheus-alertmanager         ClusterIP   10.43.190.169   <none>        80/TCP     2d6h
prometheus-pushgateway          ClusterIP   10.43.237.227   <none>        9091/TCP   2d6h
prometheus-kube-state-metrics   ClusterIP   10.43.225.40    <none>        8080/TCP   2d6h
```

Como vemos en la salida del comando, el servicio expone *prometheus-server* internamente en el clúster en el puerto 80.

Creamos un *configMap* en el *namespace* `monitoring`:

```yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |-
    {
        "apiVersion": 1,
        "datasources": [
            {
               "access":"proxy",
                "editable": true,
                "name": "prometheus",
                "orgId": 1,
                "type": "prometheus",
                "url": "http://prometheus-server.monitoring.svc:80",
                "version": 1
            }
        ]
    }
```
## Referencias

- [How to Setup Grafana on Kubernetes](https://devopscube.com/setup-grafana-kubernetes/) por Bibin Wilson, 4/11/2019.
