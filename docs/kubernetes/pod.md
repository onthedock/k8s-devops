# Pod

Un Pod es la mínima unidad desplegable en un clúster de Kubernetes.

Un Pod contiene uno o más contenedores que comparten:

- almacenamiento
- recursos de red
- una especificación sobre cómo ejecutar contenedores

Todos los contenedores del Pod se despliegan en el mismo nodo y en el mismo *contexto*.

El contexto compartido de un Pod es un conjunto de espacios de nombres de Linux, cgroups así como otras características que proporcionan aislamiento a los contenedores.

Además de los contenedores de aplicación, un Pod puede contener **init containers** que se ejecutan durante el inicio del *pod*. También es posible inyectar **contenedores efímeros** para *debugging* (si lo permite el clúster).
## Referencia

- [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) en la documentación oficial de Kubernetes