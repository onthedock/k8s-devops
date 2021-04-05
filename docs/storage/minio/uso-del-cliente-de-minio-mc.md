# Uso del cliente de MinIO **mc**

`mc` es el *cliente* para interaccionar con Minio y los *buckets*.

`mc` se distribuye como un contenedor [minio/mc](https://hub.docker.com/r/minio/mc), por lo que he pensado en que las acciones a realizar se pueden realizar a través de *Jobs*. Como alternativa, se puede lanzar un Pod donde iniciar una sesión interactiva y crear el *bucket* de forma manual o usar el interfaz web de MinIO.

## Configuración de un *alias*

`mc` conecta con el *servicio* de MinIO usando un alias; el equivalente para conectar con un *bucket* en AWS sería usar el *alias* **s3**.

Empezamos por definir un volumen donde `mc` guardará la configuración:

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: minio
  name: minio-config
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Mi
```

La configuración de **mc** se almacena en `~/.mc/`; como el usuario en el contenedor `minio/mc` es **root**, montamos el volumen en `/root/.mc`.

## Crear un *alias* para el servidor de MinIO

Para simplificar la interacción entre el cliente de MinIO y el servidor, podemos asociar un *alias* al *endpoint* de MinIO. Por defecto, el cliente de MinIO tiene definidos -aunque no están configurados- *alias* para Google Cloud Storage (`gcs`), AWS S3 (`s3`) y un sandbox público de pruebas (`play`).

En nuestro caso, vamos a denominar `minio` al servidor de MinIO desplegado en Kubernetes.

Definimos un *Job* para crear el *alias*:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: minio
  generateName: mc-alias-set-
spec:
  template:
    metadata:
      labels:
        app: minio
    spec:
      restartPolicy: Never
      containers:
        - name: mc-alias-set
          image: minio/mc
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-user
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-password
          command: ["mc"]
          args: ["alias", "set", "minio", "http://minio:9000", "--debug"]
```

> El *Job* se completa con éxito, pero el *alias* creado no contiene las credenciales de acceso a MinIO (debido a limitaciones de `mc`). Sigue leyendo…

A destacar algunos detalles:

- El *Job* usa `metadata.generatedName` y no `metadata.name`, lo que permite lanzar el *Job* múltipes veces, ya que en cada ejecución el *Job* tiene un nombre diferente. Si usas `metadata.name`, la segunda ejecución del *Job* falla porque ya existe un *Job* con el mismo nombre.
- Al usar `metadata.generatedName` no puedes usar `kubectl apply` para lanzar el *Job*; tienes que usar `kubectl create`.
- El nombre del *alias* está fijado (`minio`); se podría obtener el valor del *alias* añadiendo un campo adicional en el *Secret* del que obtenemos las credenciales, por ejemplo…
- Si MinIO está desplegado en otro *Namespace* o fuera de Kubernetes, debes ajustar la URL de MinIO.

### Limitaciones del cliente **mc** de MinIO

Revisando la documentación del cliente de MinIO **mc** [MinIO Client Complete Guide](https://docs.min.io/docs/minio-client-complete-guide.html), vemos que se indica que **mc** sólo acepta las credenciales como argumento o a través de *standard input*; es decir, no recoge las credenciales si se especifican como variables de entorno.

Al ejecutar el *Job* anterior, se crea el *alias* `minio`, pero las credenciales están en blanco:

```yaml
...
minio
  URL       : http://minio:9000
  AccessKey : 
  SecretKey : 
  API       : 
  Path      : auto
...
```

Esto es debido al comportamiento actual de **mc**, ignorando las variables de entorno, aunque estén definidas.

Especificando las variables de entorno como argumentos del comando ejecutado por el *Job* anterior, tampoco funciona:

```yaml
...
command: ["mc"]
args: ["alias", "set", "minio", "http://minio:9000", $MINIO_ROOT_USER , $MINIO_ROOT_PASSWORD ,"--debug"]
```

En este caso, `$MINIO_ROOT_USER` y `$MINIO_ROOT_PASSWORD` se interpretan como cadenas literales, no se sustituyen con los valores de las variables de entorno.

Tampoco funcionan el resto de opciones indicadas en la documentación: **Pipe from STDIN**, **Specify temporary host configuration through environment variable**, con `export MC_HOST_<alias>=https://<Access Key>:<Secret Key>@<YOUR-S3-ENDPOINT>`).

### Plan B: usar un *script*

Después de comprobar que no es posible configurar el *alias* usando directamente el cliente de MinIO **mc**, modificamos el comando ejecutado por el *Job* para ejecutar **bash** en el contenedor:

```yaml
...
command: ["/bin/bash"]
args:
  - "-c"
  - "mc alias set minio http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD"
```

A través de los logs del *Pod* generado por el *Job*, vemos que de esta forma sí que se configura el *alias* para MinIO:

```bash
$ kubectl logs mc-alias-set-832smd-8md3l -n minio
...
minio
URL : http://minio:9000
AccessKey : ACCESSKEYEXAMPLE123
SecretKey : wdvb5rtghn76yujm
API : s3v4
Path : auto
...
```

### Persistiendo la configuración del cliente de MinIO **mc**

Una vez hemos validado que el *Job* configura el *alias* para **mc** correctamente, modificamos la definición del *Job* para montar el *PVC* definido al principio del artículo; para ello, añadimos el bloque `volumeMounts` montando el *PVC* en `/root/.mc`:

```yaml
...
volumeMounts:
  - name: minio-config
    mountPath: "/root/.mc"
...
```

También añadimos la referencia al volumen (en `spec.template.spec`):

```yaml
...
volumes:
  - name: minio-config
    persistentVolumeClaim:
      claimName: minio-config
```

Ejecutando de nuevo el *Job* se debe generar el *alias* y guardarse en el *Persistent Volume Claim* montado. Lo validamos creando un *Job* que consulte los *alias* definidos:

```yaml
---
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: minio
  generateName: mc-alias-list-
spec:
  template:
    metadata:
      labels:
        app: minio
    spec:
      restartPolicy: Never
      containers:
        - name: mc-alias-list
          image: minio/mc
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-user
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-password
          command: ["mc"]
          args: ["alias", "list", "--debug"]
          volumeMounts:
            - name: minio-config
              mountPath: "/root/.mc"
      volumes:
        - name: minio-config
          persistentVolumeClaim:
            claimName: minio-config
```

En los logs observamos la configuración del *alias* creado por el *Job* definido anteriormente:

```bash
$ kubectl logs mc-alias-list-9l9md-k6w2h -n minio
...
minio
URL : http://minio:9000
AccessKey : ACCESSKEYEXAMPLE123
SecretKey : wdvb5rtghn76yujm
API : s3v4
Path : auto
...
```

---

## Crear el *bucket*

Para crear el *bucket* desde un *Job* podemos usar la "sintaxis" del *script* o directamente el cliente de MinIO **mc**. Prefiero usar directamente el cliente de MinIO en este caso.

Copiamos la definición del *Job* para listar los *alias* y modificamos el comando y los argumentos para crear el *bucket* en MinIO:

```yaml
kind: Job
apiVersion:  batch/v1
metadata:
  namespace: minio
  name: mc-makebucket-velero-backups
spec:
  template:
    metadata:
      labels:
        app: minio
    spec:
      restartPolicy: Never
      containers:
        - name: mc-makebucket-velero-backups
          image: minio/mc
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-user
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-secret
                  key: minio-root-password
          command: ["mc"]
          args: ["mb", "mino/velero-backups"]
          volumeMounts:
            - name: minio-config
              mountPath: "/root/.mc"
      volumes:
        - name: minio-config
          persistentVolumeClaim:
            claimName: minio-config
```

En los logs del *Job* comprobamos que se ha creado el *bucket* correctamente:

```bash
$ kubectl logs mc-makebucket-velero-backup-fwxg7 -n minio
Bucket created successfully `minio/velero-backups`.
```

En este caso, en la definición del *Job* he usado `metadata.name` y no `metadata.generatedName`; la creación de un *bucket* sólo debe realizarse una vez. Si lanzamos de nuevo el mismo *Job*, como la definición no ha cambiado, el *Job* no se ejecuta de nuevo:

```bash
$ kubectl -n minio apply -f minio-mc-job-makebucket-velero-backups.yaml 
job.batch/mc-makebucket-velero-backups unchanged
```
