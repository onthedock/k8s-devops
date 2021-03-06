# Grafana

> **Versiones**
>
> - k3d: 3.4.0
> - Kubernetes: 1.19.4
> - Grafana: 7.3.7
> - Traefik 1.7.19 (desplegado por defecto con k3d)

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

> Este despliegue usar un volumen de tipo [*emptyDir*](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir). En el futuro, quizás sea interesante cambiarlo por un volumen persistente.

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

A continuación, usamos `port-forward` para conectar con el *pod* de Grafana (en el puerto 3000, como vemos en `containerPort: 3000` en el fichero de definición del *deployment*):

```bash
$ kubectl -n monitoring port-forward grafana-6cb5cf45bf-lzmvj 3000:3000
Forwarding from 127.0.0.1:3000 -> 3000
Forwarding from [::1]:3000 -> 3000

```

A través del navegador podemos acceder a la página de *login* de Grafana a través de [http://localhost:3000](http://localhost:3000).

### Validación del *datasource* de Prometheus

Manteniendo activa la conexión al *pod* de Grafana mediante el *port-forward*, accedemos a Grafana con las credenciales por defecto (usuario `admin`, *password* `admin`).

Pulsando en el panel lateral, sobre el icono del engranaje (*Configuration*), seleccionamos *Data Sources*.

En el panel principal, debería mostrarse el *datasource* configurado a través del *configMap*.

Al pulsar sobre el *datasource* de Prometheus, se muestra la configuración del *datasource*. En la parte inferior, pulsa el botón *Save & Test* para validar que Grafana puede obtener datos de Prometheus.

## Servicio

En el artículo de la referencia se incluyen dos *annotations* en la definición del servicio; `prometheus.io/scrape: 'true'` y `prometheus.io/port: '3000'`. En [Kubernetes & Prometheus Scraping Configuration](https://www.weave.works/docs/cloud/latest/tasks/monitor/configuration-k8s/) se indica que la configuración por defecto de Prometheus es la de obtener métricas de todos los *pods*. Por tanto, no es necesario establecer `prometheus.io/scrape: 'true'`.

Lo mismo ocurre con `prometheus.io/port: '3000'`, que permite especificar el puerto a través del cual Prometheus obtiene las métricas, en el caso de que no se especifique el puerto en la definición del *pod*.

En nuestro caso vamos a acceder a Grafana a través de un *Ingress*, por lo que creamos un servicio de tipo *ClusterIP*:

```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector: 
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
```

## Publicar Grafana con un *Ingress*

El paso final en el despliegue de Grafana es *publicarlo* usando un *ingress* para que sea accesible desde el exterior del clúster.

Usamos como guía las instrucciones en la web de **k3d** [Exposing Services](https://k3d.io/usage/guides/exposing_services/):

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

> Al crear el *Ingres*, vemos que Grafana es accesible a través de la IP 172.18.0.2. En nuestro caso (usando **k3d**, "k3s en Docker"), esta IP corresponde a la IP del interfaz *bridge* en nuestro equipo.

```bash
$ kubectl get ingress -n monitoring
Warning: extensions/v1beta1 Ingress is deprecated in v1.14+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress
NAME      CLASS    HOSTS   ADDRESS      PORTS   AGE
grafana   <none>   *       172.18.0.2   80      5m22s
```

Tal y como hemos configurado el *ingress*, redirige todo el tráfico a Grafana, por lo que no podemos desplegar más aplicaciones en el clúster.

Una opción es modificar el campo `path` en el *ingress*, pero ésto nos obligaría a realizar algún tipo de *re-escritura* del *path* (o modificar la aplicación), por lo que usamos la opción de definir el `host`.

Añadimos el campo `.spec.rules.host` indicando el nombre `grafana.k3s.lab` (definido en el DNS), de manera que sólo el tráfico dirigido a `grafana.k3s.lab` acabe en el servicio de Grafana.

> En mi caso, "el DNS" es una entrada en el fichero `/etc/hosts` de mi equipo.

```yaml
---
# apiVersion: networking.k8s.io/v1beta1 # for k3s < v1.19
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: "grafana.k3s.lab"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000

```

## Referencias

- [How to Setup Grafana on Kubernetes](https://devopscube.com/setup-grafana-kubernetes/) por Bibin Wilson, 4/11/2019.
