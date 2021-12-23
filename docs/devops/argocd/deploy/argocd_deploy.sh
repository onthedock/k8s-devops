#!/usr/bin/env bash
EXIT_CODE_OK=0

argocdVersion='v2.2.1'
argocdURL="https://raw.githubusercontent.com/argoproj/argo-cd/${argocdVersion}/manifests/install.yaml"
argocdLocalInstallManifest="argocd-install-stable-${argocdVersion}.yaml"

# Descarga local de la versión estable del fichero de instalación
if [[ -e ${argocdLocalInstallManifest} ]]
then
    echo "File ${argocdLocalInstallManifest} already exists"
else
    wget --output-document ${argocdLocalInstallManifest} ${argocdURL}
fi

if [[ -z $KUBECONFIG ]]
then
    echo "\$KUBECONFIG must be defined"
    exit 1
fi

# Create namespace if it does not exists
argocdNamespaceExist=$(kubectl get namespace argocd)
if [[ $? -eq $EXIT_CODE_OK ]]
then
    echo "[INFO] Namespace 'argocd' already exists"
else
    kubectl create namespace argocd
fi

kubectl apply -n argocd -f ${argocdLocalInstallManifest}

# Wait until it is running

readyReplicas=$(kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.readyReplicas}')

until [[ $readyReplicas -eq 1 ]]
do
    clear
    echo "[INFO] Waiting for ArgoCD deployment to be ready..."
    readyReplicas=$(kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.readyReplicas}')
    sleep 2
done

echo "[INFO] ArgoCD server deployed."

echo "[INFO] Configuring insecure access (using ConfigMap)..."
kubectl apply -f argocd-cmd-params-cm.yaml
kubectl -n argocd rollout restart deploy argocd-server

echo "[INFO] Deploy Ingress (argocd.dev.lab)"
kubectl apply -f argocd-ingress-traefik.yaml
