# Instalación

Hay varias formas de instalar *Sealed Secrets*; voy a probar la instalación vía Helm Charts.

> La versión *major* de *SealedSecrets* es `0.x.y`, pero cuando se creó la *Helm Chart* se adoptó la *major version* `1.x.y`.

## Añadir el *repo*

Añadimos el repositorio donde se encuentran las *charts* de *Sealed Secrets*:

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
```

## *Namespace* de instalación

*Sealed Secrets* se instala por defecto en el *namespace* `kube-system`.

Es posible instalar *Sealed Secrets* en otro *namespace*, pero entonces es necesario indicarle a `kubeseal` en qué *namesace* se encuentra el controlador.

[How to use kubeseal if the controller is not running within the kube-system namespace?](https://github.com/bitnami-labs/sealed-secrets#how-to-use-kubeseal-if-the-controller-is-not-running-within-the-kube-system-namespace)

Para probar el funcionamiento de *Sealed Secrets*, empezaremos usando el despliegue en el *namespace* `kube-system`.

## Instalación con Helm

```bash
$ helm install --namespace kube-system sealed-secrets sealed-secrets/sealed-secrets
NAME: sealed-secrets
LAST DEPLOYED: Thu Jun 17 19:33:21 2021
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You should now be able to create sealed secrets.

1. Install client-side tool into /usr/local/bin/

GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-$GOOS-$GOARCH
sudo install -m 755 kubeseal-$GOOS-$GOARCH /usr/local/bin/kubeseal

2. Create a sealed secret file

# note the use of `--dry-run` - this does not create a secret in your cluster
kubectl create secret generic secret-name --dry-run --from-literal=foo=bar -o [json|yaml] | \
 kubeseal \
 --controller-name=sealed-secrets \
 --controller-namespace=kube-system \
 --format [json|yaml] > mysealedsecret.[json|yaml]

The file mysealedsecret.[json|yaml] is a commitable file.

If you would rather not need access to the cluster to generate the sealed secret you can run

kubeseal \
 --controller-name=sealed-secrets \
 --controller-namespace=kube-system \
 --fetch-cert > mycert.pem

to retrieve the public cert used for encryption and store it locally. You can then run 'kubeseal --cert mycert.pem' instead to use the local cert e.g.

kubectl create secret generic secret-name --dry-run --from-literal=foo=bar -o [json|yaml] | \
kubeseal \
 --controller-name=sealed-secrets \
 --controller-namespace=kube-system \
 --format [json|yaml] --cert mycert.pem > mysealedsecret.[json|yaml]

3. Apply the sealed secret

kubectl create -f mysealedsecret.[json|yaml]

Running 'kubectl get secret secret-name -o [json|yaml]' will show the decrypted secret that was generated from the sealed secret.

Both the SealedSecret and generated Secret must have the same name and namespace.
```

> La versión instalada por Helm, al no haber especificado una versión concreta, es la última disponible 0.16.1.

  ```bash
  $ helm list -n kube-system
  NAME            NAMESPACE   REVISION  UPDATED                                 STATUS    CHART                   APP VERSION
  sealed-secrets  kube-system 1         2021-06-17 19:33:21.282839385 +0000 UTC deployed  sealed-secrets-1.16.1   v0.16.0    
  ```

Con el comando anterior, especificamos a Helm que instale la *chart* en el *namespace* `kube-system`.

```bash
$ k get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
NAME                              READY   STATUS    RESTARTS   AGE
sealed-secrets-5c6c8564d9-6wv95   1/1     Running   0          2m46s
```

Revisando los logs del *pod*:

```bash
$ k logs -n kube-system sealed-secrets-5c6c8564d9-6wv95
controller version: v0.16.0
2021/06/17 19:33:22 Starting sealed-secrets controller version: v0.16.0
2021/06/17 19:33:22 Searching for existing private keys
2021/06/17 19:33:25 New key written to kube-system/sealed-secrets-key22jmj
2021/06/17 19:33:25 Certificate is 
-----BEGIN CERTIFICATE-----
MIIErTCCApWgAwIBAgIQfJHsmEOOjEwwvRW/hKt6mjANBgkqhkiG9w0BAQsFADAA
MB4XDTIxMDYxNzE5MzMyNVoXDTMxMDYxNTE5MzMyNVowADCCAiIwDQYJKoZIhvcN
AQEBBQADggIPADCCAgoCggIBAJzbVbDyveQ0G7NuUNu+F75Wt/QXHrDZj6qDZ1nG
xLA5+GYsWtVAx/0rseFu5+R4GDzVE0H3PryptVPp3cGmh7JzlaBUh6XlBM2fYnmF
Kr+5Po+pdrs5aPS2w1dfyNR8D7I4GUSvV9cJZuK61H4hwnM5UFFz3n+BF9fPGqmS
3i3OisPTD4cwjdKjtA61bw2l/ICjXlq61bQjk6ohDnJlrZKjPfm4PkZ999GPDg4C
+nQxlBDg9jabMCl6+vNAWGzhdFdpbLG1llLUUzZmzHRJR7AQKv6cWtIErFTglU/g
k+FPInkdXnB3D6KqhocfOBVhpigTC/9EazMQOQXBNH+W/lf1DaYHdVmq+xuMbAVG
bK7qRmUeKl0Uzqw8dpfRNsnGuvRXfq3MP9gQMdT5bbjoCD5KvBWJztKd4m3ATyvK
6zqc5j1yRJOYdnyGCzYXK3rmQ4ao+u+siJWI2Es6fSh+1gv9fugeS6k9Qxg8HmNy
XUpnwkuvV/3ijzpyh1Stm0/xlBmpnEUMfN80OfeeBx95CuCfk9AnSc5+zZt/FYjH
J4wQNwHzbo0AJW6DeMC9kQRLI2oaxKoxhv+wx0Dob5QOe6CLyJxZirE2jY8RXCoY
DWWv/ntE8+IMbpqMtzivmn03zJe3Imxnhf/79FWh8iP78g9ERNSbFI0ZGmRTS4yT
4c7jAgMBAAGjIzAhMA4GA1UdDwEB/wQEAwIAATAPBgNVHRMBAf8EBTADAQH/MA0G
CSqGSIb3DQEBCwUAA4ICAQBH4NSmVmmTmRxNTi23Xm5hlsT6klSlckkfPkHtD7Iy
TjhqSvKYZg7u1KoL11Usii4erzy9mduOm6WLKQDMPOP8wWpsI2Qe4ATOHgHPz7bB
ZhXwcbZZZVrmAUOqVJysjxsCIyNR2QqBVEiUT7275lPD7+fJPNFl6ceZ3xF1WIRO
2O3zwE5ykHfOS4siuD9XtaSIQmDK9HysvafzZMdqjvi4pc2B1MS6TU7HuAxW41IB
H7OoBXkMo0BN/eVq4j1A6eUgXYbpzW6G7+DC3lIzmycKsv/Sq38WbHgaxYoBfqaH
rUmLAxh5Vd+oRNSWSnq9IgYycyAct5d13Mta/ZVSKg0tBZf96EIQ/sD8sbRuk6ex
GT5vim3ywcIS7LEQvNHlUJTDD7OaaVUtH/GcD7TX4+Ti5T/JPT2R0dxOjpI0YJF2
d2n99vGp/QVaFk8mOCpQOQrQytHbr65dPp3UdkXBynxYZNdCtUyF3v5MHu0lrMUG
TF2Q2t0TxdOnVltFj1xNRAlRLg17Q1oLPbT5ja5GDiT2xzrdlfNMMcUTeuvGEDeg
W6ZLzNJER7qOCiPdTcIRpYJoCkjdn2xWN029dh7ni2CSvfSuX2xKBy61+pw+bwSm
D/mssx411XJMV/0QywEvezLxbSc8+RWDbt1WpuncvUcAN3YbqFf3iGJa3CwUpkQr
mA==
-----END CERTIFICATE-----

2021/06/17 19:33:25 HTTP server serving on :8080
```

Como se indica en los logs, el par de claves se ha almacenado en un *secret* en el *namespace* `kube-system`. El *secret* creado es de tipo `tls` y contiene el certificado mostrado en los logs (la parte pública) en el campo `tls.crt`, mientras que la parte privada se encuentra en `tls.key`.

Finalmente, verificamos que tenemos un nuevo CRD en el clúster:

```bash
$ k get crd | grep -i secret
sealedsecrets.bitnami.com           2021-06-17T19:29:48Z
```

## Instalación del cliente `kubeseal`

Una vez tenemos desplegado *SealedSecrets* en el clúster, descargamos la parte cliente `kubeseal`.

Las instrucciones se encuentran en la página de [*releases*](https://github.com/bitnami-labs/sealed-secrets/releases) de *SealedSecrets* en GitHub.

```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64 -O kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

Validamos el cliente:

```bash
$ kubeseal --version
kubeseal version: v0.16.0
```

## Creación de un *SealedSecret*

Creamos el *manifest* de un *secret* desde la línea de comando usando `--dry-run`:

```bash
$ k create secret generic dummy-credentials --dry-run=client \
>  --from-literal=username=admin \
>  --from-literal=password=patata -o yaml | tee dummy-credentials.yaml
apiVersion: v1
data:
  password: cGF0YXRh
  username: YWRtaW4=
kind: Secret
metadata:
  creationTimestamp: null
  name: dummy-credentials
```

El siguiente paso es crear el *SealedSecret* usando `kubeseal`:

> Aunque hemos desplegado *SealedSecrets* usando la opción `--namespace kube-system`, vemos que es necesario especificar tanto el *namespace* como el nombre del controlador.

```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --format yaml < dummy-credentials.yaml > sealed-dummy-credentials.yaml
```

El resultado es un *manifest* de tipo `SealedSecret`:

```yaml
$ cat sealed-dummy-credentials.yaml 
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: dummy-credentials
  namespace: default
spec:
  encryptedData:
    password: AgBPjqTkBABQZ4i/t/AcvjlbMqpnt/BIp2RWGzpDRc+7s7Qyju/o75xTcVCVls0i+8Jt6E4bPaiYzwVBn5IyaeU5C2EDKuJAWWUYK69TRNac4fadVijO6suTRbBPWwb2tUWRkqcz7bJBsOqzRnCqyW5cYsPkcgs3uHGnkEEIgSkMjEiiCHrVGosJuyrFmKeU+HctYhgPwUk+sHnjckFbFAftQR4KzOith3TAzLEOltqXIoR+ovk6yVly1jH0BsGa/neW7JEXf0BFo/OlHy1hue1T7EjllMrP3lw6Ro234WtR65JzRPhpIojDqgJmOyu921bGMW8WB1hhmX3R//uiNkgmVprbbqD0CkpNYZtWL+djki2iYG9uXyVdDltwTtDeEOdvxyhACTWb5Oi1jv6Tq+OdFZN0eXLPssncBw994vyqCmAWG0N2rY8xN8dTT35i7C7QYFg9rPQMVrcxxluCTY3QNxFJED89rBM4tbnnEDxs11tHYmBdv/HQt0RXKqLld3FXx6lvZfdhan8Z2bSb5whE2OWzxarmV5/1VSv6l+SgDYTYx1N1JgDf1+309nNYj8daK9Y4ldgOyc4P9h69XqNeqVPfQ/li5NiSXA2BVDeZoVAQinowCdjPtbU8XKkNotb0zCdtSyNHdXw5vJKwfEZsKG1Kd9O7nOZuRSy4vRHCuYo0XiUzZ0nM+KJRGTo6pfFU2bkrCE4=
    username: AgBFe8Jswol6vBtQ/GUJf0WFgdIrpKAQwZCq+wp43bW3SvA4B8WjK6aqEbF9UZ8ZRDN4K/JC/ohJ9KKINpTrIk5l+pwJ5SYeUcjJOfMzeiBtlhdQ4D12IynIYSPTS/k8XHlGTOWCzokIijR7VXrTw0/O0djenZFwqFiD2qZurlm1r8AJvNYPVZr7cX7R65GCu1io33vvgBWMcGpBnayvopknEvOjDTd6XHsa/f9cLuxZCjb+MhF/b25znoS3lqWPWcxC9vgSYrgLtl8NtQgAyWB7iX1yy/0sGAye2BPinafendTzLCvwGjkv/0Kz5KEcXQ8o8SIhwlmp7+UDTG/Hjd55216fOGGDLTCIsHoEk6r3iuS1t3WY0kp2l9rRmjirkNJzN3A5MhNWdyAVTUT2WqC5Sz/jiVS0wYLPkM8X8eF2pyKC3i+WjV1f/choUi3FVMzgCxJMnxbdfHjibVLJ9TvOgLFLF/BkkJiBq3LY9ubc50rq+fbxZuWFLCOzolUDgljDoIK4UZ/VxMUM6cHlntr89C3U0EDMClWaoEJl3bdNOeAdWpP25mHiNB6fSbbQ9lhK2/pQRUWbgAnh2S6QUnuGRk3apEADK91FO1Lq7SICE5SgScl0DIl7vtJ6IhvmSX0jT1r/VzGtcmox9gvk9ONmqZfeStdgGnDdgFDkaiBhLcXK9YgCziCNlzYrUArlZx7q6z9yJw==
  template:
    data: null
    metadata:
      creationTimestamp: null
      name: dummy-credentials
      namespace: default
```

Este *SealedSecret* contiene la información *sensible* encriptada, por lo que puede publicarse en GitHub o en cualquier otro sitio.

Creamos el *SealedSecret* en Kubernetes usando `kubectl apply`:

```bash
$ k create -f sealed-dummy-credentials.yaml 
sealedsecret.bitnami.com/dummy-credentials created
```

Validamos que el *secret* se ha creado en el *namespace* `default`:

```bash
$ k get secret dummy-credentials -o yaml
apiVersion: v1
data:
  password: cGF0YXRh
  username: YWRtaW4=
kind: Secret
metadata:
  creationTimestamp: "2021-06-17T20:53:18Z"
  managedFields:
  ...
    manager: controller
    operation: Update
    time: "2021-06-17T20:53:18Z"
  name: dummy-credentials
  namespace: default
  ownerReferences:
  - apiVersion: bitnami.com/v1alpha1
    controller: true
    kind: SealedSecret
    name: dummy-credentials
    uid: aa797c53-6341-4e55-9574-5904d0811dbe
  resourceVersion: "352333"
  uid: 165ae758-cefe-4e20-a023-0fcb1385cbe1
type: Opaque
```

Podemos validar que el valor del campo `password: cGF0YXRh` corresponde con el valor con el que creamos el *secret*

```bash
$ echo -n cGF0YXRh | base64 -d
patata
```

### Actualización del *Secret*

Para actualizar el contenido del *secret* (por ejemplo, añadir una etiqueta):

1. Editamos el fichero `dummy-credentials.yaml` (o lo obtenemos consultando la API de Kubernetes `k get secret -o yaml`).
1. *Sellamos* el secreto
1. (Subimos el *SealedSecret* al repositorio de código)
1. Aplicamos el *SealedSecret* usando `k apply -f`
