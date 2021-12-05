# Creación de un usuario en K8s (método nativo de Kubernetes 1.19+)

En este artículo vamos a describir el proceso de crear un usuario en Kubernetes **sin necesidad de exportar los certificados privados de la CA del clúster**; usaremos el mecanismo de aprobación de las peticiones de firma de certificados disponible en Kubernetes v1.19 o superior.

## Proceso automatizado

La principal diferencia con el método anterior es que esta vez no se requiere extraer el certificado privado de la entidad certificadora del clúster; la firma del *CSR* se realiza mediante un método *nativo* de Kubernetes (1.19+): el `CertificateSigningRequest` y el comando `kubctl certificate approve` (o `deny`).

El proceso esta vez no require acceso al certificado privado de la CA del clúster (al que no debería tener acceso mucha gente), por lo que he pensado que se podría automatizar el proceso de solicitar acceso al clúster (si es necesario).

Me imagino un escenario donde un usuario solicita acceso al clúster mediante un portal de autoservicio. La notificación llega al equipo de administradores del clúster, que tras revisar la petición, aprueban el acceso.

A partir de aquí, un *script* similar al propuesto realizaría los pasos necesarios para proporciona acceso al solicitante.

El *script* se podría mejorar, por ejemplo, añadiendo un tiempo de expiración al certificado (especificando `spec.expirationSeconds` en el CSR, por ejemplo (disponible en Kubernetes 1.22+)) o usando como *input* el CSR adjuntado por el usuario en la petición.

## Requisitos

Para crear el `CertificateSigningRequest`, aprobar el CSR y generar el fichero `kubeconfig` para el usuario, es necesario contar con un usuario con acceso y los permisos necesarios en el clúster. La ubicación del fichero `kubeconfig` a usar debe especificarse en la variable `$KUBECONFIG`.

## Clave privada del usuario

El procedimiento para generar un nuevo usuario empieza del mismo modo: creando una clave privada:

```bash
generate_key_if_not_exists() {
    keyName=${1}

    if [[ -n ${2} ]]
    then
        keyBITS=${2}
    else
        keyBITS=4096
    fi

    if [[ -e ${keyName} ]]
    then
        logger "INFO" "${keyName} already exists."
    else
        logger "INFO" "Generating ${keyName} (${keyBITS} bits)..."
        openssl genrsa -out ${keyName} ${keyBITS}
    fi
}
```

## Petición de firma de certificado (*Certificate Signing Request*)

Al generar la petición de firma de certificado (*Certificate Signing Request*, CSR), es necesario especificar:

- el nombre de usuario en el campo *Common Name (CN)*. Se usa el valor definido en `CN` para autenticarlo en el API Server.
- el nombre del grupo (o grupos) a los que pertenece en el campo *Organization (O)*. Se usa el valor definido en `O` para asociar el rol con los permisos del usuario.

Esta información se incluye en la creación del CSR mediante: `-subj "/CN=xavi/O=managers"`.

```bash
generate_certificate_signing_request() {
    # Create Certificate Signing Request (CSR)
    if [[ -n ${1} ]]
    then
        keyOwner=${1}
    else
        logger "ERROR", "keyOwner is requiered."
    fi

    if [[ -n ${2} ]]
    then
        keyOwnerGroup=${2}
    else
        logger "ERROR", "keyOwnerGroup is requiered."
    fi

    logger "INFO" "Created CSR csr_${keyOwner}.csr"
    openssl req -new -key ${keyOwner}.key \
            -out csr_${keyOwner}.csr \
            -subj "/CN=${keyOwner}/O=${keyOwnerGroup}"
}
```

## Firma de la *CSR*

La firma del fichero `.csr` resulta en la creación de un certificado. Éste permitirá al usuario autenticar cada petición que se realice contra el API server.

A diferencia del artículo anterior, en este caso el usuario genera un recurso en Kubernetes de tipo `CertificateSigningRequest` (disponible en Kubernetes 1.19+):

> `spec.signerName` is required for `cetificates.k8s.io/v1` como indica la documentación oficial en[Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)

Codificamos en base64 el fichero *CSR* generado el paso anterior y creamos un *manifest* para un objeto de tipo `CertificateSigningRequest`:

```bash
generate_csr_manifest() {
    if [[ -n ${1} ]]
    then
        keyOwner=${1}
    else
        logger "ERROR" "keyOwner is required"
    fi

    if [[ -n ${2} ]]
    then
        csrFile=${2}
    else
        logger "ERROR" "csrFile is required"
    fi

    if [[ -e ${csrFile} ]]
    then
        logger "INFO" "Generating base64EncodedCSR"
        base64EncodedCSR=$(cat ${csrFile} | base64 | tr -d '\n')
    else
        logger "ERROR" "csrFile not found!"
    fi
    
    logger "INFO" "Generating manifest csr_${keyOwner}_manifest.yaml"
    cat > csr_${keyOwner}_manifest.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${keyOwner}-csr
spec:
  signerName: kubernetes.io/kube-apiserver-client
  request: ${base64EncodedCSR}
  usages:
  - client auth
EOF
}
```

Una vez creado el *manifest*, lo *aplicamos* para crear la petición en la API del clúster:

> Es necesario que la variable `$KUBECONFIG` esté definida (apuntando a un fichero `kubeconfig` con permisos para crear y aprobar CSR en el clúster.)

```bash
apply_csr_manifest() {
    if [[ -n ${1} ]]
    then
        csrManifestFile=${1}
    else
        logger "ERROR" "csrManifestFile required"
    fi

    if [[ -e ${csrManifestFile} ]]
    then
        logger "INFO" "Using $csrManifestFile"
    else
        logger "ERROR" "$csrManifestFile not found!"
    fi

    if [[ -n ${KUBECONFIG} ]]
    then
        logger "INFO" "Applying file ${csrManifestFile}"
        kubectl apply -f ${csrManifestFile}
    else
        logger "ERROR" "\$KUBECONFIG not set"
    fi
}
```

## Aprobar la firma del CSR

Las CSR aprobadas, denegadas o fallidas se eliminan automáticamente del clúster tras una hora. Las peticiones pendientes, tras 24 horas (ver [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)).

> Cuando hay más de un certificado, debemos filtrar por el nombre del `csr`: `k get csr -o jsonpath='{.items[?(@.metadata.name=="antonio-csr")].status}'`. Si está pendiente, devuelve `{}`.
>
> Revisar: Cuando el certificado ya está aprobado, el campo `kubectl get csr -o jsonpath='{.items[?(@.metadata.name=="xavi-csr")].status.conditions[*].type}'` devuelve `Approved`.

Una vez creado el recurso `CertificateSigningRequest` en el clúster, lo aprobamos:

```bash
approve_csr() {
    if [[ -n ${1} ]]
    then
        csrToApprove=${1}
        isPending=$(kubectl get csr ${csrToApprove} -o jsonpath='{.items[*].status}')
        if [[ ${isPending} == "" ]]
        then
            logger "INFO" "${csrToApprove} is Pending for approval"
            logger "INFO" "Approving ${csrToApprove}..."
            kubectl certificate approve ${csrToApprove}
        else
            logger "ERROR" "${csrToApprove} is ${isPending}"
        fi
    else
        logger "ERROR" "csrToApprove is required!"
    fi
}
```

## Extracción del certificado

Extraemos el certificado ya firmado por la entidad certificadora del clúster usando:

```bash
get_user_signed_certificate() {
    userCSR="${1}"
    userSignedCertificate="${1}_signed_certificate.crt"
    logger "INFO" "Generating $userSignedCertificate ..."
    kubectl get csr -o jsonpath="{.items[?(@.metadata.name==\"${k8sUSER}-csr\")].status.certificate}" | base64 --decode | tee ${userSignedCertificate}
}
```

Examinamos el certificado para comprobar que, efectivamente, identifica al usuario y que la entidad certificadora es la del clúster:

```bash
$ openssl x509 -in xavi_signed_certificate.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            ed:ea:7c:5e:3c:65:03:d4:a8:f2:b7:ef:4f:ac:2d:49
        Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN = k3s-client-ca@1632676250
        Validity
            Not Before: Dec  5 17:38:21 2021 GMT
            Not After : Dec  5 17:38:21 2022 GMT
        Subject: O = managers, CN = xavi
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (4096 bit)
            .
            .
            .
```

El *issuer* es `Issuer: CN = k3s-client-ca@1632676250` y el *subject* `Subject: O = managers, CN = xavi`.

## Fichero `kubeconfig` para el usuario

Finalmente, definimos un fichero `kubeconfig` que permita al usuario autenticar y autorizar las peticiones que realice contra la API de Kubernetes.

> Se puede usar un fichero `kubeconfig.tpl` como plantilla y substituir los valores usando `envsubst`, por ejemplo.
>
>  ```yaml
>  apiVersion: v1
>  kind: Config
>  clusters:
>  - cluster:
>      certificate-authority-data: ${k8sCLUSTER_CA}
>      server: ${k8sCLUSTER_ENDPOINT}
>    name: ${k8sCLUSTER_NAME}
>  users:
>  - name: ${k8sUSER}
>    user:
>      client-certificate-data: ${k8sCLIENT_CERTIFICATE_DATA}
>      client-key-data: ${k8sCLIENT_KEY_DATA}
>  contexts:
>  - context:
>      cluster: ${k8sCLUSTER_NAME}
>      user: ${k8sUSER}
>    name: ${k8sUSER}-${k8sCLUSTER_NAME}
>  current-context: ${k8sUSER}-${k8sCLUSTER_NAME}
>  ```
>
> Sin embargo, he optado por seguir la vía de definir el fichero mediante una función del *script*.

El objetivo es crear un fichero `kubeconfig` que entregaremos al usuario final al resolver la petición de acceso al clúster, por ejemplo.

### Kubeconfig - definición del clúster

En esta sección del fichero `kubeconfig` debemos proporcionar un nombre y la URL de acceso a la API del clúster de Kubernetes.

Esta información podemos extraerla del fichero `kubeconfig` definido en la variable de entorno `$KUBECONFIG` que estamos usando en el *script*.

Como en el fichero `kubeconfig` puede haber definidos varios *contextos*, en primer lugar debemos averiguar cuál es el *current context*:

```bash
get_current_context_from_kubeconfig() {
    kubectl config view -o jsonpath='{.current-context}'
}
```

De aquí, obtenemos la información que necesitamos:

```bash
get_server_from_kubeconfig() {
    clusterName="${1}"
    kubectl config view -o jsonpath="{.clusters[?(@.name==\"${clusterName}\")].cluster.server}"
}
```

También obtenemos la parte pública de la CA del clúster (para validar la firma del certificado del usuario):

```bash
get_cluster_ca_certificate_from_kubeconfig() {
    clusterName="${1}"
    kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"${clusterName}\")].cluster.certificate-authority-data}" | base64 --decode | tee cluster_ca_file.cert
}
```

### Kubeconfig - definición del usuario y contexto

La información a incluir en el fichero `kubeconfig` relativa al usuario la hemos generado previamente: la clave privada y el certificado firmado por la CA del clúster:

```bash
[...]
logger "INFO" "[kubeconfig] Setting user \"${k8sUSER}\"..."
kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-credentials ${k8sUSER} \
    --client-certificate=${k8sUSER}_signed_certificate.crt \
    --client-key=${k8sUSER}.key \
    --embed-certs=true
[...]
```

Finalmente definimos un *contexto*, que *agrupa* la información del usuario y del clúster al que proporcionamos acceso:

```bash
[...]
logger "INFO" "[kubeconfig] Setting context to \"${k8sUSER}@${k8sClusterName}\"..."
kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-context ${k8sUSER}@${k8sClusterName} \
    --user="${k8sUSER}" --cluster="${k8sClusterName}"
[...]
```

Para facilitar la conexión, establecemos el contexto definido como *current-context* en el fichero `kubeconfig`:

```bash
[...]
logger "INFO" "[kubeconfig] Setting default context to \"${k8sUSER}@${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config use-context ${k8sUSER}@${k8sClusterName}
[...]
```

Todo junto:

```bash
create_user_kubeconfig() {
    k8sUSER="${1}"
    k8sClusterName="${2}"
    apiURL="${3}"
    clusterCA="${4}"

    logger "INFO" "[kubeconfig] Setting cluster \"${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-cluster ${k8sClusterName} \
        --server="${apiURL}" --certificate-authority="${clusterCA}" --embed-certs=true

    logger "INFO" "[kubeconfig] Setting user \"${k8sUSER}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-credentials ${k8sUSER} \
        --client-certificate=${k8sUSER}_signed_certificate.crt \
        --client-key=${k8sUSER}.key \
        --embed-certs=true

    logger "INFO" "[kubeconfig] Setting context to \"${k8sUSER}@${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-context ${k8sUSER}@${k8sClusterName} \
        --user="${k8sUSER}" --cluster="${k8sClusterName}"
    
    logger "INFO" "[kubeconfig] Setting default context to \"${k8sUSER}@${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config use-context ${k8sUSER}@${k8sClusterName}
}
```

## Ejecución de ejemplo

```bash
./automate.sh -u perico -g developers
[INFO] Generating perico.key (4096 bits)...
Generating RSA private key, 4096 bit long modulus (2 primes)
................................................++++
....................................................................................................................................................................................................++++
e is 65537 (0x010001)
[INFO] Created CSR csr_perico.csr
[INFO] Generating base64EncodedCSR
[INFO] Generating manifest csr_perico_manifest.yaml
[INFO] Using csr_perico_manifest.yaml
[INFO] Applying file csr_perico_manifest.yaml
certificatesigningrequest.certificates.k8s.io/perico-csr created
[INFO] perico-csr is Pending for approval
[INFO] Approving perico-csr...
certificatesigningrequest.certificates.k8s.io/perico-csr approved
[INFO] Generating perico_signed_certificate.crt ...
-----BEGIN CERTIFICATE-----
MIIDWTCCAv6gAwIBAgIQHuwjQI/iBPqmN5pBJ+oVdjAKBggqhkjOPQQDAjAjMSEw
HwYDVQQDDBhrM3MtY2xpZW50LWNhQDE2MzI2NzYyNTAwHhcNMjExMjA1MTcyMDU1
WhcNMjIxMjA1MTcyMDU1WjAmMRMwEQYDVQQKEwpkZXZlbG9wZXJzMQ8wDQYDVQQD
EwZwZXJpY28wggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0WhCUUHj6
8faURtQmdzs9jcAzXVj3C/IoK5hFn2Xf4/yse1tIAQlTRrbJpnZz3wERRlXToTj+
g4wm3UeGrWX/NG9cMTof7pqLgt5CCQHAfdvfCbRRc7pMTsDf9gzZbKwdL+8zKZQE
pcqCovmb799MELEBhrF7Psvb5xT4yAzKoRRGYg5U7CY+7TGPa3/mp0bqWM5dfOzO
hsJ2JA/y/FIhClSDiMIXYGAVZX8vvSXz4cyffSjlETwVYAFnlNE/LVn0Z78DyzIU
I+pAnN+dFPWR19bu0QBNROkOWyEVAcaKPP0DeZ3gx9OXJvyZ9PNWeYj4lWVNU95C
mmXPNpZiwVADPQfVt0gyUnjhiCxJlsHI4DlQ6FFRvVZ50WjoZLrK/EQ4fD4709J0
cJUK48AxeZSCxLHMjypTbsHKVHVhtikoP9yqAYQUe/gNSn3ApaVbA5fii2kxFXEW
+fxKaGJ/TYw68RXJ3bs3B7IpLNbdkgj78/Iw7Cr3KUM0b613VX3XWeoOlqbgwN+2
6n4K+XLfUBMWyEXMl5uwW4js0pn11yKpwM2Z6fMUHhDG6AtrGEV67USgWcfkiO6B
qf2yyg1L6tf/h5NRO1hpATOEpdrU/8qCdJx1693pjsgPfwNRBuBlHlYXQuyMdoqx
FfNyfMABV5FQXLdz0yeurP23Tkf44yonqwIDAQABo0YwRDATBgNVHSUEDDAKBggr
BgEFBQcDAjAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFF5NUrp44FW16SizbArY
cGpDhRc+MAoGCCqGSM49BAMCA0kAMEYCIQDjoxcaBYUpnwtiaXoSt9rshXZTXFhr
QS4GbFpw8IyhFAIhANS7H8K5lDHrYVxdssHdRDevoBBuH9GFXY3KuTbJDl3J
-----END CERTIFICATE-----
[INFO] [kubeconfig] Setting cluster "kubernetes"...
Cluster "kubernetes" set.
[INFO] [kubeconfig] Setting user "perico"...
User "perico" set.
[INFO] [kubeconfig] Setting context to "perico@kubernetes"...
Context "perico@kubernetes" created.
[INFO] [kubeconfig] Setting default context to "perico@kubernetes"...
Switched to context "perico@kubernetes".
```

## Validación

Con el certificado firmado por entidad certificadora del clúster, el usuario puede **autenticarse** en la API de Kubernetes del clúster.

En el fichero `kubeconfig` se incluye la clave privada del usuario y un certificado firmado que permite acreditarse al realizar una llamada a la API.

Pero como el usuario no tiene asociado ningún rol (y por tanto, no tiene permisos para realizar ninguna acción), tras autenticar al usuario se deniega cualquier llamada a la API (`Forbidden`):

```bash
$ kubectl get pods -n development --kubeconfig perico_kubeconfig
Error from server (Forbidden): pods is forbidden: User "perico" cannot list resource "pods" in API group "" in the namespace "development"
```

En el *namespace* `development` se definió un rol de sólo lectura llamado `read-only-manager`:

```bash
$ kubectl get roles -n development
NAME                CREATED AT
read-only-manager   2021-11-27T16:18:40Z
```

Este rol se asoció a los miembros del grupo `managers`:

```bash
$ kubectl describe rolebinding read-only-managers -n development
Name:         read-only-managers
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  read-only-manager
Subjects:
  Kind   Name      Namespace
  ----   ----      ---------
  Group  managers
```

Por tanto, si creamos un usuario que forme parte del grupo `managers`, debería poder, además de realizar llamadas autenticadas a la API, tener permisos para realizar las acciones definidas en este rol:

```bash
$ kubectl describe role read-only-manager -n development
Name:         read-only-manager
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  *.*        []                 []              [get list]
```

Creamos un usuario llamado `xavi` dentro del grupo de `managers`:

```bash
./automate.sh -u xavi -g managers
```

Validamos que este usuario sí que puede realizar la acción `get` sobre los `pods` en el *namespace* `development` (aunque no haya ninguno):

```bash
$ kubectl get pods -n development --kubeconfig xavi_kubeconfig
No resources found in development namespace.
```

Una manera de validar los permisos es usando el subcomando `can-i` de `kubectl auth`:

```bash
$ kubectl auth can-i list pods --as=xavi --as-group=managers -n development
yes
$ kubectl auth can-i list pods --as=xavi --as-group=managers -n kube-system
no
$ kubectl auth can-i create pods --as=xavi --as-group=managers -n development
no
```
