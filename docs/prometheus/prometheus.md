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

## Referencias

- [How To Monitor Kubernetes With Prometheus](https://phoenixnap.com/kb/prometheus-kubernetes-monitoring), 24/02/2020.
