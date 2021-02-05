# Despliegue de Tekton

- Un clúster de Kubernetes v1.15+ para Tekton Pipelines v.0.11.0
- RBAC habilitado en el clúster
- Un usuario con permisos de `cluster-admin`

## Versiones

- k3d con Kubernetes 1.19.4
- Tekton Pipelines v0.20.1
- Tekton CLI 0.15.0

## Instalación

> El método de instalación indicado en la documentación en el apartado *Getting Started* aplica un fichero YAML desde un repositorio en internet, lo que en general es una **muy mala idea**. Revisa el contenido del fichero antes de desplegar su contenido en el clúster.

El método recomendado para realizar la instalación es ejecutar:

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

Este comando instala la última versión disponible de Tekton; si quieres aplicar una versión concreta, usa:

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/previous/YOUR-VERSION/release.yaml
```

El listado completo de [versiones disponibles](https://github.com/tektoncd/pipeline/releases) se encuentra en GitHub.

Usaré la última versión disponible en este momento [`v0.20.1`](https://github.com/tektoncd/pipeline/releases/download/v0.20.1/release.yaml) [^1]:

```bash
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.20.1/release.yaml
```

El fichero crea el *namespace* `tekton-pipelines` y despliega todos los recursos en él.

```bash
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.20.1/release.yaml
namespace/tekton-pipelines created
podsecuritypolicy.policy/tekton-pipelines created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-controller-cluster-access created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-controller-tenant-access created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-webhook-cluster-access created
role.rbac.authorization.k8s.io/tekton-pipelines-controller created
role.rbac.authorization.k8s.io/tekton-pipelines-webhook created
role.rbac.authorization.k8s.io/tekton-pipelines-leader-election created
serviceaccount/tekton-pipelines-controller created
serviceaccount/tekton-pipelines-webhook created
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRoleBinding
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-cluster-access created
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-tenant-access created
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook-cluster-access created
Warning: rbac.authorization.k8s.io/v1beta1 RoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 RoleBinding
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-leaderelection created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook-leaderelection created
customresourcedefinition.apiextensions.k8s.io/clustertasks.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/conditions.tekton.dev created
Warning: apiextensions.k8s.io/v1beta1 CustomResourceDefinition is deprecated in v1.16+, unavailable in v1.22+; use apiextensions.k8s.io/v1 CustomResourceDefinition
customresourcedefinition.apiextensions.k8s.io/images.caching.internal.knative.dev created
customresourcedefinition.apiextensions.k8s.io/pipelines.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/pipelineruns.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/pipelineresources.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/runs.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/tasks.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/taskruns.tekton.dev created
secret/webhook-certs created
validatingwebhookconfiguration.admissionregistration.k8s.io/validation.webhook.pipeline.tekton.dev created
mutatingwebhookconfiguration.admissionregistration.k8s.io/webhook.pipeline.tekton.dev created
validatingwebhookconfiguration.admissionregistration.k8s.io/config.webhook.pipeline.tekton.dev created
clusterrole.rbac.authorization.k8s.io/tekton-aggregate-edit created
clusterrole.rbac.authorization.k8s.io/tekton-aggregate-view created
configmap/config-artifact-bucket created
configmap/config-artifact-pvc created
configmap/config-defaults created
configmap/feature-flags created
configmap/config-leader-election created
configmap/config-logging created
configmap/config-observability created
configmap/config-registry-cert created
deployment.apps/tekton-pipelines-controller created
service/tekton-pipelines-controller created
horizontalpodautoscaler.autoscaling/tekton-pipelines-webhook created
poddisruptionbudget.policy/tekton-pipelines-webhook created
deployment.apps/tekton-pipelines-webhook created
service/tekton-pipelines-webhook created
```

Para eliminar los *warning* por el uso de una `apiVersion` desaconsejada, modificamos el fichero de definción de los recursos, sustituyendo:

- todas las apariciones de `rbac.authorization.k8s.io/v1beta1` por `rbac.authorization.k8s.io/v1`

> Si cambiamos `apiextensions.k8s.io/v1beta1` por `apiextensions.k8s.io/v1` obtengo un error de validación del YAML, por lo que lo dejamos sin corregir:

```bash
error: error validating "docs/tekton/deploy/release-v0.20.1-no-warnings.yaml": error validating data: [ValidationError(CustomResourceDefinition.spec): unknown field "subresources" in io.k8s.apiextensions-apiserver.pkg.apis.apiextensions.v1.CustomResourceDefinitionSpec, ValidationError(CustomResourceDefinition.spec): unknown field "version" in io.k8s.apiextensions-apiserver.pkg.apis.apiextensions.v1.CustomResourceDefinitionSpec, ValidationError(CustomResourceDefinition.spec): missing required field "versions" in io.k8s.apiextensions-apiserver.pkg.apis.apiextensions.v1.CustomResourceDefinitionSpec]; if you choose to ignore these errors, turn validation off with --validate=false
```

Una vez modificado, aplicamos el fichero corregido.

Tras unos instantes, comprobamos que se han desplegado todos los componentes y que se ejecutan con normalidad:

```bash
$ kubectl get all -n tekton-pipelines
NAME                                               READY   STATUS    RESTARTS   AGE
pod/tekton-pipelines-controller-769bcc6996-6fjbm   1/1     Running   0          24m
pod/tekton-pipelines-webhook-76d9b48fff-w7cj7      1/1     Running   0          24m

NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                              AGE
service/tekton-pipelines-controller   ClusterIP   10.43.10.159    <none>        9090/TCP,8080/TCP                    24m
service/tekton-pipelines-webhook      ClusterIP   10.43.133.203   <none>        9090/TCP,8008/TCP,443/TCP,8080/TCP   24m

NAME                                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/tekton-pipelines-controller   1/1     1            1           24m
deployment.apps/tekton-pipelines-webhook      1/1     1            1           24m

NAME                                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/tekton-pipelines-controller-769bcc6996   1         1         1       24m
replicaset.apps/tekton-pipelines-webhook-76d9b48fff      1         1         1       24m

NAME                                                           REFERENCE                             TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/tekton-pipelines-webhook   Deployment/tekton-pipelines-webhook   14%/100%   1         5         1          24m
```

## Volúmenes persistentes

Para ejecutar un flujo de CI/CD es necesario proporcionar a Tekton un *persistent volume*. Por defecto, Tekton solicita un volumen de 5Gi con la *storage class* definida por defecto en el clúster.

El tamaño y *storage class* usada por Tekton puede configurarse a través del *configMap* `config-artifact-pvc`.

```bash
kubectl create configmap config-artifact-pvc \
                         --from-literal=size=10Gi \
                         --from-literal=storageClassName=manual \
                         -o yaml -n tekton-pipelines \
                         --dry-run=client | kubectl replace -f -
```

## *Service account* para Tekton

Tekton usa la *service account* `default` del clúster; se puede configurar esta opción a través del *configMap* `config-defaults`.

```bash
kubectl create configmap config-defaults \
                         --from-literal=default-service-account=YOUR-SERVICE-ACCOUNT \
                         -o yaml -n tekton-pipelines \
                         --dry-run=client  | kubectl replace -f -
```

## Herramienta de línea de comando `tkn`

La instalación de la herramienta de línea de comandos `tkn` es opcional, pero recomendada.

En linux, para distribuciones basadas en el gestor de paquetes `deb` la instalación puede realizarse a través de los repositorios o bien a partir de la lista de *releases* [disponibles en GitHub](https://github.com/tektoncd/cli/releases) [^2].

En mi caso he instalado la última versión disponible `0.15.0`:

```bash
curl -LO https://github.com/tektoncd/cli/releases/download/v0.15.0/tektoncd-cli-0.15.0_Linux-64bit.deb
sudo apt install ./tektoncd-cli-0.15.0_Linux-64bit.deb
```

Una vez instalada, validamos con:

```bash
$ tkn version
Client version: 0.15.0
Pipeline version: v0.20.1
```

## Referencias

- [Getting Started](https://tekton.dev/docs/getting-started/)

[^1]: He descargado el documento para tener una copia en la carpeta `deploy/`.
[^2]: Las instrucciones de instalación a partir del paquete `deb` son incorrectas. He abierto la *pull request* [Fix install instructions for deb-based distros #244](https://github.com/tektoncd/website/pull/244) para corregirlo.
