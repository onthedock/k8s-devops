# Documentación como código (Prueba de concepto)

El objetivo de la prueba de concepto es usar MkDocs y un *Job* (o un *CronJob*) para generar documentación en formato web y publicarla usando Kubernetes.

El proceso consiste en tres pasos:

1. `git clone` del repo donde se encuentra la documentación en un volumen local.

    - Si es un repositorio público, no son necesarias credenciales
    - Si es un repositorio privado, ver cómo pueden pasarse las credenciales al comando `git clone`

1. ejecutar `mkdocs build` apuntando a la carpeta raíz de mkdocs.
1. Publicar la web resultante

Empezando por el final; la web final se publicará usando un servidor web tipo Nginx. El contenido de la web publicada se obtiene de un volumen (montado como *read only*), ya que el servidor web no necesita modificar ningún fichero de los publicados.

La construcción del sitio web estático se genera mediante un Job con dos contenedores... El primero, un [init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), clona el repositorio remoto en el volumen efímero.

El segundo contenedor (el *principal*) monta el volumen efímero y el volumen final (usado por el servidor web). El job genera el sitio estático en la carpeta (lo que actualiza la web publicada por Nginx).

Referencias:

- Imagen en DockerHub [squidfunk/mkdocs-material](https://hub.docker.com/r/squidfunk/mkdocs-material/)

- Documentación en el sitio oficial de Kubernetes sobre cómo construir un Pod con un *init container* [(TASK) Create a Pod that has an Init Container](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-initialization/#create-a-pod-that-has-an-init-container)

- Definir la carpeta en la que se encuentran los ficheros fuente de la documentación `docs_dir` en [Build directories](https://www.mkdocs.org/user-guide/configuration/#build-directories)
- Definir la carpeta en la que se genera el contenido estático generado por MkDocs: `site_dir` en [Build directories](https://www.mkdocs.org/user-guide/configuration/#build-directories)

## Namespace

Vamos a colocar los diferentes elementos en un *Namespace* llamado `doc-as-code`:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: doc-as-code
```

## Volúmenes

Empezamos definiendo el volumen que alojará el sitio generado.

Al crear un *PVC*, si no especificamos una *storageClass*, se usa la *storage class*  por defecto especificada en el clúster. En el caso de K3S, se usa [local-path](https://github.com/rancher/local-path-provisioner/blob/master/README.md), que permite la provisión dinámica basada en las caraterísticas del volumen nativo de tipo `local` de Kubernetes. La *storageClass* `local-path` permite provisionar volúmenes de tipo `hostPath` de forma dinámica.

> `local-path` no soporta el *accessMode* `ReadOnlyMany`.

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: website-pvc
  namespace: doc-as-code
  labels:
    app.kubernetes.io/name: doc-as-code-pvc
    app.kubernetes.io/component: storage
    app.kubernetes.io/part-of: doc-as-code
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

El siguiente paso es generar el *Deployment* basado en Nginx que permita servir la documentación generada. Los *Pods* creados por el *Deployment* deben montar el volumen en modo *ReadOnly*.

Aunque el volumen soporte múltiples modos de acceso, por ejemplo `ReadWriteOnce` y `ReadOnlyMany` sólo puede montarse usando un único modo (todos los *Pods* que lo monten debe usar el mismo *access mode*).

## Website

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: doc-as-code-nginx
  namespace: doc-as-code
  labels:
    app.kubernetes.io/name: doc-as-code-nginx
    app.kubernetes.io/component: webserver
    app.kubernetes.io/part-of: doc-as-code
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: doc-as-code-nginx
      app.kubernetes.io/component: webserver
      app.kubernetes.io/part-of: doc-as-code
  replicas: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: doc-as-code-nginx
        app.kubernetes.io/component: webserver
        app.kubernetes.io/part-of: doc-as-code
    spec:
      containers:
        - name: nginx
          image: nginx:stable-alpine
          imagePullPolicy: IfNotPresent
          ports:
          - name: http-tcp
            containerPort: 80
          volumeMounts:
            - name: webdocs
              mountPath: /usr/share/nginx/html
              readOnly: true # Montamos el volumen como ReadOnly en el webserver
      volumes:
        - name: webdocs
          persistentVolumeClaim:
            claimName: website-pvc
```

Si usas *port-forward* para validar el despliegue obtienes un error `403` porque no hay ningún fichero HTML en la ruta montada (todavía).

Vamos a usar el repositorio público: <https://github.com/onthedock/k8s-devops.git>, que contiene documentación en formato MkDocs.

> He verificado que la imagen [squidfunk/mkdocs-material](https://hub.docker.com/r/squidfunk/mkdocs-material/) incluye Git; puede comprobarse revisando el [`Dockerfile`](https://github.com/squidfunk/mkdocs-material/blob/master/Dockerfile).

Como la imagen contiene Git, en vez de lanzar un *init container* que clone el repositorio remoto primero, vamos a usar un *script*, montado en un *ConfigMap* (o directamente, ya que igual son tres líneas), que ejecute:

- clonado del repositorio remoto a una carpeta local (de un volumen temporal)
- `mkdocs build site_dir=volumen_nginx/donde toque` (puedo tener problemas de permisos¿?)

Como en la imagen `squidfunk/mkdocs-material` se especifica como `ENTRYPOINT ["mkdocs"]`, es necesario sobrescribir el comando a ejecutar en el contenedor [^1].

Vamos con la definición de un *Job* usando la imagen base `mkdocs-material`.

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: doc-as-code
  labels:
    app.kubernetes.io/name: doc-as-code-build
    app.kubernetes.io/component: builder
    app.kubernetes.io/part-of: doc-as-code
  generateName: doc-as-code-builder-
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: doc-as-code-build
        app.kubernetes.io/component: builder
        app.kubernetes.io/part-of: doc-as-code
    spec:
      restartPolicy: Never
      containers:
        - name: doc-as-code-builder
          image: squidfunk/mkdocs-material
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - name: website-docs
              mountPath: /usr/share/nginx/html
          command: ["/bin/sh"]
          args:
            - "-c"
            - "git clone https://github.com/onthedock/k8s-devops.git /docs && mkdocs build --site-dir /usr/share/nginx/html"
      volumes:
        - name: website-docs
          persistentVolumeClaim:
            claimName: website-pvc
```

[^1]: [Define a Command and Arguments for a Container](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes)
