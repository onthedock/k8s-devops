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

## Referencias

- [How To Monitor Kubernetes With Prometheus](https://phoenixnap.com/kb/prometheus-kubernetes-monitoring), 24/02/2020.
