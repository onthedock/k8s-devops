# Instalación de Longhorn usando Helm

Lanzamos la instalación de Longhorn usando Helm. Para ello usamos las instrucciones recogidas en la [documentación oficial (para la versión 1.2.2)](https://longhorn.io/docs/1.2.2/deploy/install/install-with-helm/):

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

## Versiones

```bash
$ kubectl version --short
Client Version: v1.19.4
Server Version: v1.19.16+k3s1
$ helm version --short
v3.6.2+gee407bd
$ helm -n longhorn-system list -o yaml
- app_version: v1.2.2
  chart: longhorn-1.2.2
  name: longhorn
  namespace: longhorn-system
  revision: "1"
  status: deployed
  updated: 2021-11-11 18:28:33.36440462 +0100 CET
```
