# Crear usuarios en Kubernetes (y en K3s)

En Kubernetes no existe el concepto de usuario; sólo se confía en quien presente un certificado firmado por la CA del clúster.

Para obtener los certificados de la CA, lo más sencillo es acceder a un nodo *server*; los certificados (`ca.cert` y `ca.key`) se encuentran en `/etc/kubernetes/pki/`.

> Existe otra opción que pasa or generar un objeto `CertificateSigningRequest` para firmar el certificado de usuario.

El proceso implica generar un certificado al usuario, solicitar que lo firme la *Certificate Authority* del clúster y después autenticarse con él.

Para poder autenticarse en el clúster, necesitamos configurar un cliente, por ejemplo creando un fichero `kubeconfig` para **kubectl**.

Finalmente, el nuevo usuario debe estar autorizado a realizar algunas acciones en el clúster; para ello definiremos un conjunto de permisos en un *Role* o un *ClusterRole* y lo asociaremos al usuario mediante un *RoleBinding* (o un *ClusterRoleBinding*).

## Creación del certificado de usuario

Para generar el certificado de usuario, usamos *openssl*:

```bash
openssl genrsa -out ${USER}.key 2048
```

El comando genera un fichero `${USER}.key` que contiene una clave privada:

```bash
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3UgD2srmh6W3VUsG2yEWRVeJ2wDmTdgnQmhgM0EYltMrNm+T
hV5xbWGsBIUhKc4iHLsRyAAKWSHxB08tgz0W9+jrRddBAqA+g3g15GK1Ro6j9QfI
...
5L/rOxsKs+AF5VHf+opkBTbv+ymTuKKtf9Lidpg5q0wvRryHh+Atbw==
-----END RSA PRIVATE KEY-----
```

Esta clave privada identifica al usuario (solo él la posee).

## Solicitud de firma del certificado de usuario (*Certificate Signing Request*)

Generamos una petición de firma del certificado mediante el comando:

```bash
openssl req -new -key ${USER}.key \
    -out ${USER}.csr \
    -subj "/CN=${USER}/O=${GROUP}"
```

El contenido del campo `/CN=` es lo que identifica al usuario en Kubernetes. Opcionalmente, opdemos indican el *grupo* (o grupos) al que pertenece el usuario.

El comando genera el fichero `${USER}.csr` que contiene la petición de firma del certificado:

```bash
-----BEGIN CERTIFICATE REQUEST-----
MIICVDCCATwCAQAwDzENMAsGA1UEAwwEeGF2aTCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBAN1IA9rK5oelt1VLBtshFkVXidsA5k3YJ0JoYDNBGJbTKzZv
...
XNDmUwoLsYtTY3rdlFDI5t7Dm2WitLrLu1TACdZWFvOK9Hb7OguNWIkUBLq1ng52
ddSpt9cBhFtkoLTMVF1XewQIYXoRIMXw
-----END CERTIFICATE REQUEST-----
```

## Firma del fichero *CSR*

Hasta ahora, el usuario ha generado un certificado que lo identifica y ha creado el fichero con la solicitud de firma del certificado.

Para realizar las siguientes acceiones es necesario tener acceso a la clave privada de la entidad certificadora (*CA*) de Kubernetes, por lo que debe realizarlos un administrador del clúster.

### Firma del fichero **CSR**

En K3s los certificados de la entidad certificadora del clúster se encuentran en `/var/lib/rancher/k3s/server/tls/`. A diferencia de lo que sucede en Kubernetes, en K3s tenemos un par de claves para la firma de certificados de usuario `client-ca.crt` y `client-ca.key` y otro para el API Server (`server-ca.crt`).

> En Kubernetes sólo hay un certificado, `ca.crt` y `ca.key`, que se encuentran en `/etc/kubernetes/pki/`

Para realizar la firma del certificado de usuario, usamos el par de claves `client-ca.*`:

```bash
openssl x509 -req -in ${USER}.csr -out ${USER}.crt \
    -CA client-ca.crt -CAkey client-ca.key \
    -CAcreateserial -days $days_until_expiration
```

El valor para el parámetro `-days` indica la duración de la validez del certificado emitido.

Si el comando tiene éxito, la salida será similar a:

```bash
Signature ok
subject=CN = ${USER}
Getting CA Private Key
```

El comando genera el fichero `${USER}.crt`:

```bash
-----BEGIN CERTIFICATE-----
MIIB+DCCAZ4CFEI3KK+a081d9SSOLBY5tecQgei0MAoGCCqGSM49BAMCMCMxITAf
BgNVBAMMGGszcy1jbGllbnQtY2FAMTYzMjY3NjI1MDAeFw0yMTEwMDUxOTIxNDBa
...
AwIDSAAwRQIhAPsU8FOJW0upv5JtsjIQaPRWL+/aWw8vMmgvUnwkEGNAAiB2IOI/
E4I7IUSkxXgfE+rphNUBfGstt4np0KnUkTIJyw==
-----END CERTIFICATE-----
```

## Generar un fichero `kubeconfig`

Para que el usuario pueda acceder al clúster usando un cliente como `kubectl`, generamos un fichero `kubeconfig` (aunque podemos añadir la misma información a un fichero `kubeonfig` existente).

La configuración necesaria para conectar al clúster en el fichero `kubeconfig` es:

- *cluster*: URL de acceso al clúster y certificado público para establecer la conexión TLS con el API Server.
- *user*: nombre del usuario y certificados de cliente que identifican al usuario
- *contexto*: un *contexto* es la combinación de un usuario y un clúster.

*kubectl* permite generar esta información mediante el subcomando `kubectl config`.

> Para evitar mezclar configuraciones, creamos un fichero de configuración específico para el usuario.

### Configuración del clúster (en el fichero `kubeconfig`)

Configuración de clúster:

```bash
kubectl config set-cluster ${CLUSTER_NAME} \
    --kubeconfig=${USER}-kubeconfig \
    --server=${CLUSTER_URL} --certificate-authority=server-ca.crt \
    --embed-certs=true
```

- `${CLUSTER_NAME}` especifica el nombre con el que queremos identificar el clúster en el fichero de configuración.
- `${CLUSTER_URL}` indica la URL de acceso del API Server, incluyendo el puerto (por defecto, 6443)

### Configuración del usuario (en el fichero `kubeconfig`)

Configuración del usuario:

```bash
kubectl config set-credentials ${USER} \
    --kubeconfig=${USER}-kubeconfig \
    --client-certificate=${USER}.crt --client-key=${USER}.key \
    --embed-certs=true
```

- `${USER}` especifica el nombre de usuario en el fichero `kubeconfig`; puede ser diferente del nombre de usuario contenido en el certificado. El nombre del usuario en el clúster será el especificado en el campo `CN=` del certificado.

### Configuración del contexto (en el fichero `kubeconfig`)

Configuración del contexto:

```bash
kubectl config set-context ${CONTEXT} \
    --kubeconfig=${USER}-kubeconfig \
    --namespace=${NAMESPACE} --user=${USER} --cluster=${CLUSTER_NAME}
```

- `${CONTEXTO}` especifica el nombre asignado a la combinación de nombre y usuario. Algunas herramientas muestran este nombre al usar la configuración del fichero `kubeconfig`. Este nombre también es el que se usa para cambiar de un contexto a otro en `kubectl`

- `${USER}` el nombre de un usuario definido en el fichero de configuración (con un certificado asociado)
- `${CLUSTER_NAME}` nombre de un clúster definido en el fichero de configuración (con una URL y un certificado asociado)
- `${NAMESPACE}` (opcional) el nombre del *namespace* por defecto al conectar al clúster. Si se omite, se usa `default`.

#### Establecer el contexto como *current*

Dado que el fichero `kubeconfig` puede contener múltiples *contextos*, es necesario indicar cuál es el contexto activo o *current*.

Usamos el comando:

```bash
kubectl config use-context ${CONTEXT} --kubeconfig ${USER}-kubeconfig
```

## Autorización del usuario

El certificado autentica al usuario en el clúster; es decir, demuestra que es quien dice ser. Pero todavía no hemos especificado qué puede hacer; para ello, necesitamos asignar permisos al usuario.

### Crear un *Role* (o *ClusterRole*)

En Kubernetes, los permisos se definen a través de los *Roles*; un rol especifica qué acciones (`verbs`) se pueden realizar sobre los elementos de la API (los recursos).

El siguiente *Role* de ejemplo permite las acciones `get`, `watch` y `list` en el *namespace* `${NAMESPACE}`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: sample-role-for-${USER}}
rules:
- apiGroups: [''] # '' indicates the core API group
  resources: ['pods']
  verbs: ['get', 'watch', 'list']
```

Para asignar los permisos especificados en el *Role* a un usuario, usamos un *RoleBinding* (o un *ClusterRoleBinding*):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: ${NAMESPACE}
  name: bind-sample-view-role-to-${USER}
subjects:
- kind: User
  name: ${USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: sample-role-for-${USER}
  apiGroup: rbac.authorization.k8s.io
```

El nombre del usuario `${USER}` es el indicado en el campo `CN` del certificado.

## Prueba

Verificamos que el rol existe (con el usuario administrador):

```bash
$ kubectl describe role sample-role-for-xavi
Name:         sample-role-for-xavi
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [get watch list]
```

Verificamos que el *RoleBinding* proporciona los permisos indicados en el rol al usuario:

```bash
$ kubectl describe rolebinding bind-sample-role-to-xavi
Name:         bind-sample-role-to-xavi
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  sample-role-for-xavi
Subjects:
  Kind  Name  Namespace
  ----  ----  ---------
  User  xavi 
```

> Aunque el *subject* aparezca en blanco, el rol es un recurso que sólo aplica al *namespace* en el que se encuentra definido.

Ahora, como usuario `${USER}`:

```bash
$ kubectl get pods --kubeconfig=xavi-kubeconfig
No resources found in default namespace.
```

La petición a la API para listar los pods en el namespace `default` se ejecuta con éxito; esto demuestra que el usuario ha podido autenticarse en la API de Kubernetes y que además, está autorizado a *listar* los pods en el *namespace* `default`.

Si el usuario intenta realizar la misma acción en otro *namespace*:

```bash
$ kubectl get pods --kubeconfig=xavi-kubeconfig --namespace kube-system
Error from server (Forbidden): pods is forbidden: User "xavi" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

Como podemos ver, el usuario no está autorizado a realizar esta acción en otro *namespace* diferente, por lo que recibimos *Forbidden*.

Lo mismo sucede si intentamos realizar una acción diferente a las especificadas, aunque sea en el *namespace* en el que el usuario tiene algunos permisos:

```bash
$ kubectl get configmap --kubeconfig=xavi-kubeconfig
Error from server (Forbidden): configmaps is forbidden: User "xavi" cannot list resource "configmaps" in API group "" in the namespace "default"
```
