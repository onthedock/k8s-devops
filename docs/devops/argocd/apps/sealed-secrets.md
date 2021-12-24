# Nueva aplicación (usando Helm)

Vamos a desplegar *Sealed Secrets* usando la Helm Chart mediante una *application* de ArgoCD.

> Hemos elegido *Sealed Secrets* porque no realizamos ninguna configuración sobre la *Helm Chart*; además, es la aplicación elegida como ejemplo en la documentación de ArgoCD para desplegar aplicaciones usando [Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/) charts.

## Creación automática del *Namespace* (si no existe)

En el [issue 1809-"Automatically create namespace with application"](https://github.com/argoproj/argo-cd/issues/1809#issuecomment-860123674), se indica que la opción existe como parte de `application.yaml` en el repositorio oficial (aunque no aparece en la documentación):

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

## Sincronización automática

En la documentación oficial de ArgoCD, se pueden consultar las opciones disponibles para la sincronización automática: [Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/).

## Definición de la aplicación

```yaml hl_lines="16 17 18"
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  project: default
  source:
    chart: sealed-secrets
    repoURL: https://bitnami-labs.github.io/sealed-secrets
    targetRevision: 1.16.1
    helm:
      releaseName: sealed-secrets
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated: {}
  destination:
    server: https://kubernetes.default.svc
    namespace: sealed-secrets
```
