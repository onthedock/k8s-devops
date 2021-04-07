# Instalación de Velero

[Velero](htps:/velero.io) es una herramienta de código abierto que permite realizar copias de seguridad, restaurarlas y migrar recursos de Kubernetes entre clústers (lo que también permite recuperar un clúster en caso de desastre).

Velero soporta diferentes proveedores en los que almacenar las copias de seguridad que realiza. La lista completa y actualizada se encuentra en [Providers](https://velero.io/docs/v1.5/supported-providers/). En mi caso, voy a utilizar MinIO, que es compatible con AWS S3 y que tengo desplegado localmente en Kubernetes.

Velero despliega *Custom Resource Definitions* en el clúster que definen *backups*, *restores*, etc... Para interaccionar con Velero (servidor/operador), se proporciona la herramienta de línea de comandos **velero**.

Como en el caso de MinIO, vamos a desplegar **velero** (CLI) en un contenedor y realizaremos la configuración de los *backup*, etc en Velero usando *Jobs* en Kubernetes (*a lo GitOps*).

## Construcción de la imagen con **velero** (CLI)

A diferencia de lo que sucede con **mc**, el cliente de MinIO, **velero** no se ofrece como imagen de contenedor. Por tanto, el primer paso es construir la imagen.

### Prerequisitos

En la documentación de Velero [Basic Install](https://velero.io/docs/v1.5/basic-install/) se indica como prerequisito que **kubectl** esté instalado localmente. En realidad lo que se necesita es disponer de un fichero `KUBECONFIG` que permita conectar con el clúster.

En nuestro escenario, en el que vamos a desplegar **velero** (la herramienta de línea de comandos) en el clúster, no es necesario disponer de **kubectl** ni del fichero de configuración.

La API de Kubernetes es accesible internamente -desde un *Pod*- a través de `kubernetes.default.svc`, como se describe en [Accessing the Kubernetes API from a Pod](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/).

Para validarnos contra la API de Kubernetes, usaremos una *Service Account* con los permisos necesarios (`cluster-admin`).

### Descarga de **velero**

Descargamos la última versión estable de **velero** en la subcarpeta `./velero-cli`. Para ello, podemos usar el *script*:

```bash
#!/bin/bash
REPO_ROOT_DIR=${PWD}
VELERO_RELEASE=v1.5.3
echo $VELERO_RELEASE
echo "Downloading Velero (release $VELERO_RELEASE)..."
curl -LO https://github.com/vmware-tanzu/velero/releases/download/$VELERO_RELEASE/velero-$VELERO_RELEASE-linux-amd64.tar.gz

echo "Unpacking ..."
tar xzvf velero-$VELERO_RELEASE-linux-amd64.tar.gz 
echo "Moving velero to $REPO_ROOT_DIR/velero-cli/ ..."
mv velero-$VELERO_RELEASE-linux-amd64/velero $REPO_ROOT_DIR/velero-cli/velero

echo "Cleaning ..."
rm -rf velero-$VELERO_RELEASE-linux-amd64/
rm -i velero-$VELERO_RELEASE-linux-amd64.tar.gz
```

### `Dockerfile`

Generamos un `Dockerfile` usando como imagen base la última versión de Alpine Linux:

```Dockerfile
FROM alpine
COPY ./velero-cli/velero /usr/local/bin/velero
RUN chmod +x /usr/local/bin/velero
CMD ["velero"]
```

### Construcción de la imagen

Generamos la imagen mediante:

```bash
$ docker build -t velero-cli:1.5.3 .
Sending build context to Docker daemon  65.54MB
Step 1/4 : FROM alpine
latest: Pulling from library/alpine
ca3cd42a7c95: Pull complete 
Digest: sha256:ec14c7992a97fc11425907e908340c6c3d6ff602f5f13d899e6b7027c9b4133a
Status: Downloaded newer image for alpine:latest
 ---> 49f356fa4513
Step 2/4 : COPY ./velero-cli/velero /usr/local/bin/velero
 ---> 4eb0261040aa
Step 3/4 : RUN chmod +x /usr/local/bin/velero
 ---> Running in 13af301b8afa
Removing intermediate container 13af301b8afa
 ---> 94da4227ffaf
Step 4/4 : CMD ["velero"]
 ---> Running in 71a3b244cfef
Removing intermediate container 71a3b244cfef
 ---> a7ec148f22f3
Successfully built a7ec148f22f3
Successfully tagged velero-cli:1.5.3
```

Una vez construida, la subimos a DockerHub como [xaviaznar/velero-cli:1.5.3](https://hub.docker.com/r/xaviaznar/velero-cli/):

```bash
$ docker tag velero-cli:1.5.3 xaviaznar/velero-cli:1.5.3
$ docker login 
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: xaviaznar                  
Password: 
WARNING! Your password will be stored unencrypted in /home/operador/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
$ docker push xaviaznar/velero-cli:1.5.3
The push refers to repository [docker.io/xaviaznar/velero-cli]
60362a3dc47f: Pushed 
8ea3b23f387b: Mounted from library/alpine 
1.5.3: digest: sha256:8b818af91a5805e7baf2dd3ad7adfd2b2a2cc0cb56bf0c8d01852f77670296af size: 952
```

## Despliegue de Velero en Kubernetes

Empezamos creando un *Namespace* dedicado `velero-cli` para la herramienta **velero**:

> Velero se despliegua por defecto en un *Namespace* llamado `velero`.

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: velero-cli
```

Dentro de cada *Namespace* se genera una *ServiceAccount* llamada `default`. Los *Pods* creados en un *Namespace* usan la *ServiceAccount* `default` si no se especifica una en la definición del *Pod*. El [Service Account Admission Controller](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#serviceaccount-admission-controller) se encarga de montar un *token* que proporciona acceso a la API de Kubernetes a esta cuenta `default`.

La *ServiceAccount* `default` sólo tiene permisos dentro del propio *Namespace* en la que se encuentra, por lo que no dispone de los permisos necesarios para desplegar los *Custom Resource Definitions* que requiere Velero para su instalación.

Para realizar la instalación, definimos la *ServiceAccount* `velerocli`:

```yaml
---
kind: ServiceAccount
apiVersion: v1
metadata:
  namespace: velero-cli
  name: velerocli
  labels:
    app: velero-cli
```

Para asociar los permisos del rol `cluster-admin` a la *ServiceAccount*  `velerocli`, definimos un *ClusterRoleBinding*:

```yaml
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: velerocli-cluster-admin-crb
  labels:
    app: velero-cli
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: velerocli
  namespace: velero-cli
```

Todos los parámetros necesarios para realizar la instalación de Velero se pasan como argumentos al comando `velero install`, excepto el fichero que contiene las credenciales de acceso a la ubicación donde se almacenan las copias de seguridad (en nuestro caso, MinIO).

Para poder reutilizar el *Job*, todos los parámetros los definimos como variables de entorno, que cargamos desde un *ConfigMap*.
El fichero `--secret-file` (que contiene las credenciales para MinIO) lo montamos como un volumen a partir de otro *ConfigMap*.

Para poder usar la sustitución de variables ejecutamos el comando `velero install` desde una *shell* (`/bin/sh`, [ash](https://en.wikipedia.org/wiki/Almquist_shell), en Alpine Linux).

### Fichero de variables para la instalación de Velero

Usamos la opción descrita en [Configure all key-value pairs in a ConfigMap as container environment variables](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables) para definir un *ConfigMap* con todos las variables de entorno que usaremos en el comando `velero install`:

```yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  namespace: velero-cli
  name: velero-install-config
  labels:
    app: velero-cli
data:
  PROVIDER: aws
  PLUGIN: velero/velero-plugin-for-aws:v1.1.0
  BUCKET: velero-backup
  BACKUP_LOCATION_CONFIG_URL: http://minio.minio.svc:9000
  SNAPSHOT_LOCATION_CONFIG_URL: http://minio.minio.svc:9000 
```

### *ConfigMap* con las credenciales

El fichero de credenciales usado por Velero debe tener la estructura:

```ini
[default]
aws_access_key_id=ACCESSKEYEXAMPLE123
aws_secret_access_key=wdvb5rtghn76yujm
```

Generamos la definición del *ConfigMap* usando la opción `dry-run`:

```bash
$ kubectl -n velero-cli create configmap credentials-minio \
> --from-file=credentials-minio --dry-run=client \ 
> -o yaml | tee velero-cli-cm-minio-credentials.yaml
apiVersion: v1
data:
  minio-credentials: |-
    [default]
    aws_access_key_id=ACCESSKEYEXAMPLE123
    aws_secret_access_key=wdvb5rtghn76yujm
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: credentials-minio
  namespace: velero-cli
```

Al fichero generado añadimos la etiqueta `app: velero-cli`:

```yaml
apiVersion: v1
data:
  credentials-minio: |-
    [default]
    aws_access_key_id=ACCESSKEYEXAMPLE123
    aws_secret_access_key=wdvb5rtghn76yujm
kind: ConfigMap
metadata:
  name: credentials-minio
  namespace: velero-cli
  labels:
    app: velero-cli
```

## Instalación de Velero (desde un *Job*)

Después de haber preparado los diferentes bloques del *Job*, ya podemos lanzar la instalación de Velero.

En el caso de MinIO, no tiene sentido especificar la región en la que se encuentra el *bucket* (a diferencia de S3), pero es necesario proporcionar un valor. Usando como referencia el ejemplo de [Quick start evaluation install with Minio](https://velero.io/docs/v1.5/contributions/minio/), especificamos `region=minio`.

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  labels:
      app: velero-cli
  namespace: velero-cli
  name: velero-cli-install
spec:
  template:
    metadata:
      labels:
        app: velero-cli
    spec:
      serviceAccount: velerocli
      restartPolicy: Never
      containers:
        - name: velero-cli-install
          image: docker.io/xaviaznar/velero-cli:1.5.3
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: velero-install-config
          command: ["/bin/sh"]
          args: ["-c", "velero install --provider $PROVIDER --plugins $PLUGIN --bucket $BUCKET --backup-location-config region=minio,s3ForcePathStyle='true',s3Url=$BACKUP_LOCATION_CONFIG_URL --use-volume-snapshots=false --secret-file /tmp/minio-credentials"]
          volumeMounts:
            - name: cm-file-minio-credentials
              mountPath: /tmp/
      volumes:
        - name: cm-file-minio-credentials
          configMap:
            name: minio-credentials
```

Revisando los logs del *Pod* generado por el *Job* de instalación, validamos que Velero se ha desplegado correctamente:

```bash
...
CustomResourceDefinition/restores.velero.io: created
CustomResourceDefinition/schedules.velero.io: attempting to create resource
CustomResourceDefinition/schedules.velero.io: created
CustomResourceDefinition/serverstatusrequests.velero.io: attempting to create resource
CustomResourceDefinition/serverstatusrequests.velero.io: created
CustomResourceDefinition/volumesnapshotlocations.velero.io: attempting to create resource
CustomResourceDefinition/volumesnapshotlocations.velero.io: created
Waiting for resources to be ready in cluster...
Namespace/velero: attempting to create resource
Namespace/velero: created
ClusterRoleBinding/velero: attempting to create resource
ClusterRoleBinding/velero: created
ServiceAccount/velero: attempting to create resource
ServiceAccount/velero: created
Secret/cloud-credentials: attempting to create resource
Secret/cloud-credentials: created
BackupStorageLocation/default: attempting to create resource
BackupStorageLocation/default: created
VolumeSnapshotLocation/default: attempting to create resource
VolumeSnapshotLocation/default: created
Deployment/velero: attempting to create resource
Deployment/velero: created
Velero is installed! ⛵ Use 'kubectl logs deployment/velero -n velero' to view the status.
```

Revisando los logs del *Pod* de Velero como se indica en la salida, observamos mensajes informativos (ningún error):

```bash
...
time="2021-04-03T21:24:12Z" level=info msg="No backup locations were ready to be verified" controller=backupstoragelocation logSource="pkg/controller/backupstoragelocation_controller.go:120"
time="2021-04-03T21:24:34Z" level=info msg="Checking for existing backup locations ready to be verified; there needs to be at least 1 backup location available" controller=backupstoragelocation logSource="pkg/controller/backupstoragelocation_controller.go:58"
time="2021-04-03T21:24:34Z" level=info msg="No backup locations were ready to be verified" controller=backupstoragelocation logSource="pkg/controller/backupstoragelocation_controller.go:120"
```
