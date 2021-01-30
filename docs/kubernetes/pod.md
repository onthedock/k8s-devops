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

## Plantillas de Pods

Los controladores en Kubernetes crean y gestionan objetos por tí que ejecutan las *workloads* en Pods. Los controladores generan los Pods a partir de la `PodTemplate` contenida en el fichero de definición del objeto (por ejemplo, de un *Job*). Esta plantilla forma parte del estado deseado de las cargas de trabajo a desplegar en el clúster.

En el siguiente ejemplo, la plantilla para crear un Pod se encuentra en la sección `.spec.template`:

```yaml
---
kind: Job
apiVersion: batch/v1
metadata:
  name: hello-world
spec:
  template:
    # La plantilla del Pod empieza aquí
    spec:
      containers:
        - name: hello-world
          image: busybox
          command:
            [
              "sh",
              "-c",
              'echo "Hello world from a Kubernetes Job" && sleep 30'
            ]
          restartPolicy: OnFailure
```

Modificar la plantilla de un Pod no tiene ningún efecto en los Pods que ya han sido desplegados.
Para aplicar los cambios, es necesario crear nuevos recursos a partir de la plantilla actualizada.

Cada tipo de recurso implementa sus propias reglas para gestionar los cambios en la plantilla del Pod.

## Recursos compartidos y comunicación

### Almacenamiento

Un Pod puede especificar un conjunto de *volúmenes* de almacenamiento. Todos los contenedores en el Pod puede acceder a los volúmenes compartidos, lo que permite compartir datos entre los contenedores de un mismo Pod.

Los volúmenes también proporcionan almacenamiento para persistir datos en caso de que alguno de los contenedores del Pod tenga que ser reiniciado.

### Red en un Pod

Cada Pod tiene asiganda una dirección IP única. Cada contenedor en el Pod comparte el *network namespace*, incluída la dirección IP y los puertos. Dentro de un Pod, los contenedores que pertenecen al mismo Pod pueden comunicarse entre ellos usando `localhost`. Cuando los contenedores en un Pod se comunican con entidades exteriores, deben coordinarse en cómo se usan la red compartida (como los puertos).

Los contenedores dentro de un Pod ven el *hostname* de sistema como el especificado en el campo `name` del Pod.

## Modo privilegiado para los contenedores

Se puede habilitar el *modo privilegiado* ara cualquier contenedor usando el *flag* `privileged` en el *security context* de la sección `spec` de la definición del contenedor. Este modo es útil para contenedores que tienen que acceder a las capacidades administrativas del sistema operativo, como manipular el *stack* de red o acceder a los dispositivos de hardware.

En este modo un contenedor obtiene prácticamente los mismos privilegios que los procesos que se ejecutan fuera del contenedor.

## Pods estáticos

Los *pods estáticos* son gestionados directamente por el **kubelet** en cada nodo, sin que el servidor de la API de Kubernetes los observe.

Los pods estáticos están siempre asociados a un **kubelet** en un nodo. El uso principal de los pods estáticos es la ejecución de un *self-hosted control plane*; en otras palabras, el **kubelet** supervisa los elementos individuales del *control plane*.

El **kubelet** automáticamente intenta crear un *mirror pod* en el servidor de API de Kubernetes para cada pod estático. Esto significa que los Pods que se ejecutan en un nodo son visibles para en el servidor de API, pero no se pueden gestionar desde allí.

## Ejemplo - **Jumpod**

Como los pods tienen IPs que sólo son visibles desde "dentro" del clúster, una manera sencilla de realizar pruebas es desde un pod desplegado a modo de "jumpserver"; de ahí el nombre: *jump+pod*.

El pod es sencillamente un pod con *busybox*:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: jumpod
spec:
  containers:
  - name: busybox
    image: busybox
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: OnFailure
```

## Referencia

- [Pod](https://kubernetes.io/docs/concepts/workloads/pods/) en la documentación oficial de Kubernetes
