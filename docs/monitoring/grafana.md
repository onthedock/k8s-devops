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

## Deployment de Grafana

> En la  configuración del artículo de referencia, se usaba la imagen `latest`; en nuestro caso usamos la última versión de Grafana disponible en este momento, la 7.3.7.

```yaml
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      name: grafana
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:7.3.7
        ports:
        - name: grafana
          containerPort: 3000
        resources:
          limits:
            memory: "2Gi"
            cpu: "1000m"
          requests: 
            memory: "1Gi"
            cpu: "500m"
        volumeMounts:
          - mountPath: /var/lib/grafana
            name: grafana-storage
          - mountPath: /etc/grafana/provisioning/datasources
            name: grafana-datasources
            readOnly: false
      volumes:
        - name: grafana-storage
          emptyDir: {}
        - name: grafana-datasources
          configMap:
              defaultMode: 420
              name: grafana-datasources
```

### Validación del despliegue

Podemos validar que Grafana se ha desplegado correctamente usando `port-foward`.

En primer lugar, obtenemos el nombre del pod generado:

```bash
$ kubectl get pods -n monitoring
NAME                                            READY   STATUS    RESTARTS   AGE
prometheus-node-exporter-9v8sq                  1/1     Running   1          2d7h
prometheus-pushgateway-5d6884b99-7zzpz          1/1     Running   1          2d7h
prometheus-alertmanager-58b5b9d6d8-d9vnc        2/2     Running   2          2d7h
prometheus-server-6b687c4b87-j97mr              2/2     Running   2          2d7h
prometheus-kube-state-metrics-95d956569-z9wck   1/1     Running   2          2d7h
grafana-6cb5cf45bf-lzmvj                        1/1     Running   0          16m
```

A continuación, usamdos `port-forward` para conectar con el *pod* de Grafana (en el puerto 3000, como vemos en `containerPort: 3000` en el fichero de definición del *deployment*):

```bash
$ kubectl -n monitoring port-forward grafana-6cb5cf45bf-lzmvj 3000:3000
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000

```

A través del navegador podemos acceder a la página de *login* de Grafana a través de [http://localhost:3000](http://localhost:3000).

## Referencias

- [How to Setup Grafana on Kubernetes](https://devopscube.com/setup-grafana-kubernetes/) por Bibin Wilson, 4/11/2019.
