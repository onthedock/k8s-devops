# Recuperar copia de seguridad

Velero realiza copias de seguridad (puntuales o recurrentes) para recuperarnos con rapidez de un desastre en el clúster de Kubernetes.

## Pérdida "accidental" de un *Namespace*

Eliminamos el *Namespace* `nginx-example` para simular un desastre:

```bash
$ kubectl delete ns nginx-example
namespace "nginx-example" deleted
```

## Consultar las copias de seguridad disponibles

Si hemos programado un *schedule*, disponemos de múltiples copias de seguridad.

Consultamos las copias disponibles:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-restore-get-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-restore-get
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh"]
          args: ["-c", "velero restore get"]
```

Lo que devuelve, en los logs:

```bash
NAME STATUS ERRORS WARNINGS CREATED EXPIRES STORAGE LOCATION SELECTOR
nginx-backup Completed 0 0 2021-04-04 18:12:00 +0000 UTC 26d default <none>
nginx-backup-2021-04-04 Completed 0 0 2021-04-04 18:47:20 +0000 UTC 26d default <none>
nginx-example-backups-20210404203557 Completed 0 0 2021-04-04 20:35:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404203057 Completed 0 0 2021-04-04 20:30:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404202557 Completed 0 0 2021-04-04 20:25:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404202057 Completed 0 0 2021-04-04 20:20:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404201557 Completed 0 0 2021-04-04 20:15:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404201057 Completed 0 0 2021-04-04 20:10:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404200830 Completed 0 0 2021-04-04 20:08:30 +0000 UTC 27d default <none>
nginx-example-backups-20210404193557 Completed 0 0 2021-04-04 19:35:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404193057 Completed 0 0 2021-04-04 19:30:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404192557 Completed 0 0 2021-04-04 19:25:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404192057 Completed 0 0 2021-04-04 19:20:57 +0000 UTC 27d default <none>
nginx-example-backups-20210404191557 Completed 0 0 2021-04-04 19:15:57 +0000 UTC 26d default <none>
nginx-example-backups-20210404191057 Completed 0 0 2021-04-04 19:10:57 +0000 UTC 26d default <none>
nginx-example-backups-20210404190557 Completed 0 0 2021-04-04 19:05:57 +0000 UTC 26d default <none>
nginx-example-backups-20210404190013 Completed 0 0 2021-04-04 19:00:13 +0000 UTC 26d default <none>
```

En general recuperamos a partir de la última copia de seguridad realizada, pero podemos seleccionar la copia específica desde la que restaurar. Si lo indicamos, también podemos realizar la recuperación en un *Namespace* **diferente** al de la copia original.

Restauramos a partir de la última copia realizada:

> Definimos el nombre de la copia específica de la que queremos recuperar en una variable de entorno: `$BACKUP2RESTORE`

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-restore-create-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-restore-create
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          env:
            - name: BACKUP2RESTORE
              value: "nginx-example-backups-20210404203557"
          command: ["/bin/sh"]
          args: ["-c", "velero restore create --from-backup $BACKUP2RESTORE"]
```

Consultando los logs del *Job*:

```bash
Restore request "nginx-example-backups-20210404203557-20210407190834" submitted successfully.
Run `velero restore describe nginx-example-backups-20210404203557-20210407190834` or `velero restore logs nginx-example-backups-20210404203557-20210407190834` for more details.
```

Al cabo de un instante, cuando ha finalizado la restauración a partir de la copia de seguridad, se han creado todos los recursos eliminados y la aplicación vuelve a estar disponible:

```bash
$ curl http://nginx.k3s.lab:31142
...
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
...
```

Tanto el *Namespace* como todos los recursos desplegados por la aplicación vuelven a estar disponibles (incluídos los creados automáticamente por Kubernetes, como `configmap/kube-root-ca.crt`, `secret/default-token-fj9gv`, etc...):

```bash
$ kubectl get all,secret,cm,sa -n nginx-example
NAME                                   READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-57d5dcb68-jc7jx   1/1     Running   0          24m
pod/nginx-deployment-57d5dcb68-jbbjj   1/1     Running   0          24m

NAME               TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/my-nginx   NodePort   10.43.207.52   <none>        80:31142/TCP   24m

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   2/2     2            2           24m

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-57d5dcb68   2         2         2       24m

NAME                         TYPE                                  DATA   AGE
secret/default-token-fj9gv   kubernetes.io/service-account-token   3      24m

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      24m

NAME                     SECRETS   AGE
serviceaccount/default   1         24m
```

Si lo deseamos, podemos consultar los logs del *Job* de restauración para obtener el detalle de todas las acciones realizadas para recuperar la copia:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: backup-nginx
  namespace: velero-cli
  generateName: velero-restore-get-
spec:
  template:
    metadata:
      labels:
        app: backup-nginx
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-restore-get
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          env:
            - name: RESTORE_NAME
              value "nginx-example-backups-20210404203557-20210407190834"
          command: ["/bin/sh"]
          args: ["-c", "velero restore logs $RESTORE_NAME"]
```

```bash
time="2021-04-07T19:08:34Z" level=info msg="starting restore" logSource="pkg/controller/restore_controller.go:467" restore=velero/nginx-example-backups-20210404203557-20210407190834
...
time="2021-04-07T19:08:35Z" level=info msg="Attempting to restore Endpoints: my-nginx" logSource="pkg/restore/restore.go:1107" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Restoring resource 'endpointslices.discovery.k8s.io' into namespace 'nginx-example'" logSource="pkg/restore/restore.go:724" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Getting client for discovery.k8s.io/v1beta1, Kind=EndpointSlice" logSource="pkg/restore/restore.go:768" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Attempting to restore EndpointSlice: my-nginx-r8ggk" logSource="pkg/restore/restore.go:1107" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Restoring resource 'services' into namespace 'nginx-example'" logSource="pkg/restore/restore.go:724" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Getting client for /v1, Kind=Service" logSource="pkg/restore/restore.go:768" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Executing item action for services" logSource="pkg/restore/restore.go:1002" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Attempting to restore Service: my-nginx" logSource="pkg/restore/restore.go:1107" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Waiting for all restic restores to complete" logSource="pkg/restore/restore.go:488" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Done waiting for all restic restores to complete" logSource="pkg/restore/restore.go:504" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Waiting for all post-restore-exec hooks to complete" logSource="pkg/restore/restore.go:508" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="Done waiting for all post-restore exec hooks to complete" logSource="pkg/restore/restore.go:516" restore=velero/nginx-example-backups-20210404203557-20210407190834
time="2021-04-07T19:08:35Z" level=info msg="restore completed" logSource="pkg/controller/restore_controller.go:482" restore=velero/nginx-example-backups-20210404203557-20210407190834
```

## Conclusión

Velero es una de esas herramientas que hace una cosa y la hace bien; a través del uso de unos pocos *Custom Resources*, Velero realiza copias de seguridad de manera sencilla y a la vez, flexible, permitiendo incluir o excluir elementos durante el *backup* o los *restores*.

La posibilidad de programar las copias de seguridad como una tarea usando un *Job* permite integrar esta la configuracón de los *backups* en el proceso de despliegue de cualquier aplicación en un entorno productivo.

Para las tareas de consulta de las copias disponibles lanzar un *Job* puede parece un poco *overkill*, pero permte tener un "registro" de cualquier acción realizada en el clúster y se puede integrar en la metodología "GitOps".

Una mejora a lo expuesto en estas entradas sobre Velero sería ajustar los permisos de la *ServiceAccount* `velerocli` usada por la herramienta de línea de comandos **velero** en los ejemplos para que únicamente permita realizar acciones sobre los *Custom Resources* definidos por Velero. La documentación oficial también describe cómo ajustar los permisos de Velero (la parte "servidor") para que no sea necesario proporcionar permisos de `cluster-admin`: [Run Velero more securely with restrictive RBAC settings](https://velero.io/docs/v1.5/rbac/).

El único *inconveniente*, por ponerle alguna pega a Velero, es que no es posible prescindir de la herramienta de comandos **velero** para crear o configurar los *Custom Resources* desplegados, como se indica en [API types](https://velero.io/docs/v1.5/api-types/):

> Here’s a list the API types that have some functionality that you can only configure via json/yaml vs the velero cli (hooks)

Pese a este inconveniente menor, la funcionalidad y la simplicidad con lo que Velero permite realizar copias de seguridad y restauraiones del clúster convierte a [Velero](https://velero.io/) en una herramienta imprescindible.

