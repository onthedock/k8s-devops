# Crear `SealedSecrets` con `kubeseal`

| Producto | Versión |
| -- | -- |
| **kubectl** (`kubectl version --short`) | Client Version: v1.19.4 |
| (**k3s**) | Server Version: v1.21.2+k3s1 |
| **Helm** (`helm version --short`) | v3.6.2+gee407bd |
| **SealedSecrets** | v0.16.0 (*Helm Chart*: 1.16.1) |
| **kubeseal** (`kubeseal --version`) | kubeseal version: v0.16.0 |

La *Helm Chart* oficial despliega el **controlador** de *Sealed Secrets* en el clúster.

Para generar los *SealedSecrets* usamos la herramienta **kubeseal**; se trata de un ejecutable en Go, sin dependencias externas.

```bash
$ wget -O kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64
--2021-08-18 22:00:38--  https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64
Resolving github.com (github.com)... 140.82.121.4
Connecting to github.com (github.com)|140.82.121.4|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://github-releases.githubusercontent.com/92702519/38955200-b1e1-11eb-9a84-0e13336d831e?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20210818%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20210818T200039Z&X-Amz-Expires=300&X-Amz-Signature=987f4688e22b716d3d61c64452fe02c80567a2be90132096d16666015f415db8&X-Amz-SignedHeaders=host&actor_id=0&key_id=0&repo_id=92702519&response-content-disposition=attachment%3B%20filename%3Dkubeseal-linux-amd64&response-content-type=application%2Foctet-stream [following]
--2021-08-18 22:00:39--  https://github-releases.githubusercontent.com/92702519/38955200-b1e1-11eb-9a84-0e13336d831e?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20210818%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20210818T200039Z&X-Amz-Expires=300&X-Amz-Signature=987f4688e22b716d3d61c64452fe02c80567a2be90132096d16666015f415db8&X-Amz-SignedHeaders=host&actor_id=0&key_id=0&repo_id=92702519&response-content-disposition=attachment%3B%20filename%3Dkubeseal-linux-amd64&response-content-type=application%2Foctet-stream
Resolving github-releases.githubusercontent.com (github-releases.githubusercontent.com)... 185.199.110.154, 185.199.108.154, 185.199.111.154, ...
Connecting to github-releases.githubusercontent.com (github-releases.githubusercontent.com)|185.199.110.154|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 35626806 (34M) [application/octet-stream]
Saving to: ‘kubeseal’

kubeseal                         100%[========================================================>]  33,98M  4,15MB/s    in 8,7s    

2021-08-18 22:00:48 (3,91 MB/s) - ‘kubeseal’ saved [35626806/35626806]
```

Lo *instalamos* (moviéndolo a una ruta dentro del *path*) usando:

```bash
$ sudo install kubeseal /usr/local/bin
$ kubeseal --version
kubeseal version: v0.16.0
```

## Crear un *Secret* temporal (usando `--dry-run=client`)

El objetivo de *SealedSecrets* es evitar que datos *sensibles* contenidos en `Secrets` se publiquen en el repositorio de código.

La manera más segura de que no se pueda guardar **nunca** esa información *en claro* en el repositorio es no crear el fichero del `Secret`. Usaremos la opción `--dry-run` del comando `kubectl create` redirigiendo la salida hacia **kubeseal**.

> Como referencia, crearé un `SealedSecret` con un par de claves de AWS (`AWS_ACCESS_KEY_ID` y `AWS_SECRET_KEY`) falsas.

| Clave | Valor |
| ----- | ----- |
| `AWS_ACCESS_KEY_ID` | `AKIAEXAMPLEIOSFODNN7` |
| `AWS_SECRET_KEY` | `EXAMPLEKEYwJalrXUtnFEMI/K7MDENG/bPxRfiCY` |

El siguiente comando generaría el fichero de definición de un *Secret* (sin llegar a crearlo):

```bash
$ kubectl create secret generic aws_credentials \
  -n demo \
  --from-literal='AWS_ACCESS_KEY_ID=AKIAEXAMPLEIOSFODNN7' \
  --from-literal='AWS_SECRET_KEY=EXAMPLEKEYwJalrXUtnFEMI/K7MDENG/bPxRfiCY' \
  -o yaml --dry-run=client
```

Para crear un `SealedSecret` enviamos la salida del comando anterior hacia **kubeseal**:

```bash
$ kubectl create secret generic aws_credentials \
  -n demo \
  --from-literal='AWS_ACCESS_KEY_ID=AKIAEXAMPLEIOSFODNN7' \
  --from-literal='AWS_SECRET_KEY=EXAMPLEKEYwJalrXUtnFEMI/K7MDENG/bPxRfiCY' \
  -o yaml --dry-run=client \
  | kubeseal -o yaml | tee aws-credentials-sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: aws_credentials
  namespace: demo
spec:
  encryptedData:
    AWS_ACCESS_KEY_ID: AgCb/RuzbHqc172M9y7ZbzcIPSiUcc1jn2nLEPpb7t93fTSBVTcMES6fwCfsP8p9K4EiOgndgHWuYREk1FhEeM3BHlBi6e9+MZu8xKuQ5AbClltRuZRBJZVFfdZsijU2HEt1qbCDTTSuk8jIqYHCmVnnjcDsiVJ/m/haA1jwFZr/XQtMuZR12+JL+vWgIslbEzD0KWzXZHO12w8NYKOCSu4IjbAfHML/4tYr5k34djYIqzohGbQdCbEirAN17ovyPOQZcmro5yaedmU3pzKm6oHmh2an6i/Q6eKtSC5yq9AK66SwB16MwR8Nw1YSEZBGzzDNLir00ErQoxuG8Pu1sTgIWIWD89dTlKyhlmCq2V3am4rXmFIIbmht5neZgly7n6kipZjLo0wn1RlUOtaZu3dE/t1jRxWTBdpPRXs2D8nytV7W/uEeaK3m+OwpuP+7CBO6NT5/QTAcIGbkje8DJGT7baO7hgsVxGL8mAK5Fsw33j2vYsVF9AeiiBiDQLjlbxx8YeIEJzshDlJ9pvfBbEer4a+MkPDFiYu3sy9KmpE8UY3VsFhYKd4bTb3mB2kGPcFDOPid5aEOGVbOepLdjcJq6SUnScq0m5X92FirH9oKxu+Vry36j1w2GaGk+/FSX1vWfiBZDUYVrWY60X0mdwoB9WeHHOrpVXE/nWl61d9xGErn0JB2ydRvZ0Vs0NzmMv3DWMc+5EuEkDBJiwfJdGDVrhRB6Q==
    AWS_SECRET_KEY: AgA6p7yH+lCICTYC10ZxTGUQvyNQaCSOd4StZPkaPFSUgKGye8LIQ8JxhclcoHXi+haIXCKunP+wOduUy5Ef3mYVxsivsvjcPlb0Rj6hh33YKWLJh8dXW2dY7IBAh9tXf6TCDAgQz+Pr7hqeh/HOsaiZBDlgETo27HC2cp8ovXfIesqreq0ZOlSyF9YU/U+e1F25gkxO2KuuqThMyAA45n0M2fnW1hXDdjIcRUz99/YQVcBLMkVhYg83wE/YeAZEpf7Xr4b4JeWBJPjW2HrhjWmY6VT1jfm6+d2xe5SO39VnzIOGoX3zkTkNIuC1Qq+ggth4aOSjFUSebuSfWadv1fDU5/zdKKZI2X9yx6SBsw50Df2T+BXV2sDPC2t67TyUXoyesjGd5qSgi7ZzktCBtKWjih2QS3P9ktAXaoNcCKAHQj8PRxZJh4T3EyZF3O5f5vFeqSu7YFuGDHSo0ahCcjFCHHJ6UgBIP9hrRlQTQeOtSSBK7ld5SPV+sytS+6CYCADRTlBwiIHdQG9FPPzqVDscIDZ2ccfm9jmdLvuuO4fzg1gVCw2cAm8urnLLdkuVkraiBdjXqPGFLIj6VM86/4S1JR8t+4hInnOerM47YUiX5p4wRoT9qcMBBLgU5YdStxBfc2IfkzpJEc9X6/cY2FITBMXmGElCBKgNSZjnk4DQV/K5btJwTTlu0n7DTkcOL9IV5fCF1V7z36YizzK2nVi8V5cYpGxClJRKw9u7/n6PS2JUJUZpBm4T
  template:
    data: null
    metadata:
      creationTimestamp: null
      name: aws_credentials
      namespace: demo
```

La información sensible contenida en el `SealedSecret` está cifrada, no simplemente *codificada en base64*, como un `Secret` ordinario, por lo que es seguro publicarla en un repositorio de código; sin la clave privada (a la que sólo tiene acceso el *controller* de *SealedSecrets* en el clúster), no es posible leer el contenido de los campos en `.spec.encryptedData.*`.

### Importante - Conectividad y acceso a la API del clúster

`kubeseal` ha obtenido la parte pública del certificado generado por el controlador *SealedSecrets* contectando con el clúster vía API usando la información y las credenciales contenidas en el fichero `~/.kube/config` (en mi caso).

Si **kubeseal** no puede acceder al clúster, se pueden *sellar* los secretos especificando la ruta al certificado público del controler con la opción `--cert`.

**kubeseal** permite obtener el certificado público del controlador mediante el comando `kubeseal --fetch-cert` (require conectividad y acceso a la API del clúster).

```bash
$ kubeseal --fetch-cert | tee controller-public-cert.crt
-----BEGIN CERTIFICATE-----
MIIErTCCApWgAwIBAgIQBiQc7Z+Z8n8xtYME0Bs40jANBgkqhkiG9w0BAQsFADAA
MB4XDTIxMDgxODE5MjM1NFoXDTMxMDgxNjE5MjM1NFowADCCAiIwDQYJKoZIhvcN
AQEBBQADggIPADCCAgoCggIBANh5a5otzFHEPfMrDJPFhZIR0fQ+7HLSmZb6EOxQ
NbI4uV/L06Icq+K28deCCPQgp2GTnVO2oMJql/fMbkYCSWZMmRSIXKdBZca8dJOJ
WUxOYQ66qS1p2iLJl9NmClXZp2GMxzQbrBRRwss4TdW+Y+zj0YY5VzxbYxz3NRt6
/3fUfOEl9J5zsfJp/uY/HnfWrtHu1lZjmwj/zabd/D+Guw3cdQ07UdQ1B9FhZBzu
+/sf0DGLA/FRo0uOE8q/uTiY+l0GqyJeM3WxjrFSEF+WBgdbE26OaIeE+w9yOENq
8dsyCxqkI+Oa5xtFkBaN8T6dLJTlubdzq2ioohnlPOUQymK5Tct5/EhvFtAAczij
/Ko2nDBFIw9HFMtXOBkeDsRDyIllO+e+BOxYsmxQV8b6CzmwrfAOQ2MbaT7v/78H
E8cWu6viRwbKdrCuR8Y30JgG6LlXKTKSRyXmirAhRpTkRcbu0E8kQOA9uwkDDrmP
b6ScO7CJcnDlA4eWxvL4D6Oik7f94TpbKbpG07bSLh4HNIJ+V8gxnT3FWE8BAEtH
sR0lFBvewVeZhD6okvbN40vJFhV36Imx4suJ7DjdudGqrCVc2XyMt8ezQDRWADy+
MlNOFxpTe8xp6HUpHWohZ2yPk3biBQhTBdx5nacmwzmoI8zsxP/vk/8KV6bnsT1a
Bv5HAgMBAAGjIzAhMA4GA1UdDwEB/wQEAwIAATAPBgNVHRMBAf8EBTADAQH/MA0G
CSqGSIb3DQEBCwUAA4ICAQAou/AreNf51u9HwGoxctCdxVx6hvCjwh/7SCMQ0dJ5
zq52y6EOR0ZXOZ+ZllUkZb0PMv3jMjpVfYo4AlzpoMS9jEfsPN/AvHf2z71VzJvM
S7Qbldia6/4+MqpKjRISffW1BsAZTthAlKilDBo9+o8gioqqhMYgcvnaRduLMlYB
1dgv4X6pwTWzuASkQ6V5VrixQMa76GtRY/we/p3HfE7+af2McgpmAv8xSawUF4sV
g86ll4Hxy4U3tFjNo7iDs8upBuwc3AdvqYyBuh4l7RbxFtk1/LkZLnMhAUNI1gKr
nLS1uWiyoe+sgjip2JG9aAQoRiRXPwAN5aQgx1alQ1pLqacn78I6WC1nJENMYpYU
otSyOtxvN4oyw1ZDp3M1dEcGfiU4MT7G3ocG43QWj8lpY8UyMbZYTAU98kcmlmw5
W/xcCMuQm5YN+S3ooZcIxxO2jKJ2qNCRjfiHyMWyPRRl7aLgepozn8UmWsY7OOps
wSJXt8RFoOdXTSRQJLkXI5jtFMkkEYk9p0mYJTiRt1fpavtQ/gnSr+H7CW+II4Q6
zv3i7m2URtlkO8E348vaakjuVziJ18dJtDkyOcWKuo+fI47v57N49opvkVcoSFmP
GEQNRr+qeaJqUYguD2F5a6Mm1lIquZPI/UdmeHnfIs+CHWmcG5itvvNGhbxb8ALu
aA==
-----END CERTIFICATE-----
```

> El certificado rota cada 30 días (por defecto).

### Importante - *Namespace* destino del *Secret*

La política por defecto para *SealedSecrets* es `strict`; este comportamiento hace que el *SealedSecret* sellado por **kubeseal** sólo puede desplegarse con el mismo nombre y en el mismo *namespace* con el que ha sido *sellado*.

En el ejemplo, el *SealedSecret* sólo puede ser desplegado en el *namespace* `demo`.

Si se intenta desplegar en otro *namespace* (o con otro nombre), la acción falla con el mensaje:

```bash
$ kubectl apply -f aws-credentials-sealed-secret.yaml -n not-demo
error: the namespace from the provided object "demo" does not match the namespace "not-demo". You must pass '--namespace=demo' to perform this operation.
```

### Importante - Nombre del *controller*

**kubeseal** usa como nombre por defecto del controlador de *SealedSecrets* `sealed-secrets-controller`. Si se ha desplegado con otro nombre, es necesario indicarlo a **kubeseal** mediante la opción `--controller-name`.

Si el *controller* se ha instalado en un *namespace* difeente a `kube-system`, debe indicarse a **kubeseal** mediante la opción `--controller-namespace`.

> Se puede pasar la información a **kubeseal** mediante la variable de entorno `SEALED_SECRETS_CONTROLLER_NAMESPACE`.
