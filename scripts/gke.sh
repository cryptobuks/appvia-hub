#!/bin/bash
#
# Copyright (C) 2019  Rohith Jayawardene <gambol99@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

log()    { (2>/dev/null echo -e "$@"); }
info()   { log "[info] $@";  }
error()  { log "[error] $@"; }
failed() { log "[fail] $@"; exit 1; }

GCLOUD="/opt/google-cloud-sdk/bin/gcloud --quiet --no-user-output-enabled --verbosity=error"

AUTHORIZED_MASTER_CIDRS=""
CLUSTER_ADDONS=""
CLUSTER_CIDR=""
CLUSTER_VERSION="latest"
DEFAULT_ADDONS="HorizontalPodAutoscaling,HttpLoadBalancing"
ENABLE_ADDON=""
ENABLE_AUTOREPAIR="true"
ENABLE_AUTOSCALER="true"
ENABLE_AUTOUPGRADE="true"
ENABLE_GRAFANA_ADDON="true"
ENABLE_LOGGING="true"
ENABLE_LOKI_ADDON="true"
ENABLE_MONITORING="true"
ENABLE_NETWORK_POLICIES="true"
ENABLE_POD_SECURITY_POLICIES="true"
ENABLE_PRIVATE_NETWORK="true"
MAX_NODES=10
NETWORK="default"
REGION="europe-west2"
SERVICES_CIDR=""
SIZE="1"
SUBNETWORK="default"

IFS='' read -r -d '' DEFAULT_PSP <<"EOF"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: default:psp
rules:
- apiGroups:
  - policy
  resourceNames:
  - gce.unprivileged-addon
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: default:psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: default:psp
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts
EOF

IFS='' read -r -d '' DEFAULT_CLUSTER_ADMIN <<"EOF"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster:admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin
  namespace: kube-system
EOF

# enable the debugging mode
[[ ${DEBUG} == "true" ]] && set -x

usage() {
  cat <<EOF
  $(basename $0) [options]
  --build)                    Indicates we are createing a new cluster and deploying any assets
  --destroy)                  Indicates we are destroying a previously created cluster

  Options:
  --account PATH                       The path to the GCP service account file credentials (defaults: ${GOOGLE_APPLICATION_CREDENTIALS})
  --authorize-master-cidr              A key value pair or name of cidr authorized to speak to master api when in private mode
  --cluster-addon NAME                 A comma separated list of addons for this cluster (defaults: ${DEFAULT_ADDONS})
  --cluster-cidr CIDR                  An optional network cidr used for the pods (defaults: ${CLUSTER_CIDR})
  --enable-autorepair BOOL             Indicates if the auto repair feature in the cluster (defaults: ${ENABLE_AUTOREPAIR})
  --enable-autoscaler BOOL             Indicates if the autoscaler should be running in the cluster (defaults: ${ENABLE_AUTOSCALER})
  --enable-autoupgrade BOOL            Indicates if the autoupgrade feature is enabled on the default pool (defaults: ${ENABLE_AUTOUPGRADE})
  --enable-grafana-deployment BOOL     Indicates we should deploy a grafana installation post creation (defaults: ${ENABLE_GRAFANA_ADDON})
  --enable-logging BOOL                Indicates is stackdriver kubernetes logging is enabled (defaults: ${ENABLE_LOGGING})
  --enable-loki-deployment BOOL        Indicates we should deploy a loki deployment post creation (defaults: ${ENABLE_LOKI_ADDON})
  --enable-monitoring BOOL             Indicates is stackdriver kubernetes metrics monitoring is enabled (defaults: ${ENABLE_MONITORING})
  --enable-network-policies BOOL       Indicates if network policies should be enabled in cluster (defaults: ${ENABLE_NETWORK_POLICIES})
  --enable-pod-security-policies BOOL  Indicates if pod security policies should be enabled in cluster (defaults: ${ENABLE_POD_SECURITY_POLICIES})
  --enable-private-network BOOL        Indicates if the nodes should be on a private network (defaults: ${ENABLE_PRIVATE_NETWORK})
  --name NAME                          The name of the cluster you are actioning on (defaults: "")
  --network NAME                       The name of the VPC network to use when creating the cluster (defaults: ${NETWORK})
  --output PATH                        The path to the file containing the cluster details post creation
  --region REGION                      The GCP region the GKE cluster should be created within (defaults: ${REGION})
  --services-cidr CIDR                 An optional CIDR used to place cluster servies into (defaults: ${SERVICES_CIDR})
  --size INT                           The initial size of the GKE cluster (defaults: ${SIZE})
  --max-nodes INT                      If autoscaling is enabled, this is the max nodes permitted (defaults: ${MAX_NODES})
  --subnetwork NAME                    The name of the GCP subnetwork the cluster should reside (defaults: ${SUBNETWORK})
  --version K8S_VERSION                The version of kubernetes the cluster should run (defaults: ${CLUSTER_VERSION})
  --help                               display this usage menu
EOF
  if [[ -n $@ ]]; then
    error "$@"
    exit 1
  fi
  exit 0
}

# provision is the entrypoint for provisioning a new gke cluster
provision() {
  [[ -n "${ACCOUNT}" ]] || usage "you have not specified a GCP credenetials account file"
  [[ -f "${ACCOUNT}" ]] || usage "${ACCOUNT} either doesn't exist or is not a file"
  [[ -n ${OUTPUT}    ]] || usage "you have to specify a output file"

  # @step: provision gcp auth
  if ! provision-auth; then
    failed "unable to provision the gcp credentials"
  fi

  # @step: build the cluster
  ( provision-gke && authenticate && wait-on ) || failed "provisioning cluster: ${CLUSTER_NAME}";

  # @step: if private networking is enabled, provision a nat device
  if [[ ${ENABLE_PRIVATE_NETWORK} == "true" ]]; then
    provision-nat || failed  "deploying a cloud-nat for the private nodes"
  fi

  # @step: apply a default psp
  if [[ "${ENABLE_POD_SECURITY_POLICIES}" == "true" ]]; then
    info "applying the default pod security policy"
    echo "${DEFAULT_PSP}" | kubectl apply -f - >/dev/null || failed ""
  fi

  # @step: apply a default cluster admin
  if ! echo "${DEFAULT_CLUSTER_ADMIN}" | kubectl apply -f - >/dev/null; then
    failed "unable to create the default cluster admin"
  fi

  # @step: deploy the grafana dashboard and loki?
  if [[ ${ENABLE_GRAFANA_ADDON} == "true" ]]; then
    info "deploying the grafana deployment - @@TODO"
  fi

  # @step: should we deploy loki
  if [[ ${ENABLE_LOKI_ADDON} == "true" ]]; then
    info "deploying the loki deployment - @@TODO"
  fi

  # @step: out the kubernetes integration config
  KUBE_CERTIFICATE_CA=$(kubectl config view --minify --raw | awk '/certificate-authority-data/ { print $2 }')
  KUBE_SA_NAME=$(kubectl -n kube-system get sa admin -o json | jq '.secrets[0].name' -r)
  KUBE_SA_TOKEN=$(kubectl -n kube-system get secret ${KUBE_SA_NAME} -o json | jq '.data["token"]' -r)
  KUBE_SERVER_URL=$(kubectl config view --minify | awk '/server/ { print $2 }')

  cat <<EOF > ${OUTPUT}
SERVER_URL=${KUBE_SERVER_URL}
SERVER_CA=${KUBE_CERTIFICATE_CA}
SERVER_TOKEN=${KUBE_SA_TOKEN}
EOF
}

# destroy is responsible for deleting the gke cluster
destroy() {
  [[ -n "${ACCOUNT}"    ]] || usage "you have not specified a GCP credenetials account file"
  [[ -f "${ACCOUNT}"    ]] || usage "${ACCOUNT} either doesn't exist or is not a file"
  [[ -n ${CLUSTER_NAME} ]] || usage "you must specify the cluster name"
  [[ -n ${REGION}       ]] || usage "you have not specified a gcp region"

  # @step: provision gcp auth
  if ! provision-auth; then
    failed "unable to provision the gcp credentials"
  fi

  if ! has-cluster; then
    failed "the cluster: ${CLUSTER_NAME} does not exist in region: ${REGION}"
  fi

  info "attempting to delete the cluster: ${CLUSTER_NAME}, region: ${REGION}"
  if ! ${GCLOUD} container clusters delete ${CLUSTER_NAME}; then
    failed "trying to the delete the cluster: ${CLUSTER_NAME}"
  fi

  # @@TODO: how can we delete the cloud-nat? if no clusters exist?

  info "successfully deleted the cluster"
}

# provision-auth is responsible for setting up the gcp auth
provision-auth() {
  # @step: provision the account configuration
  if ! ${GCLOUD} auth activate-service-account --key-file=${ACCOUNT}; then
    error "unable to activate the credentials file: ${ACCOUNT}"
    return 1
  fi

  # @step: extract the project from service account
  PROJECT=$(jq '.project_id' -r ${ACCOUNT})
  if [[ $? -ne 0 ]]; then
    error "failed to extract the project from accounts file: ${ACCOUNT}"
    return 1
  fi
  if [[ -z ${PROJECT} ]]; then
    error "unable to find project in the accounts file: ${ACCOUNT}"
    return 1
  fi

  EMAIL=$(jq '.client_email' -r ${ACCOUNT})
  if [[ $? -ne 0 ]]; then
    error "failed to extract the email from accounts file: ${ACCOUNT}"
    return 1
  fi
  if [[ -z ${EMAIL} ]]; then
    error "unable to find email in the accounts file: ${ACCOUNT}"
    return 1
  fi

  # @step: update the gcloud command
  GCLOUD="${GCLOUD} --project ${PROJECT} --account ${EMAIL}"
}

# authenticate is responsible for retrieving the credentials for the k8s cluster
authenticate() {
  ${GCLOUD} container clusters get-credentials \
    ${CLUSTER_NAME} --region ${REGION} >/dev/null 2>&1 && return 0 || return 1
}

# wait-on is responsible for waiting on the master api to become available
wait-on() {
  local timeout=${1:-400}
  info "waiting on the master api to come up, timeout: ${timeout}"

  local checks=0
  for ((j=0; j<3; j++)); do
    for ((i=0; i<${timeout}; i++)); do
      if kubectl --request-timeout=2s get node >/dev/null 2>&1; then
        checks=$((checks+=1))
        break
      fi
      sleep 1
    done
    [[ ${checks} -ge 3 ]] && return 0 || sleep 5
  done

  return 1
}

# has-cluster is responsible for checking if the cluster exists
has-cluster() {
  resp=$(${GCLOUD} container clusters describe ${CLUSTER_NAME} --region=${REGION} 2>&1)
  if [[ $? -ne 0 ]]; then
    # @check if this is a known error, else we quit to be same
    if [[ ! "${resp}" =~ ^.*[nN]ot.[fF]ound.*$ ]]; then
      failed "checking the status of the cluster: ${CLUSTER_NAME}"
    fi
    return 1
  fi

  return 0
}

# provision-nat is responsble for provisioning a nat device
provision-nat() {
  info "attempting to deploy a cloud nat device for external internet access"

  # @step: check if a cloud-nat exists already
  resp=`${GCLOUD} compute routers nats describe cloud-nat --region=${REGION} --router=router 2>&1`
  if [[ $? -ne 0 ]]; then
    if [[ ! "${resp}" =~ ^.*not.found.*$ ]]; then
      error "unable to check status of cloud nat"
      return 1
    fi

    # @step: provision a cloud-nat device
    if ! ${GCLOUD} compute routers nats create cloud-nat \
      --auto-allocate-nat-external-ips \
      --nat-all-subnet-ip-ranges \
      --router=router \
      --router-region=${REGION}; then
      return 0
    fi
  else
    info "skipping provisioning of nat device as one already exists"
  fi
}

# provision-gke is responsible for provisioning the gke cluster
provision-gke() {
  # @check the options are there
  [[ -n ${CLUSTER_NAME} ]] || usage "you must specify the cluster name"
  [[ -n ${REGION}       ]] || usage "you have not specified a gcp region"

  # @check a cluster already exists with the same name
  if ! has-cluster; then
    info "attempting to build the cluster: ${CLUSTER_NAME}, region: ${REGION}"

    local opts=""
    [[ ${ENABLE_AUTOREPAIR} == "true"            ]] && opts="${opts} --enable-autorepair"
    [[ ${ENABLE_AUTOUPGRADE} == "true"           ]] && opts="${opts} --enable-autoupgrade"
    [[ ${ENABLE_LOGGING} == "true"               ]] && opts="${opts} --enable-cloud-logging"
    [[ ${ENABLE_MONITORING} == "true"            ]] && opts="${opts} --enable-cloud-monitoring"
    [[ ${ENABLE_NETWORK_POLICIES} == "true"      ]] && opts="${opts} --enable-network-policy"
    [[ ${ENABLE_POD_SECURITY_POLICIES} == "true" ]] && opts="${opts} --enable-pod-security-policy"
    [[ ${ENABLE_AUTOSCALER} == "true"            ]] && opts="${opts} --enable-autoscaling --min-nodes=${SIZE} --max-nodes=${MAX_NODES}"
    [[ -n ${CLUSTER_CIDR}                        ]] && opts="${opts} --cluster-ipv4-cidr=${CLUSTER_CIDR}"
    [[ -n ${SERVICES_CIDR}                       ]] && opts="${opts} --services-ipv4-cidr=${SERVICES_CIDR}"

    if [[ ${ENABLE_PRIVATE_NETWORK} == "true" ]]; then
      opts="${opts} --enable-private-nodes --enable-master-authorized-networks"
      opts="${opts} --master-authorized-networks=${AUTHORIZED_MASTER_CIDRS:-"0.0.0.0/0"}"
      opts="${opts} --master-ipv4-cidr=${MASTER_CIDR:-"172.16.0.0/28"}"
    fi

    if ! ${GCLOUD} beta container clusters create \
      --addons=${DEFAULT_ADDONS}${CLUSTER_ADDONS} \
      --cluster-version=${CLUSTER_VERSION} \
      --enable-ip-alias \
      --enable-stackdriver-kubernetes \
      --image-type "COS" \
      --max-pods-per-node 110 \
      --network ${NETWORK} \
      --no-enable-basic-auth \
      --no-enable-legacy-authorization \
      --no-issue-client-certificate \
      --num-nodes ${SIZE} \
      --region=${REGION} \
      --subnetwork ${SUBNETWORK} ${opts} \
      ${CLUSTER_NAME}; then
      return 1
    fi
  fi

  return 0
}

# @step: process the command line
while [[ $# -ne 0 ]]; do
  case $1 in
  --build)                          ACTION="build";                  shift 1; ;;
  --destroy)                        ACTION="destroy";                shift 2; ;;
  --account)                        ACCOUNT="$2";                    shift 2; ;;
  --authorize-master-cidr)          AUTHORIZED_MASTER_CIDRS=${2};    shift 2; ;;
  --cluster-addon)                  CLUSTER_ADDONS=",${2}";          shift 2; ;;
  --cluster-cidr)                   CLUSTER_CIDR=${2};               shift 2; ;;
  --enable-autorepair)              ENABLE_AUTOREPAIR=${2};          shift 2; ;;
  --enable-autoscaler)              ENABLE_AUTOSCALER=$2;            shift 2; ;;
  --enable-autoupgrade)             ENABLE_AUTOUPGRADE=$2;           shift 2; ;;
  --enable-grafana-deployment)      ENABLE_GRAFANA_ADDON="$2";       shift 2; ;;
  --enable-logging)                 ENABLE_LOGGING=$2;               shift 2; ;;
  --enable-loki-deployment)         ENABLE_LOKI_ADDON="$2";          shift 2; ;;
  --enable-monitoring)              ENABLE_MONITORING=$2;            shift 2; ;;
  --enable-network-policies)        ENABLE_NETWORK_POLICIES=$2;      shift 2; ;;
  --enable-pod-security-policies)   ENABLE_POD_SECURITY_POLICIES=$2; shift 2; ;;
  --enable-private-network)         ENABLE_PRIVATE_NETWORK=$2;       shift 2; ;;
  --max-nodes)                      MAX_NODES=$2;                    shift 2; ;;
  --name)                           CLUSTER_NAME=${2};               shift 2; ;;
  --network)                        NETWORK=$2;                      shift 2; ;;
  --output)                         OUTPUT=$2;                       shift 2; ;;
  --region)                         REGION=$2;                       shift 2; ;;
  --services-cidr)                  SERVICES_CIDR=$2;                shift 2; ;;
  --size)                           SIZE=$2;                         shift 2; ;;
  --subnetwork)                     SUBNETWORK=$2;                   shift 2; ;;
  --version)                        CLUSTER_VERSION=$2;              shift 2; ;;
  --help|-h)                        usage;                           shift 2; ;;
  *)                                shift 1;                         ;;
  esac
done

case $ACTION in
  build)   provision; ;;
  destroy) destroy;   ;;
  *)       usage "you have not specified an action (build|destroy)"; ;;
esac
