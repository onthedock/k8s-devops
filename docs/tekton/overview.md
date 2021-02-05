# Tekton

[Tekton](https://tekton.dev) es un *framework* *opensource* que permite crear potentes sistemas de CI/CD. Proporciona diferentes herramientas y utilidades que componen el ecosistema completo de Tekton, como Tekton CLI, Tekton Catalog...

Tekton está disponible como *Custom Resource Definition (CRD)* en Kubernetes. Estos CRDs  definen los bloques con los que crear tus *pipelines*. Una vez instalado, Tekton Pipelines está disponible a través de la Kubernetes CLI (kubectl) y de llamadas a la API, como el resto de objetos en Kubernetes.

## Componentes de Tekton

Tekton consiste en los siguientes componentes:

- Tekton Pipelines es la base de Tekton. Define un conjunto de CRDs que funcionan como piezas de Lego a partir de las cuales crear las *pipelines*.
- Tekton Triggers permite instanciar *pipelines* como respuesta a eventos.
- Tekton CLI proporciona una herramienta de línea de comandos llamada `tkn`, construida a partir de la Kubernetes CLI que permite interactuar con Tekton.
- Tekton Dashboard es una interfaz gráfica web para mostrar Tekton Pipelines de forma gráfica (está *work in progress*)
- Tekton Catalog es un repositorio de bloques como *Tasks*, *Pipelines*, etc contribuidas por la comunidad.
- Tekton Hub es una interfaz gráfica para acceder al Tekton Catalog.
- Tekton Operator es un *operador* de Kubernetes que permite instalar, actualizar y eliminar proyectos de Tekton en el clúster de Kubernetes.

## Conceptos en Tekton

- `Task` define una serie ordenada de `Steps`, y cada `Step` invoca a una herramienta usando un conjunto de *inputs* y produce *outputs* (que a su vez pueden ser usados como *inputs* para el siguiente `Step`).
- `Pipeline`: define un conjunto de `Tasks` ordenadas que componen una `Pipeline` y del mismo modo que el conjunto de `Steps` en una `Task`, la salida de una `Task` puede ser usada como entrada de la siguiente `Task`.
- `TaskRun` instancia una `Task` específica con un conjunto de *inputs* que producen un conjunto de *outputs*. En otras palabras, una `Task` le indica a Tekton qué hacer, mientras que una `TaskRun` le dice sobre qué debe hacerlo, así como detalles adicionales sobre cómo debe hacerlo, por ejemplo, a partir de *build flags*.
- `PipelineRun` instancia una `Pipeline` específica para que ejecute una *Pipeline* con conjunto específico de entradas.

Cada `Task` se ejecuta como un Pod en Kubernetes. Por defecto, las `Tasks` en una `Pipeline` no comparten datos. Para compartir datos entre `Tasks`, hay que configurar de manera explícita cada `Task` de manera que su salida esté disponible como *input* para la siguiente `Task`.

## Referencias

- [Overview of Tekton](https://tekton.dev/docs/overview/)
