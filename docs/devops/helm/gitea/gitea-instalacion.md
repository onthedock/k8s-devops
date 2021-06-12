# Instalación de la Chart para Gitea

Antes de instalar Gitea, creamos el *namespace* `code`, en el que desplegaremos Gitea:

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
    name: code
```

La instalación de Gitea usando la *chart* oficial se describe en la documentación [Installation with Helm (on Kubernetes)](https://docs.gitea.io/en-us/install-on-kubernetes/); consiste en dos pasos:

1. Añadir el repo oficial Helm para Gitea `helm repo add gitea-charts https://dl.gitea.io/charts/`
1. Instalar la *chart* de Gitea

La cuestión es que, en general, no queremos instalar la *chart* con los valores por defecto; algunos valores serán específicos para cada instalación y por tanto debemos configurarlos.

Helm permite usar parámetros que sobrescriban los valores por defecto en el comando de ejecución de `helm install` de varios modos: usando `--values/-f` o `--set` o `--set-file`.

Descargamos el fichero [`values.yaml`](https://gitea.com/gitea/helm-chart/raw/branch/master/values.yaml) del repositorio oficial de la *chart* para Gitea:

```bash
wget -O values.original.yaml https://gitea.com/gitea/helm-chart/raw/branch/master/values.yaml
```

Copiamos el fichero original para tener una copia de seguridad:

```bash
cp values.original.yaml values.custom.yaml
```

Editamos el fichero para adaptarlo a nuestro entorno [^fichero_insertado] (las líneas resaltadas son las modificadas respecto a la configuración por defecto en la *chart*):

```yaml hl_lines="9 10  29 3 34 145 146 147 148 151 155 159"
---8<--- "docs/devops/helm/gitea/deploy/values.custom.yaml"
```

Finalmente lo instalamos con:

```bash
$ helm install gitea -n code -f values.custom.yaml gitea-charts/gitea
NAME: gitea
LAST DEPLOYED: Sat May 29 11:49:17 2021
NAMESPACE: code
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  echo "Visit http://127.0.0.1:3000 to use your application"
  kubectl --namespace code port-forward svc/gitea-http 3000:3000
```

Como vemos, al no usar un *Ingress* (y el *Service* es de tipo *ClusterIP*), sólo podemos acceder a Gitea usando `kubectl port-forward`, lo que no resulta muy útil.

## Configuración del *Ingress*

Una vez validada la instalación de Gitea, actualizamos la configuración para incluir un *Ingress*.

La configuración del *Ingress* depende del *Ingress Controller* instalado; en el caso de **k3d** (1.19.4), el *Ingress Controller* es Traefik.

En el fichero `values.custom.yaml` añadimos las anotaciones necesarias para Traefik y el nombre del *host* a través del cual accedemos a Gitea (resoluble a través de una entrada en mi fichero `/etc/hosts`):

```yaml hl_lines="5 6 9"
...
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: traefik
    ingress.kubernetes.io/ssl-redirect: "false"

  hosts:
    - code.k3d.lab
  tls: []
...
```

Con estas modificaciones, actualizamos la *release* de Gitea en el clúster:

```bash
$ helm upgrade -n code gitea gitea-charts/gitea -f values.custom.yaml
Release "gitea" has been upgraded. Happy Helming!
NAME: gitea
LAST DEPLOYED: Sat May 29 18:44:16 2021
NAMESPACE: code
STATUS: deployed
REVISION: 2
NOTES:
1. Get the application URL by running these commands:
  http://code.k3d.lab/
```

## Configuración de Gitea: `gitea.config`

Con Gitea desplegado, el siguiente paso es configurar la aplicación a través del bloque `gitea.config`. En esta sección podemos modificar el valor de cualquiera de las variables que aparecen en el fichero `app.ini` [^cheat_sheet].

Por mostrar cómo realizar la configuración, en el fichero `values.custom.yaml` he modificado la *landing page* a "login" y eliminado la posibilidad de que los usuarios creen sus propias cuentas (debe generarlas el administrador de Gitea):

```yaml
  config: 
    server:
      LANDING_PAGE: login
    service:
      DISABLE_REGISTRATION: true
```

[^fichero_insertado]: A continuación se muestra el fichero `values.custom.yaml` final, por lo que incluye modificaciones que se comentan más adelante en el artículo.

[^cheat_sheet]: [Configuration Cheat Sheet](https://docs.gitea.io/en-us/config-cheat-sheet/)
