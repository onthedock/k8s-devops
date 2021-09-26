# Login de usuario con certificado en Kubernetes

En Kubernetes no existe el concepto de usuario; sólo se confía en quien presente un certificado firmado por la CA del clúster.

Para obtener los certificados de la CA, lo más sencillo es acceder a un nodo *server*; los certificados (`ca.cert` y `ca.key`) se encuentran en `/etc/kubernetes/pki/`.

> En K3s los certificados de la CA de Kubernetes se encuentran en `/var/lib/rancher/k3s/server/tls/` y se denominan `server-ca.crt` y `server-ca.key`.

## Crear certificado de usuario

Para autenticar un nuevo usuario, debemos generar un certificado para el usuario. Para ello, usamos **openssl**.

> En el documento de referencia se genera un contenedor en Docker basado en Alpine en el que se instala `openssl` :
>
> ```bash
> docker run -it -v ${PWD}:/work -w /work -v ${HOME}:/root/ --net host alpine sh
>  
> apk add openssl
> ```

Generamos una clave privada para `Bob Smith`:

```bash
openssl genrsa -out bob.key 2048
```

El siguiente paso es generar la *certificate signing requst (CSR)* y determinar a qué grupo pertenecerá el usuario.

Suponemos que vamos a asignar al usuario al grupo `Shopping`. Este grupo viene determinado por el campo `O=` en el certificado generado.

```bash
openssl req -new -key bob.key -out bob.csr -subj "/CN=Bob Smith/O=Shopping"
```

Usando los certificados de la CA, firmamos el *CSR* del usuario y establecemos una fecha máxima de validez para el certificado.

```bash
openssl x509 -req -in bob.csr -out bob.crt \
  -CA ca.crt -CAkey ca.key -CAcreateserial  -days 1
```

## Crear el fichero *kubeconfig*

El fichero `kubeconfig` tiene tres partes:

- usuario
- clúster
- contexto

Para evitar interferir con nuestro fichero de configuración, definimos:

```bash
export KUBECONFIG=~/.kube/bobconfig
```

### Especificar el usuario

```bash
kubectl config set-credentials bob --client-certificate=bob.crt --client-key=bob.key --embed-certs=true
```

### Especificar el clúster

```bash
kubectl config set-cluster <NOMBRE_DEL_CLUSTER> --server=<URL_DEL_CLUSTER> --certificate-authority=ca.crt --embed-certs=true
```

### Especificar el contexto

El contexto indica la combinación de usuario y clúster:

```bash
kubectl config set-context <NOMBRE_DEL_CONTEXTO> --cluster=<NOMBRE_DEL_CLUSTER> --namespace=<DEFAULT_NAMESPACE> --user=bob
```

> En mi caso, al no haberse especificado ningún contexto como el contexto actual, kubectl intentaba conectar contra `localhost:6433`; la solución ha sido definir el contexto creado como el *current context*: `kubectl config use-context vagrant-k3s`.

Establecemos el contexto recién creado como el contexto actual:

```bash
kubectl config use-context <NOMBRE_DE_CONTEXTO>
```

## Acceso al clúster

Si Bob intenta acceder al clúster, obtendrá un error, ya que no tiene ningún permiso asociado (el rol `manage-pods` todavía no existe).

```bash
$ kubectl get pods
error: You must be logged in to the server (Unauthorized)
```

> En mi caso el error que obtengo es `Unable to connect to the server: x509: certificate signed by unknown authority`. Comparando el valor del certificado almacenado en el fichero `~/.kube/config` funcional (para el usuario `admin`) y el generado mediante la guía, veo que en el caso de K3s, el certificado de la CA almacenado corresponde con el contenido de `server-ca.crt` (*encondeado* en base64)). Este es el certificado que hay que usar para firmar el certificado de usuario.

### Permisos para el usuario

Definimos el *role* `manage-pods` especificando las acciones que se pueden realizar sobre los recursos del clúster:

> El namespace indicado debe existir en el clúster. En caso contrario, se recibe el mensaje de error `Error from server (NotFound): error when creating "manage-pods-role.yaml": namespaces "shopping" not found`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: shopping
  name: manage-pods
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "watch", "list", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "watch", "list", "delete", "create"]
```

Creamos el rol:

```bash
kubectl create -f manage-pods-role.yaml
```

Para que Bob obtenga los permisos definidos en el rol `manage-pods`, debemos asociarlo mediante un *role binding*:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: manage-pods
  namespace: shopping
subjects:
- kind: User
  name: "Bob Smith"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: manage-pods
  apiGroup: rbac.authorization.k8s.io
```

Referencias:

- [Introduction to Kubernetes: RBAC](https://github.com/marcel-dempers/docker-development-youtube-series/tree/master/kubernetes/rbac), 14/09/2021 by Marce Dempers (That Devops Guy)
- [Provisioning Users and Groups for Kubernetes](https://dev.to/focusedlabs/provisioning-users-and-groups-for-kubernetes-4251), 1/1/2020 by FocusedLabs.io. El artículo indica una vía más "kubernetes" de hacer los mismo.
