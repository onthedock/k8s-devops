# Creación de un *backup* (manual)

Vamos a ver cómo crear copias de seguridad puntuales y recurrentes usando la herramienta de línea de comandos **velero** (lanzada desde un *Job*)

## Aplicación de prueba - Nginx

Para demostrar las capacidades de Velero desplegamos una aplicación de prueba: un servicio con dos réplicas de Nginx inspirada en la que proporciona el equipo de Velero [`base.yaml`](https://github.com/vmware-tanzu/velero/blob/main/examples/nginx-app/base.yaml).:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: nginx
  labels:
    app: nginx

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.17.6
        name: nginx
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: my-nginx
  namespace: nginx
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: NodePort
```

## Copia de seguridad (manual)

Al generar una nueva copia de seguridad con Velero, podemos elegir qué elementos incluir o excluir en base a las etiquetas (*labels*) indicadas, realizar *backup* de *Namespaces* completos o del clúster completo (opción por defecto).

Para crear la copia de seguridad del *Namespace* `nginx`, usaremos el comando `velero backup create ${nombre-backup} --include-namespaces nginx`.

> Para realizar *backup* de varios *Namespaces*, especifica la lista de los *Namespaces* a incluir separados por comas.

### Permisos para realizar la copia de seguridad

Para poder realizar copias de seguridad es necesario que el usuario con el que se ejecuta el contenedor - la *ServiceAccount*- pueda crear objetos de tipo `backup` (o `schedule`) en el *Namespace* `velero`.

En cada organización la gestión de las copias de seguidad puede estar administradas de forma diferente: puede estar centralizada en un equipo "de operaciones", asignada al equipo de desarrollo o alguna situación intermedia (en el entorno de desarrollo se encarga el equipo de desarrollo y en el de producción el de operaciones, por ejemplo).

En mi caso, voy a lanzar el *backup* usando la *ServiceAccount* `velerocli` en el *Namespace* `velero-cli`, desde donde he realizado la instalación de Velero.

Generamos un *Job* para crear una copia de seguridad del *Namespace* `nginx`:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-create-backup-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-create-backup
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero create backup nginx-backup --include-namespaces nginx"]
```

El comando `velero create backup` indica al operador de Velero que realice una copia de seguridad del *Namespace* indicado. Si revisamos los logs del *Job*:

```bash
Backup request "nginx-backup" submitted successfully.
Run `velero backup describe nginx-backup` or `velero backup logs nginx-backup` for more details.
```

Siguiendo las instrucciones de la salida del comando anterior, generamos un *Job* (copiando la definición del *Job* anterior) para "describir" el *backup* generado:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-describe-backup-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-describe-backup
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero describe backup nginx-backup"]
```

En la salida del *Pod* generado por el *Job* vemos que la copia de seguridad se ha creado con éxito:

```bash
Name: nginx-backup
Namespace: velero
Labels: velero.io/storage-location=default
Annotations: velero.io/source-cluster-k8s-gitversion=v1.20.4+k3s1
velero.io/source-cluster-k8s-major-version=1
velero.io/source-cluster-k8s-minor-version=20
Phase: Completed
Errors: 0
Warnings: 0
Namespaces:
Included: nginx
Excluded: <none>
Resources:
Included: *
Excluded: <none>
Cluster-scoped: auto
Label selector: <none>
Storage Location: default
Velero-Native Snapshot PVs: auto
TTL: 720h0m0s
Hooks: <none>
Backup Format Version: 1.1.0
Started: 2021-04-04 18:12:00 +0000 UTC
Completed: 2021-04-04 18:12:02 +0000 UTC
Expiration: 2021-05-04 18:12:00 +0000 UTC
Total items to be backed up: 49
Items backed up: 49
Velero-Native Snapshots: <none included>
```

Como vemos, la copia de seguridad se ha realizado inmediatamente, en cuanto se ha definido el objeto *backup* en la API de Kubernetes.

Revisando el contenido del *bucket* `velero-backup`, vemos que se han creado los ficheros de la copia de seguridad en `/valero-backup/backups/nginx-backup/`.

Del mismo modo, generamos un *Job* para obtener los logs del proceso `velero backup logs nginx-backup`:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-backup-logs-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-backup-logs
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero backup logs nginx-backup"]
```

Con lo que podemos consultar el resultado de la ejecución del proceso de creación de la copia de seguridad:

```bash
...
time="2021-04-04T18:12:01Z" level=info msg="Backing up item" backup=velero/nginx-backup logSource="pkg/backup/item_backupper.go:121" name=nginx namespace=nginx resource=namespaces
time="2021-04-04T18:12:01Z" level=info msg="Backed up 45 items out of an estimated total of 49 (estimate will change throughout the backup)" backup=velero/nginx-backup logSource="pkg/backup/backup.go:394" name=nginx namespace= progress= resource=namespaces
time="2021-04-04T18:12:01Z" level=info msg="Processing item" backup=velero/nginx-backup logSource="pkg/backup/backup.go:354" name=my-nginx namespace=nginx progress= resource=endpoints
time="2021-04-04T18:12:01Z" level=info msg="Backing up item" backup=velero/nginx-backup logSource="pkg/backup/item_backupper.go:121" name=my-nginx namespace=nginx resource=endpoints
time="2021-04-04T18:12:01Z" level=info msg="Backed up 46 items out of an estimated total of 49 (estimate will change throughout the backup)" backup=velero/nginx-backup logSource="pkg/backup/backup.go:394" name=my-nginx namespace=nginx progress= resource=endpoints
time="2021-04-04T18:12:01Z" level=info msg="Processing item" backup=velero/nginx-backup logSource="pkg/backup/backup.go:354" name=nginx-deployment namespace=nginx progress= resource=deployments.apps
time="2021-04-04T18:12:01Z" level=info msg="Backing up item" backup=velero/nginx-backup logSource="pkg/backup/item_backupper.go:121" name=nginx-deployment namespace=nginx resource=deployments.apps
time="2021-04-04T18:12:01Z" level=info msg="Backed up 47 items out of an estimated total of 49 (estimate will change throughout the backup)" backup=velero/nginx-backup logSource="pkg/backup/backup.go:394" name=nginx-deployment namespace=nginx progress= resource=deployments.apps
time="2021-04-04T18:12:01Z" level=info msg="Processing item" backup=velero/nginx-backup logSource="pkg/backup/backup.go:354" name=nginx-deployment-57d5dcb68 namespace=nginx progress= resource=replicasets.apps
time="2021-04-04T18:12:01Z" level=info msg="Backing up item" backup=velero/nginx-backup logSource="pkg/backup/item_backupper.go:121" name=nginx-deployment-57d5dcb68 namespace=nginx resource=replicasets.apps
time="2021-04-04T18:12:01Z" level=info msg="Backed up 48 items out of an estimated total of 49 (estimate will change throughout the backup)" backup=velero/nginx-backup logSource="pkg/backup/backup.go:394" name=nginx-deployment-57d5dcb68 namespace=nginx progress= resource=replicasets.apps
time="2021-04-04T18:12:01Z" level=info msg="Processing item" backup=velero/nginx-backup logSource="pkg/backup/backup.go:354" name=my-nginx-r8ggk namespace=nginx progress= resource=endpointslices.discovery.k8s.io
time="2021-04-04T18:12:01Z" level=info msg="Backing up item" backup=velero/nginx-backup logSource="pkg/backup/item_backupper.go:121" name=my-nginx-r8ggk namespace=nginx resource=endpointslices.discovery.k8s.io
time="2021-04-04T18:12:01Z" level=info msg="Backed up 49 items out of an estimated total of 49 (estimate will change throughout the backup)" backup=velero/nginx-backup logSource="pkg/backup/backup.go:394" name=my-nginx-r8ggk namespace=nginx progress= resource=endpointslices.discovery.k8s.io
time="2021-04-04T18:12:02Z" level=info msg="Backed up a total of 49 items" backup=velero/nginx-backup logSource="pkg/backup/backup.go:419" progress=
```

## Generando un nuevo *backup*

Si intentamos crear una nueva copia de seguridad del *Namespace* `nginx` ejecutando de nuevo el *Job* de creación del *backup*:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-create-backup-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-create-backup
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero create backup nginx-backup --include-namespaces nginx"]
```

El *Job* falla con el mensaje:

```bash
An error occurred: backups.velero.io "nginx-backup" already exists
```

Como vemos, los *backups* puntuales deben tener nombres únicos; una sencilla modificación al *Job* sería incluir la fecha del *backup*, por ejemplo:

```yaml
...
  command: ["/bin/sh"]
  args: ["-c", "velero create backup nginx-backup-$(date +%F) --include-namespaces nginx"]
```

Sin embargo, Velero ofrece una opción más práctica para la ejecución de copias de seguridad recurrentes.

## Copias de seguridad recurrentes (*schedules*)

Aunque realizar una copia de seguridad puntual es necesario en momentos determinados, lo habitual es realizar copias periódicas (cada día, por ejemplo).

Velero ofrece la posibilidad de crear copias recurrentes a través de la configuración del *Custom Resource* `schedules` (usando la herramienta **velero**).

El siguiente *Job* crea una copia de seguridad del *Namespace* `nginx` cada cinco minutos mediante el comando `velero schedule create`:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-schedule-backup-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-schedule-backup
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero schedule create nginx-backups --schedule='*/5 * * * *' --include-namespaces nginx"]
```

El formato de la frecuencia de las copias de seguridad especificado en el parámetro `--schedule` es el de [Cron](https://en.wikipedia.org/wiki/Cron).

En el log del *Job* vemos que se ha programado el *backup* correctamente:

```bash
Schedule "nginx-backups" created successfully.
```

En MinIO se genera una "carpeta" para cada ejecución de cada repetición del *backup* en `/velero-backup/backups/nginx-backups-YYYYMMDDhhmmss/` que contiene los ficheros que componen la copia de seguridad de los objetos de Kubernetes incluidos en el *backup*.
