# Instalación de MinIO

> La forma "oficial" de desplegar Minio en Kubernetes es a través del [operador de MinIO](https://docs.min.io/docs/deploy-minio-on-kubernetes.html).

Vamos a generar un *Deployment* con un único Pod, en el que montaremos un volumen de datos para que MinIO pueda usarlo como almacenamiento.
No vamos a considerar alta disponibilidad ni nada por el estilo. Usaremos la *default storageClass* definida en el clúster.

## Namespace

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: minio
```

## Almacenamiento

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: minio
  name: minio-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

## Deployment

```yaml
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: minio
  namespace: minio
spec:
  replicas: 1 
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: minio/minio
          command: ["minio"]
          args: ["server", "/data"]
          ports:
            - name: web-ui
              containerPort: 9000 
          volumeMounts:
            - name: minio-data
              mountPath: /data
      volumes:
        - name: minio-data
          persistentVolumeClaim:
            claimName: minio-data
```

MinIO arranca con las credenciales por defecto: `minioadmin` como usuario y *password*.

Para especificar valores personalizados, usamos las variables de entorno `MINIO_ROOT_USER` y `MINIO_ROOT_PASSWORD`.
Modificamos la definición del *Deployment* para añadir, antes de la línea donde especificamos el `command` a ejecutar en el contendor, las variables de entorno:

```yaml
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
```

Para no tener el nombre del usuario en la definición del *Deployment* y el *password* en un *secret*, obtenemos los dos valores del *secret*.

Creamos el secret `minio-secret` con las claves especificadas usando la opción `dry-run=client`:

```bash
kubectl create secret generic minio-secret -n minio \
--from-literal=minio-root-user=ACCESSKEYEXAMPLE123 \
--from-literal=minio-root-password=wdvb5rtghn76yujm -o yaml --dry-run=client | tee minio-secret.yaml
```

Así obtenemos el *secret* con los valores ya "ofuscados":

```yaml
apiVersion: v1
data:
  minio-root-password: d2R2YjVydGdobjc2eXVqbQ==
  minio-root-user: QUNDRVNTS0VZRVhBTVBMRTEyMw==
kind: Secret
metadata:
 name: minio-secret
 namespace: minio
type: Opaque
```

## Servicio

Exponemos el servicio como *NodePort* durante la fase de pruebas, cambiándolo posteriormente a `ClusterIP` (usaremos MinIO como *backend* de almacenamiento para las copias de segurida):

```yaml
--- 
kind: Service
apiVersion: v1
metadata:
  namespace: minio
  name: minio
spec:
  type: NodePort
  selector:
    app: minio
  ports:
    - name: web-ui
      protocol: TCP
      port: 9000
```

Podemos consultar el puerto que ha asignado Kubernetes mediante:

```bash
$ kubectl get svc -n minio
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
minio   NodePort   10.43.117.250   <none>        9000:30712/TCP   3d20h
```

La interaz web de MinIO es accesible a través de <http://${IP-nodo}:32712>.

### Versiones

- MinIO: 2021-03-26T00:00:41Z (linux/amd64)
- Kubernetes:
    <!-- markdownlint-disable MD007 -->
    - Client Version: v1.20.5
    - Server Version: v1.20.4+k3s1
    <!-- markdownlint-enable MD007 -->
