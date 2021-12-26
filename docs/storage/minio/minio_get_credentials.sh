#!/usr/bin/env bash

if [[ -z $KUBECONFIG ]]
then
        echo "\$KUBECONFIG not set"
        exit 1
else
        minioRootUser=$(kubectl get secret minio-rootuser-secret -n minio -o jsonpath='{.data.rootUser}' | base64 -d)
        minioRootPassword=$(kubectl get secret minio-rootuser-secret -n minio -o jsonpath='{.data.rootPassword}' | base64 -d)
        echo "rootUser:" > minio-credentials.txt
        echo "$minioRootUser" >> minio-credentials.txt
        echo "rootPassword:" >> minio-credentials.txt 
        echo "$minioRootPassword" >> minio-credentials.txt 
fi
