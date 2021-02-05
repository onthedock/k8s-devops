# CI/CD con Tekton

> Las `Tasks` y otros objetos de Tekton están asociados a un *namespace*.  
> Cada equipo puede crear `Tasks` en su propio *namespace*, por lo que he creado el *namespace: cicd* para la ejecución de los ejemplos de esta sección.

## Tareas

En Tekton cada operación en un flujo de CI/CD es un `Step`, que se ejecuta en un contenedor a partir de la imagen que se indice. Los `Steps` se organizan en `Tasks`, que se ejecutan como un *pod* en Kubernetes.

Para crear una `Task`, creamos un objeto de Kubernetes de tipo `Task` usando la API de Tekton, a partir de un fichero de definición en YAML.

La siguiente `Task` tiene un único `Step` que imprime `Hello World!` usando la imagen de Alpine:

```yaml
kind: Task
apiVersion: tekton.dev/v1beta1
metadata:
  name: hello
spec:
  steps:
    - name: hello
      image: alpine:3.13
      command:
        - echo
      args:
        - "Hello World!"
```

Para crear la `Task`, usamos `kubectl` como para cualquier otro objeto en Kubernetes:

```bash
kubectl -n cicd apply -f hello-task.yaml
```

Para ejecutar esta tarea con Tekton, hay que crear una `TaskRun` que es el objeto de Kubernetes que proporciona información en tiempo de ejecución a la `Task`.

Para ver un ejemplo de este tipo de objeto, podemos usar la opción `--dry-run` de la herramienta `tkn`:

```bash
$ tkn task start hello -n cicd --dry-run
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  creationTimestamp: null
  generateName: hello-run-
  namespace: cicd
spec:
  resources: {}
  serviceAccountName: ""
  taskRef:
    name: hello
status:
  podName: ""
```

Para ejecutar la `Task` `hello` podemos usar `tkn` o crear un objeto `TaskRun` (a partir de la salida del comando anterior, por ejemplo) y aplicarlo mediante `kubectl apply -f`:

```bash
# Usando tkn
tkn task start hello -n cicd
# Usando kubectl
kubectl -n cicd apply -f hello-taskrun.yaml
```

Usando `tkn`:

```bash
$ tkn -n cicd task start hello
TaskRun started: hello-run-fpjwk

In order to track the TaskRun progress run:
tkn taskrun logs hello-run-fpjwk -f -n cicd
```

Y siguiendo las instrucciones que proporciona la salida del comando, usamos `tkn taskrun logs` para revisar el estado de ejecución de la tarea:

```bash
$ tkn taskrun logs hello-run-fpjwk -f -n cicd
[hello] Hello world!
```

Como las `Tasks` se ejecutan en forma de *pods*, podemos obtener el mismo resultado consultando los logs del contenedor indicado:

```bash
$ kubectl get pods -n cicd 
NAME                        READY   STATUS      RESTARTS   AGE
hello-run-fpjwk-pod-x2jpw   0/1     Completed   0          7m44s
$ kubectl logs hello-run-fpjwk-pod-x2jpw -n cicd 
Hello world!
```

## Tareas con parámetros

La tarea definida siempre muestra el mismo mensaje; podemos definir `Tasks` con parámetros y proporcionar el valor de los parámetros en tiempo de ejecución en la `TaskRun`.

Cada parámetro tiene un tipo, que por ahora sólo puede ser `string` (por defecto) o `array`.

Vamos a transformar la tarea anterior de manera que acepte un parámetro, de manera que muestre por consola `Hello` seguido del parámetro especificado.

```yaml
---
kind: Task
apiVersion: tekton.dev/v1beta1
metadata:
  name: greeter
spec:
  params:
    - name: subject
      type: string
  steps:
    - name: greeter
      image: alpine:3.13
      command:
        - echo
      args:
        - "Hello"
        - "$(params.subject)"
```

Aplicamos el fichero de definición de la tarea:

```bash
$ kubectl -n cicd apply -f docs/tekton/deploy/greeter-task.yaml 
task.tekton.dev/greeter created
```

Ahora, para ejecutar la tarea, usaremos herramienta de la línea de comando `tkn`:

```bash
$ tkn task start greeter -n cicd start
? Value for param `subject` of type `string`? Manolo
TaskRun started: greeter-run-bh6r9

In order to track the TaskRun progress run:
tkn taskrun logs greeter-run-bh6r9 -f -n cicd

$ tkn taskrun logs greeter-run-bh6r9 -f -n cicd
[greeter] Hello  Manolo
```

Los parámetros se consideran obligatorios por defecto; si no se especifican los parámetros requeridos por la `Task`, la ejecución se detiene hasta que se proporcionan.

Los parámetros se especifican en `tkn` como `-p key=value` (para un parámetro de tipo `string`) o como `-p key=value1,value2` (para los de tipo `array`).

```bash
$ tkn task start greeter -p subject="Anthony Machine" -n cicd
TaskRun started: greeter-run-xd5v5

In order to track the TaskRun progress run:
tkn taskrun logs greeter-run-xd5v5 -f -n cicd

$ tkn taskrun logs greeter-run-xd5v5 -f -n cicd
[greeter] Hello Anthony Machine
```

Lo habitual es definir estos valores en un fichero de definición de un objeto `TaskRun`.

> En los objetos `TaskRun`, en vez de especificar un *nombre* en `metadata.name`, se especifica un patrón a partir del cual generar el nombre de las diferentes ejecuciones del `TaskRun`: `metadata.generateName`. Por ejemplo, `greeter-run-` de manera que cada ejecución toma un nombre como `greeter-run-bh6r9`, `greeter-run-xd5v5`, etc.
>
> El nombre de los *pods* en los que se ejecutan las `Tasks` también se genera a partir de este patrón: `greeter-run-bh6r9-pod-9w8db`, `greeter-run-xd5v5-pod-5djkc`, etc.

```yaml
---
kind: TaskRun
apiVersion: tekton.dev/v1alpha1
metadata:
  generateName: greeter-taskrun-federico-
spec:
  params:
    - name: subject
      value: "Federico Mercurio"
  taskRef:
    kind: Task
    name: greeter
```

Si aplicamos el fichero:

```bash
$ kubectl -n cicd apply -f greeter-taskrun.yaml 
taskrun.tekton.dev/greeter-run created
```

Podemos consultar el log revisando:

```bash
$ tkn taskrun list -n cicd
NAME                STARTED          DURATION     STATUS
greeter-run         8 minutes ago    3 seconds    Succeeded
greeter-run-xd5v5   23 minutes ago   5 seconds    Succeeded
greeter-run-bh6r9   29 minutes ago   5 seconds    Succeeded
hello-run-fpjwk     4 hours ago      16 seconds   Succeeded


$ tkn taskrun logs greeter-run -n cicd
[greeter] Hello Federico Mercurio
```

Usando este método, podemos lanzar varias `TaskRun` de la misma `Task`:

```yaml
---
kind: TaskRun
apiVersion: tekton.dev/v1alpha1
metadata:
  generateName: greeter-run-federico-
spec:
  params:
    - name: subject
      value: "Federico Mercurio"
  taskRef:
    kind: Task
    name: greeter
---
kind: TaskRun
apiVersion: tekton.dev/v1alpha1
metadata:
  generateName: greeter-run-mery-
spec:
  params:
    - name: subject
      value: "Mary Sun"
  taskRef:
    kind: Task
    name: greeter
```

De esta forma, al aplicar el fichero YAML, se generan dos ejecuciones de la `Task`, aunque cada una con unos parámetros diferentes:

> Si usamos `metadata.generateName` no podemos usar `kubectl apply` y debemos usar `kubectl create`.

```bash
$ kubectl -n cicd create -f docs/tekton/deploy/greeter-taskrun.yaml 
taskrun.tekton.dev/greeter-run-federico-5pw6t created
taskrun.tekton.dev/greeter-run-mery-lsgl6 created
```

## Extender el flujo CI/CD con una segunda `Task` y una `Pipeline`

Vamos a extendir el *workflow* de CI/CD añadiendo una segunda `Task`. A continuación organizaremos las dos `Tasks` en una `Pipeline`, de manera similar a cómo incluimos múltiples `Steps` en una `Task`.

### Crear una segunda `Task`

En esta segunda `Task` ejecutamos un *script* en la imagen de Alpine:

```yaml
---
kind: Task
apiVersion: tekton.dev/v1beta1
metadata:
  name: goodbye
spec:
  steps:
    - name: goodbye
      image: alpine:3.13
      script: |
        #!/bin/sh
        echo "Goodbye World!"
```

Creamos esta nueva tarea mediante `kubectl -n cicd apply -f goodbye-task.yaml`.

Para ejecutar esta nueva tarea, creamos un fichero de definción de una `TaskRun`:

```yaml
---
kind: TaskRun
apiVersion: tekton.dev/v1beta1
metadata:
  generateName: goodbye-run-
spec:
  taskRef:
    name: goodbye
```

Y lanzamos la ejecución mediante:

```bash
$ kubectl -n cicd create -f goodbye-taskrun.yaml
taskrun.tekton.dev/goodbye-run-xl7hb created
```

Para revisar los logs, usamos el comando:

```bash
$ tkn taskrun logs --last -n cicd
[goodbye] Goodbye World!
```

### Crear una `Pipeline`

El siguiente paso es crear una `Pipeline` en la que incluiremos las dos tareas creadas: `hello` y `goodbye`:

```yaml
---
kind: Pipeline
apiVersion: tekton.dev/v1beta1
metadata:
  name: hello-goodbye
spec:
  tasks:
    - name: hello
      taskRef:
        name: hello
    - name: goodbye
      taskRef:
        name: goodbye
```

Creamos la `Pipeline` aplicando el fichero YAML de definición:

```bash
$ kubectl apply -f hello-goodbye-pipeline.yaml -n cicd
pipeline.tekton.dev/hello-goodbye created
```

Para realizar la ejecución de la `Pipeline`, debemos crear un `PipelineRun`; podemos obtener una *plantilla* usando la opción `--dry-run` de `tkn`:

```bash
$ tkn pipeline start hello-goodbye --n cicd --dry-run
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  creationTimestamp: null
  generateName: hello-goodbye-run-
  namespace: cicd
spec:
  pipelineRef:
    name: hello-goodbye
status: {}
```

Refinamos la definición de la `PipelineRun`:

```yaml
---
kind: PipelineRun
apiVersion: tekton.dev/v1beta1
metadata:
  generateName: hello-goodbye-run-
spec:
  pipelineRef:
    name: hello-goodbye
```

Y ejecutamos la `Pipeline` con `kubectl create`

```bash
$ kubectl create -f hello-goodbye-pipelinerun.yaml -n cicd
```

Revisamos el resultado de la ejecución de la `Pipeline`:

```bash
$ tkn pipelinerun logs --last -f -n cicd
[hello : hello] Hello world!

[goodbye : goodbye] Goodbye World!
```

## Referencias

- [Your first CI/CD workflow with Tekton](https://tekton.dev/docs/getting-started/#your-first-ci-cd-workflow-with-tekton)
- [Specifying `Parameters`](https://tekton.dev/docs/pipelines/tasks/#specifying-parameters)
- [Getting Started with Pipelines](https://tekton.dev/docs/getting-started/pipelines/)
