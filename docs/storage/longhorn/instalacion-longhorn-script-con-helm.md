# Instalación de Longhorn usando Helm (con script en BASH)

Con el objetivo de desplegar Longhorn de forma automatizada, usamos un *script*.

El *script* comprueba si la *chart* de Helm ya se encuentra instalada antes de lanzar el comando *helm install* (en caso contrario, Helm mostraría un error):

```bash
function installHelmChart {
    helmChart="$1"
    helmRepoChart="$2"
    chartNamespace="$3"

    checkRelease=$(helm status $helmChart --namespace $chartNamespace 2>/dev/null| grep -i status | awk '{ print $2 }')

    if [ "$checkRelease" != "deployed" ]
    then
        echo "...Installing longhorn"
        helm install $helmChart $helmRepoChart --namespace $chartNamespace --create-namespace
    else
        echo "... $helmChart is already installed in the namespace $chartNamespace"
    fi
}
```

La instalación de Longhorn establece `longhorn` como *default* `storageClass` en el clúster, pero no elimina la anotación de la `storageClass` que estuviera establecida como `storageClass` por defecto; para evitar problemas al tener más de una `storageClass` por defecto en el clúster, eliminamos la anotación del resto de clases de almacenamiento:

```bash
function setDefaultStorageClass {
    defaultStorageClass="$1"
    storageClassList=$(kubectl get storageclass -o name | awk -F '/' '{print $2}')

    for storageclass in $storageClassList
    do
        if [ "$storageclass" = "$defaultStorageClass" ]
        then
            echo "Set default storageClass for $storageclass"
            kubectl patch storageclass $storageclass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        else
            echo "Removing default storageClass for $storageclass"
            kubectl patch storageclass $storageclass -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        fi
    done
}
```

El *script* completo se encuentra en la subcarpeta carpeta `scripts/`.
