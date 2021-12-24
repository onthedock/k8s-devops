# Instalación de Longhorn usando Helm

Lanzamos la instalación de Longhorn usando Helm. Para ello usamos las instrucciones recogidas en la [documentación oficial (para la versión 1.2.2)](https://longhorn.io/docs/1.2.2/deploy/install/install-with-helm/):
<!-- markdownlint-disable MD031-->
1. Añadimos el repositorio de Helm para Longhorn:
   ```bash
   $ helm repo add longhorn https://charts.longhorn.io

   "longhorn" has been added to your repositories
   ```
1. Actualizamos los respositorios
   ```bash
   $ helm repo update
   Hang tight while we grab the latest from your chart repositories...
   ...Successfully got an update from the "longhorn" chart repository
   ... (UPDATING OTHER REPOS)
    Update Complete. ⎈Happy Helming!⎈
   ```
1. Instalamos Longhorn en el *namespace* `longhorn-system`; usamos la opción `--create-namespace` para crear el *namespace* si no existe):
   ```bash
   helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
   
   NAME: longhorn
   LAST DEPLOYED: Thu Nov 11 18:28:33 2021
   NAMESPACE: longhorn-system
   STATUS: deployed
   REVISION: 1
   TEST SUITE: None
   NOTES:
   Longhorn is now installed on the cluster!
   
   Please wait a few minutes for other Longhorn components such as CSI deployments, Engine Images, and    Instance Managers to be initialized.
   
   Visit our documentation at https://longhorn.io/docs/
   ```

## Validación del despliegue de Longhorn

Lanzamos el sguiente comando con `watch` para verificar que Longhorn descarga y arranca correctamente hasta que tenemos todos los pods en *running*:

```bash
$ watch kubectl -n longhorn-system get pod

NAME                                        READY   STATUS    RESTARTS   AGE
longhorn-ui-75ccbd4695-6t4v8                1/1     Running   0          20m
longhorn-manager-2tvh5                      1/1     Running   0          20m
longhorn-manager-9jnx9                      1/1     Running   0          20m
longhorn-driver-deployer-75f68555c9-n9tfc   1/1     Running   0          20m
longhorn-manager-kqgxz                      1/1     Running   0          20m
longhorn-csi-plugin-9k9n6                   2/2     Running   0          18m
csi-resizer-5c88bfd4cf-vqffl                1/1     Running   0          18m
csi-provisioner-669c8cc698-mqcd9            1/1     Running   0          18m
longhorn-csi-plugin-vq4nc                   2/2     Running   0          17m
csi-snapshotter-69f8bc8dcf-6dc66            1/1     Running   0          18m
instance-manager-e-bd042fdb                 1/1     Running   0          18m
instance-manager-r-32db8fdc                 1/1     Running   0          18m
csi-snapshotter-69f8bc8dcf-gh5mr            1/1     Running   0          18m
longhorn-csi-plugin-xblq2                   2/2     Running   0          17m
engine-image-ei-d4c780c6-m2rs9              1/1     Running   0          18m
csi-resizer-5c88bfd4cf-k2r4z                1/1     Running   0          18m
csi-provisioner-669c8cc698-xjmwj            1/1     Running   0          18m
csi-attacher-75588bff58-4fnh5               1/1     Running   0          18m
csi-provisioner-669c8cc698-vtz2s            1/1     Running   0          18m
csi-snapshotter-69f8bc8dcf-jgm66            1/1     Running   0          18m
csi-resizer-5c88bfd4cf-vqjph                1/1     Running   0          18m
csi-attacher-75588bff58-rxcm2               1/1     Running   0          18m
csi-attacher-75588bff58-zrh42               1/1     Running   0          18m
engine-image-ei-d4c780c6-nll8x              1/1     Running   0          18m
engine-image-ei-d4c780c6-km7g8              1/1     Running   0          18m
instance-manager-r-a5a4a271                 1/1     Running   0          18m
instance-manager-e-dc15c5a3                 1/1     Running   0          18m
instance-manager-r-90b90141                 1/1     Running   0          18m
instance-manager-e-59d48aff                 1/1     Running   0          18m
```

## Modificación de la *default storageClass* en el clúster

Tras instalar Longhorn, vemos que tanto `longhorn` como `local-path` están marcadas como `storageClass` por defecto:

```bash
$ kubectl get storageclass -o wide
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  46d
longhorn (default)     driver.longhorn.io      Delete          Immediate              true                   23m
```

Como se indica en la documentación de Kubernetes [Change the default StorageClass](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/#changing-the-default-storageclass):

> If two or more of them are marked as default, a `PersistentVolumeClaim` without `storageClassName` explicitly specified cannot be created.

Una `storageClass` se considera *default* si está anotada como `is-default-class=true`.
Cambiaremos el valor a `false` para la *storageClass* `local-path`:

```bash
$ kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
storageclass.storage.k8s.io/local-path patched
```

Validamos que tras modificar la anotación, sólo tenemos una *storageClass* por defecto en el clúster:

```bash
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io      Delete          Immediate              true                   41m
local-path           rancher.io/local-path   Delete          WaitForFirstConsumer   false                  46d
```

## Publicación de la consola via Ingress

Longhorn proporciona una consola con la que visualizar el almacenamiento del clúster.

El servicio que publica la consola es `longhorn-frontend`:

```bash
$ kubeclt get svc -n longhorn-system
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
longhorn-frontend   ClusterIP   10.43.238.195   <none>        80/TCP      15d
longhorn-backend    ClusterIP   10.43.150.204   <none>        9500/TCP    15d
csi-attacher        ClusterIP   10.43.167.71    <none>        12345/TCP   15d
csi-provisioner     ClusterIP   10.43.168.38    <none>        12345/TCP   15d
csi-resizer         ClusterIP   10.43.93.16     <none>        12345/TCP   15d
csi-snapshotter     ClusterIP   10.43.202.163   <none>        12345/TCP   15d
```

Definimos un *Ingress* para publicar el acceso a la consola de Longhorn en `http://longhorn.dev.lab`:

```yaml
---
apiVersion: networking.k8s.io/v1 # Kubernetes 1.19+
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    kubernets.io/ingress.class: traefik
  name: longhorn-console
  namespace: longhorn-system
spec:
  rules:
  - host: "longhorn.dev.lab"
    http:
      paths:
        - path: "/"
          pathType: Prefix
          backend:
            service:
              name: longhorn-frontend
              port:
                number: 80
```

## Versiones

```bash
$ kubectl version --short
Client Version: v1.22.3
Server Version: v1.22.4+k3s1
$ helm version --short
v3.6.2+gee407bd
$ helm -n longhorn-system list -o yaml
- app_version: v1.2.2
  chart: longhorn-1.2.2
  name: longhorn
  namespace: longhorn-system
  revision: "1"
  status: deployed
  updated: 2021-12-08 13:34:37.472618044 +0100 CET
```
