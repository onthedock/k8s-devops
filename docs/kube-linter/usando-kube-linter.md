# Usando KubeLinter

Vamos a usar KubeLinter para crear un *Deployment* de un *jumpod* validado por KubeLinter.

## *Namespace* para las pruebas

> El fichero de definición se encuentra en la ruta `$YAML_FOLDER`.

Definimos un *namespace* para ejecutar las pruebas:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: jumpod
```

Analizamos el fichero con `kube-linter lint $YAML_FOLDER`:

```bash
$ kube-linter lint $YAML_FOLDER
No lint errors found!
```

De momento, todo ok!

## Definición del *pod*

```yaml
---
kind: Pod
apiVersion: v1
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
  restartPolicy: Always
```

Analizamos de nuevo; ahora el resultado no es tan bueno:

```bash
jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" does not have a read-only root file system (check: no-read-only-root-fs, remediation: Set readOnlyRootFilesystem to true in your container's securityContext.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" is not set to runAsNonRoot (check: run-as-non-root, remediation: Set runAsUser to a non-zero number, and runAsNonRoot to true, in your pod or container securityContext. See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ for more details.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" has cpu request 0 (check: unset-cpu-requirements, remediation: Set your container's CPU requests and limits depending on its requirements. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits for more details.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" has cpu limit 0 (check: unset-cpu-requirements, remediation: Set your container's CPU requests and limits depending on its requirements. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits for more details.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" has memory request 0 (check: unset-memory-requirements, remediation: Set your container's memory requests and limits depending on its requirements. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits for more details.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" has memory limit 0 (check: unset-memory-requirements, remediation: Set your container's memory requests and limits depending on its requirements. See https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits for more details.)

Error: found 6 lint errors
```

## Ausencia de *requests* y *limits*

Tenemos cuatro errores similares:

```bash
(...) container "busybox" has cpu request 0
(...) container "busybox" has cpu limit 0
(...) container "busybox" has memory request 0
(...) container "busybox" has memory limit 0
```

Como podemos comprobar en el [enlace sugerido](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits) para corregir esta situación, debemos especificar *requests* y *limits* para el consumo de CPU y memoria del *pod*.

```yaml hl_lines="14 15 16 17 18 19 20"
---
kind: Pod
apiVersion: v1
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
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

Si analizamos de nuevo el fichero, estos cuatro errores deben haber desaparecido:

```bash
jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" does not have a read-only root file system (check: no-read-only-root-fs, remediation: Set readOnlyRootFilesystem to true in your container's securityContext.)

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" is not set to runAsNonRoot (check: run-as-non-root, remediation: Set runAsUser to a non-zero number, and runAsNonRoot to true, in your pod or container securityContext. See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ for more details.)

Error: found 2 lint errors
```

## El contenedor no debe ejecutarse como *root*

```bash
(...) container "busybox" is not set to runAsNonRoot
```

De nuevo en el mensaje de salida de KubeLinter se proporciona un enlace donde consultar la solución en la documentación oficial de Kubernetes: [Set the security context for a Pod](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).

```yaml hl_lines="14 15 16"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

Además de especificar el UID del usuario con el que se ejecuta el contenedor, también especificamos el GID (`runAsGroup`) ya que si se omite el *group ID* primario será `root` (0).

Si analizamos la definición del Pod de nuevo:

```bash
jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) container "busybox" is not set to runAsNonRoot (check: run-as-non-root, remediation: Set runAsUser to a non-zero number, and runAsNonRoot to true, in your pod or container securityContext. See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ for more details.)

Error: found 1 lint error
```

> KubeLinter no devuelve errores incluso si se omite `runAsGroup`.

## El contenedor no tiene un sistema de ficheros del volumen raíz de sólo lectura

Para eliminar el error restante, el sistema de ficheros del volumen raíz (*root volume filesystem*) debe ser de sólo lectura:

```bash
(...) )container "busybox" does not have a read-only root file system
(check: no-read-only-root-fs, remediation: Set readOnlyRootFilesystem
 to true in your container's securityContext.)
```

Tal y como indica la salida de KubeLinter, modificamos el fichero de definición del Pod para incluir la  opción:

```yaml hl_lines="17"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        readOnlyRootFilesystem: true
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

Comprobamos que KubeLinter no muestra el aviso de que el contenedor debe ejecutarse como un usuario no *root*.

```bash
$ kube-linter lint $YAML_FOLDER 
No lint errors found!
```

En este caso, **aunque el contenedor se ejecutara como *root*, no podría modificar los ficheros en el *root volume filesystem* porque lo hemos marcado como *readOnly***.

## Comparando las opciones

### Primer caso: `runAsUser: 1001`

Abrimos una *shell* en el Pod desplegado con el YAML donde se indica que el contenedor debe ejecutarse como usuario 1001:

> Comentamos la línea que especifica el sistema de ficheros como de sólo lectura.

```yaml hl_lines="17"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        # readOnlyRootFilesystem: true
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

```bash
kubectl exec -it pod/jumpod -n jumpod -- /bin/sh
```

En el Pod:

```bash hl_lines="2"
/ $ whoami
whoami: unknown uid 1001
```

Si revisamos a qué tiene acceso el usuario en el contenedor, vemos que sólo tiene permisos para escribir en `/tmp`, mientras que en el resto sólo tiene permisos de lectura y de ejecución: `drwxr-xr-x` (el propietario es `root`):

```bash  hl_lines="12 15 17"
/ $ ls -lah
total 44K    
drwxr-xr-x    1 root     root        4.0K Feb 12 18:47 .
drwxr-xr-x    1 root     root        4.0K Feb 12 18:47 ..
drwxr-xr-x    2 root     root       12.0K Feb  1 19:44 bin
drwxr-xr-x    5 root     root         360 Feb 12 18:47 dev
drwxr-xr-x    1 root     root        4.0K Feb 12 18:47 etc
drwxr-xr-x    2 nobody   nobody      4.0K Feb  1 19:44 home
dr-xr-xr-x  368 root     root           0 Feb 12 18:47 proc
drwx------    2 root     root        4.0K Feb  1 19:44 root
dr-xr-xr-x   13 root     root           0 Feb 12 18:47 sys
drwxrwxrwt    1 root     root        4.0K Feb 12 18:50 tmp
drwxr-xr-x    3 root     root        4.0K Feb  1 19:44 usr
drwxr-xr-x    1 root     root        4.0K Feb 12 18:47 var
/ $ touch /tmp/test
/ $ ls /tmp/
/tmp/test
```

El usuario con `uid: 1001` tiene permisos sobre `/tmp` y puede crear ficheros en esa carpeta. En el resto, no tiene permisos de escritura.

### Segundo caso: `readOnlyRootFilesystem: true`

> Comentamos la línea que especifica un usuario no-root, pero establecemos el sistema de ficheros como de sólo lectura.

```yaml hl_lines="17"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        #runAsUser: 1001
        #runAsGroup: 1001
        readOnlyRootFilesystem: true
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

Si sólo especificamos especficamos la opción `readOnlyRootFilesystem: true`, el usuario con el que se ejecutar el Pod es `root`:

```bash
/ # whoami
root
```

Aunque el usuario tiene permisos de escritura sobre el sistema de ficheros del Pod, cuando intentamos crear un fichero:

```bash hl_lines="5 15 16 17"
/ # ls -lah
total 44K
drwxr-xr-x    1 root     root        4.0K Feb 12 19:17 .
drwxr-xr-x    1 root     root        4.0K Feb 12 19:17 ..
drwxr-xr-x    2 root     root       12.0K Feb  1 19:44 bin
drwxr-xr-x    5 root     root         360 Feb 12 19:17 dev
drwxr-xr-x    1 root     root        4.0K Feb 12 19:17 etc
drwxr-xr-x    2 nobody   nobody      4.0K Feb  1 19:44 home
dr-xr-xr-x  375 root     root           0 Feb 12 19:17 proc
drwx------    2 root     root        4.0K Feb  1 19:44 root
dr-xr-xr-x   13 root     root           0 Feb 12 19:17 sys
drwxrwxrwt    2 root     root        4.0K Feb  1 19:44 tmp
drwxr-xr-x    3 root     root        4.0K Feb  1 19:44 usr
drwxr-xr-x    1 root     root        4.0K Feb 12 19:17 var
/ # touch /bin/test
touch: /bin/test: Read-only file system
```

Es decir, aunque el usuario es `root`, no puede crear ficheros en el *filesystem* del contenedor porque **está marcado como de sólo lectura**.

### Tercer caso: `runAsUser: 1001` y `readOnlyRootFilesystem: true`

Si desplegamos un Pod en el que especificamos un usuario no-root (`uid: 1001`) y además un **sistema de ficheros de sólo lectura**:

```yaml hl_lines="15 16 17"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        readOnlyRootFilesystem: true
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
  restartPolicy: Always
```

En este caso, el usuario con el que se ejecuta el contenedor es el `1001`, que sólo tiene permisos de escritura sobre `/tmp`.

Sin embargo, como pasaba con el usuario `root`, la opción de *readOnly* del sistema de ficheros impide crear ficheros también en `/tmp`:

```bash  hl_lines="2 14 17 18"
/ $ whoami
whoami: unknown uid 1001
/ $ ls -lah
total 44K    
drwxr-xr-x    1 root     root        4.0K Feb 12 19:33 .
drwxr-xr-x    1 root     root        4.0K Feb 12 19:33 ..
drwxr-xr-x    2 root     root       12.0K Feb  1 19:44 bin
drwxr-xr-x    5 root     root         360 Feb 12 19:33 dev
drwxr-xr-x    1 root     root        4.0K Feb 12 19:33 etc
drwxr-xr-x    2 nobody   nobody      4.0K Feb  1 19:44 home
dr-xr-xr-x  373 root     root           0 Feb 12 19:33 proc
drwx------    2 root     root        4.0K Feb  1 19:44 root
dr-xr-xr-x   13 root     root           0 Feb 12 19:33 sys
drwxrwxrwt    2 root     root        4.0K Feb  1 19:44 tmp
drwxr-xr-x    3 root     root        4.0K Feb  1 19:44 usr
drwxr-xr-x    1 root     root        4.0K Feb 12 19:33 var
/ $ touch /tmp/test
touch: /tmp/test: Read-only file system
```

En este caso, aunque el usuario `uid: 1001` tiene permisos de escritura en `/tmp`, como el sistema de ficheros es *readOnly*, **no puede escribir en el sistema de ficheros**.

### Permisos sobre un volumen adicional

En los escenarios anteriores hemos visto el efecto de aplicar `runAsUser` y `reaOnlyRootFilesystem` sobre la capacidad de que el proceso en ejecución pueda escribir sobre diferentes puntos del volumen raíz.

Definimos un *Persistent Volume Claim* para montar un volumen adicional en el Pod.

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
```

Y lo añadimos a la definición del Pod:

```yaml hl_lines="26"
---
kind: Pod
apiVersion: v1
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
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        readOnlyRootFilesystem: true
      resources:
        requests:
          memory: "64Mi"
          cpu: "10m"
        limits:
          memory: "64Mi"
          cpu: "10m"
      volumeMounts:
        - mountPath: "/var/www/html"
          name: test-volume
  volumes:
    - name: test-volume
      persistentVolumeClaim:
        claimName: test-pvc
  restartPolicy: Always
```

En primer lugar, analizamos los ficheros con KubeLinter:

```bash
$ kube-linter lint $YAML_FOLDER
No lint errors found!
```

Desplegamos la definición actualizada del Pod:

```bash
$ kubectl get pods -n jumpod
No resources found in jumpod namespace.
$ kubectl apply -f jumpod.yaml -n jumpod
namespace/jumpod unchanged
persistentvolumeclaim/test-pvc created
pod/jumpod created
```

Validamos que se ha creado el *PersistentVolumeClain*:

```bash
$ kubectl get pvc -n jumpod
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc   Bound    pvc-65009968-ab4b-49ea-9c7e-de62665b01ec   8Gi        RWO            local-path     15s
```

Revisamos dónde podemos escribir en el sistema de ficheros del Pod:

```bash hl_lines="3 19"
$ kubectl exec -ti jumpod -n jumpod -- /bin/sh
/ $ whoami
whoami: unknown uid 1001
/ $ ls -lah
total 48K    
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 .
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 ..
drwxr-xr-x    2 root     root       12.0K Feb  1 19:44 bin
drwxr-xr-x    5 root     root         360 Feb 13 16:06 dev
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 etc
drwxr-xr-x    2 nobody   nobody      4.0K Feb  1 19:44 home
dr-xr-xr-x  368 root     root           0 Feb 13 16:06 proc
drwx------    2 root     root        4.0K Feb  1 19:44 root
dr-xr-xr-x   13 root     root           0 Feb 13 16:06 sys
drwxrwxrwt    2 root     root        4.0K Feb  1 19:44 tmp
drwxr-xr-x    3 root     root        4.0K Feb  1 19:44 usr
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 var
/ $ touch /tmp/test-file
touch: /tmp/test-file: Read-only file system
```

No podemos escribir sobre `/tmp` porque forma parte del sistema de ficheros del volumen raíz del contenedor.

Sin embargo, revisando los permisos sobre `/var/www/html` (el punto donde hemos montado el volumen), vemos que cualquier usuario tienen permisos de escritura en él:

```bash hl_lines="3"
/ $ ls -lah /var/www/html/
total 12K    
drwxrwxrwx    2 root     root        4.0K Feb 13 16:14 .
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 ..
/ $
```

Validamos creando un fichero:

```bash hl_lines="3 8"
/ $ echo "Hello World" > /var/www/html/test-file 
/ $ cat /var/www/html/test-file 
Hello World
/ $ ls -lah /var/www/html/
total 12K    
drwxrwxrwx    2 root     root        4.0K Feb 13 16:14 .
drwxr-xr-x    1 root     root        4.0K Feb 13 16:06 ..
-rw-r--r--    1 1001     1001          12 Feb 13 16:14 test-file
```

## De Pod a Deployment

Analizar el fichero de definición de un Pod nos ha servidor para familiarizarnos con el uso de KubeLinter. Sin embargo, en un entorno real no desplegaremos Pods individuales, sino Deployments.

Vamos a analizar un Deployment de una sola réplica basado en la definición del Pod de la sección anterior.

```yaml
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: jumpod-deploy
  label:
    app: jumpod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jumpod
  template:
    metadata:
      labels:
        app: jumpod
    spec:
      containers:
        - name: jumpod
          image: busybox
          command:
            - sleep
            - "3600"
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 1001
            runAsGroup: 1001
            readOnlyRootFilesystem: true
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
            limits:
              memory: "64Mi"
              cpu: "10m"
```

Al partir de la base que hemos establecido con KubeLinter para el Pod, la construcción del Deployment no debe generar alertas:

```bash
$ kube-linter lint $YAML_FOLDER 
No lint errors found!
```

## Realizar comprobaciones deshabilitadas por defecto

Aunque este Deployment no las necesita, una buena práctica es la de definir *probes* que comprueben la disponibilidad y salud de los Pods desplegados.

KubeLinter no verifica por defecto si la definición del objeto contiene las *readiness* o *liveness* *probes*. Las comprobaciones están definidas, pero deshabilitadas [^1].

Para incluir una validación deshabilitada por defecto, debemos especificarla pasando un fichero de configuración a KubeLinter `--config kubelinter-config.yaml`. Este fichero puede contiener dos secciones: `checks` y `customChecks`.

El siguiente ejemplo de fichero de configuración habilita las comprobaciones de existencia de las *readiness* y *liveness* *probes*:

```yaml
---
checks:
  addAllBuiltIn: true
  include:
    - "no-readiness-probe"
    - "no-liveness-probe"
```

Si ejecutamos ahora la comprobación, obtenemos los correspondientes avisos:

```bash
$ kube-linter lint $YAML_FOLDER --config kubelinter-config-probes.yaml 

jumpod.yaml: (object: <no namespace>/jumpod-deploy apps/v1, Kind=Deployment) container "jumpod" does not specify a liveness probe (check: no-liveness-probe, remediation: Specify a liveness probe in your container. See https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ for more details.)

jumpod.yaml: (object: <no namespace>/jumpod-deploy apps/v1, Kind=Deployment) container "jumpod" does not specify a readiness probe (check: no-readiness-probe, remediation: Specify a readiness probe in your container. See https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ for more details.)

Error: found 2 lint errors
```

## Realizando validaciones personalizadas

KubeLinter permite personalizar algunas de las comprobaciones definidas por defecto (mediante parámetros) y definir nuevas *plantillas* (*templates*).

En el siguiente ejemplo vamos a validar que en los objetos analizados se incluya una etiqueta (*label*) que indique la versión de la *release*.

Para ello, usamos como *custom check* la plantilla para [`required-label`](https://docs.kubelinter.io/#/generated/templates?id=required-label):

```yaml
---
customChecks:
  - name: required-label-release
    template: required-label
    params:
      key: company-name.com/release
```

Si analizamos los ficheros en `$YAML_FOLDER`, vemos que ninguno de los recursos contiene esta etiqueta que *exige* la política interna de la empresa (por ejemplo):

```bash
$ kube-linter lint $YAML_FOLDER --config kubelinter-config-label-release.yaml

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Namespace) no label matching "company-name.com/release=<any>" found (check: required-label-release, remediation: )

jumpod.yaml: (object: <no namespace>/test-pvc /v1, Kind=PersistentVolumeClaim) no label matching "company-name.com/release=<any>" found (check: required-label-release, remediation: )

jumpod.yaml: (object: <no namespace>/jumpod /v1, Kind=Pod) no label matching "company-name.com/release=<any>" found (check: required-label-release, remediation: )

jumpod.yaml: (object: <no namespace>/jumpod-deploy apps/v1, Kind=Deployment) no label matching "company-name.com/release=<any>" found (check: required-label-release, remediation: )

Error: found 4 lint errors
```

[^1]: Lista de todas las comprobaciones definidas en KubeLinter: [KubeLinter checks](https://docs.kubelinter.io/#/generated/checks)
