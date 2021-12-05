#!/usr/bin/env bash
trap 'reportError' ERR

reportError() {
    echo "Error on line: $(caller)"
}

logger() {
    logLevel=${1} 
    logMsg=${2}

    echo "[$logLevel] $logMsg"

    if [[ $logLevel == "ERROR" ]]
    then
        echo "        Error at line $(caller)"
        exit 1
    fi
}

parse_cli_args () {
    PARAMS=""

    while (( "$#" ))
    do
        case "$1" in
            # -a|--bool-flag)
            #     BOOL_FLAG=0
            #     shift
            #     ;;
            -u|--user)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]
                then
                    k8sUSER="$2"
                    shift 2
                else
                    echo "Error: Argument for $1 is missing" >&2
                    exit 1
                fi
                ;;
            -g|--group)
                if [ -n "$2" ] && [ ${2:0:1} != "-" ]
                then
                    k8sGROUP="$2"
                    shift 2
                else
                    echo "Error: Argument for $1 is missing" >&2
                    exit 1
                fi
                ;;
            -*|--*=) # Unsupported flags
                echo "Error: Unsupported flag $1" >&2
                exit 1
                ;;
            *) # Preserve positional arguments
                PARAMS="$PARAMS $1"
                shift
                ;;
        esac
    done

    # Set positional arguments in their proper place
    eval set -- "$PARAMS"
}

check_required_parameters() {
    if [[ -z "${k8sUSER}" ]]
    then
        logger "ERROR" "\$u is requiered"
    fi

        if [[ -z "${k8sGROUP}" ]]
    then
        logger "ERROR" "\$g is requiered"
    fi
}

generate_key_if_not_exists() {
    # Generate user Key

    keyName=${1}
    if [[ -n ${2} ]]
    then
        keyBITS=${2}
    else
        keyBITS=4096
    fi

    if [[ -e ${keyName} ]]
    then
        logger "INFO" "${keyName} already exists."
    else
        logger "INFO" "Generating ${keyName} (${keyBITS} bits)..."
        openssl genrsa -out ${keyName} ${keyBITS}
    fi
}

generate_certificate_signing_request() {
    # Create Certificate Signing Request (CSR)
    if [[ -n ${1} ]]
    then
        keyOwner=${1}
    else
        logger "ERROR", "keyOwner is requiered."
    fi

    if [[ -n ${2} ]]
    then
        keyOwnerGroup=${2}
    else
        logger "ERROR", "keyOwnerGroup is requiered."
    fi

    logger "INFO" "Created CSR csr_${keyOwner}.csr"
    openssl req -new -key ${keyOwner}.key \
            -out csr_${keyOwner}.csr \
            -subj "/CN=${keyOwner}/O=${keyOwnerGroup}"
}

generate_csr_manifest() {
    if [[ -n ${1} ]]
    then
        keyOwner=${1}
    else
        logger "ERROR" "keyOwner is required"
    fi

    if [[ -n ${2} ]]
    then
        csrFile=${2}
    else
        logger "ERROR" "csrFile is required"
    fi

    if [[ -e ${csrFile} ]]
    then
        logger "INFO" "Generating base64EncodedCSR"
        base64EncodedCSR=$(cat ${csrFile} | base64 | tr -d '\n')
    else
        logger "ERROR" "csrFile not found!"
    fi
    
    logger "INFO" "Generating manifest csr_${keyOwner}_manifest.yaml"
    cat > csr_${keyOwner}_manifest.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${keyOwner}-csr
spec:
  signerName: kubernetes.io/kube-apiserver-client
  request: ${base64EncodedCSR}
  usages:
  - client auth
EOF
}

apply_csr_manifest() {
    if [[ -n ${1} ]]
    then
        csrManifestFile=${1}
    else
        logger "ERROR" "csrManifestFile required"
    fi

    if [[ -e ${csrManifestFile} ]]
    then
        logger "INFO" "Using $csrManifestFile"
    else
        logger "ERROR" "$csrManifestFile not found!"
    fi

    if [[ -n ${KUBECONFIG} ]]
    then
        logger "INFO" "Applying file ${csrManifestFile}"
        kubectl apply -f ${csrManifestFile}
    else
        logger "ERROR" "\$KUBECONFIG not set"
    fi
}

approve_csr() {
    if [[ -n ${1} ]]
    then
        csrToApprove=${1}
        isPending=$(kubectl get csr ${csrToApprove} -o jsonpath='{.items[*].status}')
        if [[ ${isPending} == "" ]]
        then
            logger "INFO" "${csrToApprove} is Pending for approval"
            logger "INFO" "Approving ${csrToApprove}..."
            kubectl certificate approve ${csrToApprove}
        else
            logger "ERROR" "${csrToApprove} is ${isPending}"
        fi
    else
        logger "ERROR" "csrToApprove is required!"
    fi
}

get_user_signed_certificate() {
    userCSR="${1}"
    userSignedCertificate="${1}_signed_certificate.crt"
    logger "INFO" "Generating $userSignedCertificate ..."
    kubectl get csr -o jsonpath="{.items[?(@.metadata.name==\"${k8sUSER}-csr\")].status.certificate}" | base64 --decode | tee ${userSignedCertificate}
}

get_current_context_from_kubeconfig() {
    kubectl config view -o jsonpath='{.current-context}'
}
get_server_from_kubeconfig() {
    clusterName="${1}"
    kubectl config view -o jsonpath="{.clusters[?(@.name==\"${clusterName}\")].cluster.server}"
}
get_cluster_ca_certificate_from_kubeconfig() {
    clusterName="${1}"
    kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"${clusterName}\")].cluster.certificate-authority-data}" | base64 --decode | tee cluster_ca_file.cert
}
create_user_kubeconfig() {
    k8sUSER="${1}"
    k8sClusterName="${2}"
    apiURL="${3}"
    clusterCA="${4}"

    logger "INFO" "[kubeconfig] Setting cluster \"${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-cluster ${k8sClusterName} \
        --server="${apiURL}" --certificate-authority="${clusterCA}" --embed-certs=true

    logger "INFO" "[kubeconfig] Setting user \"${k8sUSER}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-credentials ${k8sUSER} \
        --client-certificate=${k8sUSER}_signed_certificate.crt \
        --client-key=${k8sUSER}.key \
        --embed-certs=true

    logger "INFO" "[kubeconfig] Setting context to \"${k8sUSER}@${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config set-context ${k8sUSER}@${k8sClusterName} \
        --user="${k8sUSER}" --cluster="${k8sClusterName}"
    
    logger "INFO" "[kubeconfig] Setting default context to \"${k8sUSER}@${k8sClusterName}\"..."
    kubectl --kubeconfig=${k8sUSER}_kubeconfig config use-context ${k8sUSER}@${k8sClusterName}
}

parse_cli_args "$@"
check_required_parameters

generate_key_if_not_exists "${k8sUSER}.key" "4096"
generate_certificate_signing_request "${k8sUSER}" "${k8sGROUP}"
generate_csr_manifest "${k8sUSER}" "csr_${k8sUSER}.csr"
apply_csr_manifest "csr_${k8sUSER}_manifest.yaml"
approve_csr "${k8sUSER}-csr"
get_user_signed_certificate "${k8sUSER}"

currentContext=$(get_current_context_from_kubeconfig)
apiURL=$(get_server_from_kubeconfig $currentContext)
clusterCA=$(get_cluster_ca_certificate_from_kubeconfig $currentContext)

create_user_kubeconfig "${k8sUSER}" "kubernetes" "${apiURL}" "cluster_ca_file.cert"
