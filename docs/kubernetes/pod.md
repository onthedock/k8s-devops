# Pod

Un Pod es la mínima unidad desplegable en un clúster de Kubernetes.

Un Pod contiene uno o más contenedores que comparten:

- almacenamiento
- recursos de red
- una especificación sobre cómo ejecutar contenedores

Todos los contenedores del Pod se despliegan en el mismo nodo y en el mismo *contexto*.

El contexto compartido de un Pod es un conjunto de espacios de nombres de Linux, cgroups así como otras características que proporcionan aislamiento a los contenedores.

Además de los contenedores de aplicación, un Pod puede contener **init containers** que se ejecutan durante el inicio del *pod*. También es posible inyectar **contenedores efímeros** para *debugging* (si lo permite el clúster).

## Usando Pods

En general no se recomienda crear Pods directamente; éstos son creados por otros recursos como Deployments o Jobs.

Un Pod está pensado para contener una instancia de una aplicación. Si es necesario escalar la aplicación horizontalmente (para proporcionar más recursos ejecutando más instancias), puedes usar múltiples Pods, uno para cada instancia. Esto es lo que se conoce como *replicación*. Estas réplicas son creadas y gestionadas como un grupo por su **controlador**.

Los contenedores de un Pod comparten recursos y dependencias, se comunican entre ellos y se coordinan cuando son *terminados*.
## Referencia

- [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) en la documentación oficial de Kubernetes