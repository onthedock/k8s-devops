# MySQL (1 sola réplica)

Un gran número de aplicaciones requieren una base de datos, por lo que en esta sección se proporcionan los ficheros de definición de los recursos necesarios para desplegar MySQL.

## Detalles a tener en cuenta

- La aplicación no puede escalarse para incluir múltiple réplicas. El *PersistentVolume* sólo puede ser montado por un *Pod*. Hay que valorar la opción de usar *StatefulSets*
- La configuración `strategy.type: Recreate` en la configuración del *Deployment* indica a Kubernetes que **no** use *rolling updates*. Las *rolling updates* no funcionarían, ya que no puedes tener más de un *Pod* corriendo a la vez. La opción `Recretate` detiene el primer *Pod* antes de crear uno nuevo con la configuración actualizada.

## Namespace

En general la base de datos se despliega como parte de otra aplicación, por lo que no sea necesario crear un *Namespace* específico para la base de datos. Si asignas un *Namespace* dedicado, ajusta el nombre del *Namespace* para reflejar de qué aplicación forma parte, p.ej `mysql-wordpress-client-1`.

```yaml
--- 
kind: Namespace
apiVersion: v1
metadata:
  name: mysql
```

A los diferentes recursos aplicamos el conjunto de etiquetas recomendadas en la documentación oficial [Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).

La gestión de todas estas se ve simplificada con herramientas como Helm.

## Volumen

En el clúster disponemos de una *storage class* que provisiona volúmenes de forma dinámica.

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mysql-pvc
  namespace: mysql
  labels:
    app.kubernetes.io/name: mysql
    app.kubernetes.io/instance: mysql-app
    app.kubernetes.io/version: "8.0"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: app
    app.kubernetes.io/managed-by: manually
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

## Secret

La inicialización de MySQL (y MariaDB) requiere proporcionar como mínimo el password del usuario *root*. En vez de pasar la contraseña como variable de entorno, la obtendremos de un *Secret*.

Creamos el fichero "base" de definición del *Secret* usando la opción `--dry-run=client`:

```bash
kubectl create secret generic mysql-root-password -n mysql \
  --from-literal=MYSQL_ROOT_PASSWORD=r00tpa55word \
  --dry-run=client -o yaml \
  | tee mysql-1-replica-02-mysql-root-secret.yaml
```

### Mejora en la configuración de MySQL

En la documentación de la imagen en Docker Hub para la imagen de [mysql](https://hub.docker.com/_/mysql) se proporciona una lista de las variables de entorno que podemos usar para definir una base de datos por defecto, con un usuario con permisos completos (`GRANT ALL`) sobre ella (pero **no *root***).

Otra opción interesante [^1] es la generar una contraseña aleatoria `MYSQL_RANDOM_ROOT_PASSWORD` en combinación con `MYSQL_ONETIME_PASSWORD`, de manera que el *password* del usuario *root* se marca como *expirado* y debe cambiarse. Esto es necesario ya que la contraseña generada para el usuario *root* se muestra en *stdout* del contenedor y por tanto puede quedar expuesta en el sistema de gestión de logs.

> Define los valores de la aplicación, usuario y contraseña del usuario en las variables de entorno `$DBNAME`, `$DBUSER` y `$DBUSERPASSWORD` antes de lanzar el comando.

```bash
kubectl create secret generic mysql-secrets -n mysql \
  --from-literal=MYSQL_RANDOM_ROOT_PASSWORD=true \
  --from-literal=MYSQL_ONETIME_PASSWORD=true \
  --from-literal=MYSQL_DATABASE=$DBNAME \
  --from-literal=MYSQL_USER=$DBUSER \
  --from-literal=MYSQL_PASSWORD=$DBUSERPASSWORD \
  --dry-run=client -o yaml \
  | tee mysql-1-replica-02-mysql-secrets.yaml
```

## Deployment

En el fichero de definición del *Deployment* de MySQL configuramos sólo la variable de entorno que contiene la contraseña del usuario *root* (es la única requerida). Considera incluir las opciones de definir un usuario no *root* al usar MySQL como *backend* para una aplicación.

```yaml
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: mysql
  namespace: mysql
  labels:
    app.kubernetes.io/name: mysql
    app.kubernetes.io/instance: mysql-app
    app.kubernetes.io/version: "8.0"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: app
    app.kubernetes.io/managed-by: manually
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-root-password
                  key: MYSQL_ROOT_PASSWORD
          ports:
            - name: mysql-tcp
              containerPort: 3306
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-data
          persistentVolumeClaim:
            claimName: mysql-pvc
```

## Servicio

```yaml
---
kind: Service
apiVersion: v1
metadata:
  namespace: mysql
  name: mysql
  labels:
    app.kubernetes.io/name: mysql
    app.kubernetes.io/instance: mysql-app
    app.kubernetes.io/version: "8.0"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: app
    app.kubernetes.io/managed-by: manually
spec:
  selector:
    app.kubernetes.io/name: mysql
  ports:
    - name: mysql-tcp
      port : 3306
```

## Validación del despliegue

> Si queremos conectar a la base de datos desde otro *namespace*, debemos referenciar el nombre del servicio de MySQL indicando el *namespace* en el que se encuentra; por ejemplo: `... -h mysql.mysql.svc` (nombre del servicio, nombre del namespace y `svc`).

En vez de ejecutar el comando de forma interactiva en un contenedor desplegado, usaremos un *Job* para validar que el despliegue de MySQL se ha realizado correctamente.

Si se establece la conexión a la base de datos, el *Job* finaliza correctamente.

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: mysql
  labels:
    app.kubernetes.io/name: mysql
    app.kubernetes.io/instance: mysql-app
    app.kubernetes.io/version: "8.0"
    app.kubernetes.io/component: database
    app.kubernetes.io/part-of: app
    app.kubernetes.io/managed-by: manually
  generateName: check-mysql-status-
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mysql
    spec:
      restartPolicy: Never
      containers:
        - name: check-mysql-status
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-root-password
                  key: MYSQL_ROOT_PASSWORD
          command: ["/bin/bash"]
          args:
            - "-c"
            - "mysql -h mysql.mysql.svc -p$MYSQL_ROOT_PASSWORD"
```

> El comando para la validación *manual* sería `kubectl run -n mysql -it --rm --image=mysql:8.0 --restart=Never mysql-client -- mysql -h mysql -pr00tpa55word`

Referencias:

- [Run a Single-Instance Stateful Application](https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/)

[^1]: [Docker Environment Variables](https://dev.mysql.com/doc/refman/8.0/en/docker-mysql-more-topics.html#docker-environment-variables) en la documentación oficial de MySQL 8.0

Versiones:

```bash
$ kubectl version --short
Client Version: v1.20.4
Server Version: v1.20.4+k3s1
```
