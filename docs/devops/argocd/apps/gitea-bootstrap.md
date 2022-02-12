# Despliegue de Gitea (bootstrap) usando ArgoCD

Para desplegar las aplicaciones usando ArgoCD podemos usar Helm Charts o *manifests* que descargamos desde un repositorio.

En el caso de *Sealed Secrets* desplegamos la aplicación usando la Helm Chart directamente desde el repositorio oficial (no es necesario proporcionar parámetros personalizados).

Si necesitamos pasar parámetros a la Helm Chart, podemos especificarlos directamente en el CRD de ArgoCD o mediante un fichero `values.yaml` en el mismo repositorio donde se encuentra la Helm Chart.

Usamos uns instancia de Gitea a la que llamaremos en el *namespace* `bootstrap` para alojar los repositorios de las aplicaciones que desplegaremos mediante ArgoCD.

## Fichero `values.bootstrap.yaml`

> El ejemplo despliega Gitea 1.15.10, que introduce cambios en la estructura de los parámetros de la Helm Chart.

El fichero de valores para la instancia Gitea *bootstrap* es:

```yaml
---8<--- "docs/devops/helm/gitea/deploy/values.bootstrap.yaml"
```

## CRD de `application` en ArgCD para Gitea

El *manifest* del CRD `application` para el despliegue de Gitea es [^fichero_insertado]:

```yaml
---8<--- "argocd-apps/gitea/argocd-app-gitea.yaml"
```

[^fichero_insertado]: Este es el fichero que se encuentra en la carpeta `/argocd-apps` del repositorio.
