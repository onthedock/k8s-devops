#!/usr/bin/env bash

function getKubeconfig {
    scriptDir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if test -f "kubeconfig"
    then
        echo "Using $scriptDir/kubeconfig"
        export KUBECONFIG=$scriptDir/kubeconfig
    elif test -f $HOME/.kube/config
    then
        echo "Using default kubeconfig at $HOME/.kube/config"
    elif [[ -z "$KUBECONFIG" ]]
    then
        echo "ERROR - Unable to find a valid kubeconfig"
        exit 1
    else
        echo "Using \$KUBECONFIG=$KUBECONFIG"
    fi
}


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

function main {
    getKubeconfig

    # Those commands are idempotent
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    
    installHelmChart "longhorn" "longhorn/longhorn" "longhorn-system"
    setDefaultStorageClass "longhorn"
}

main
