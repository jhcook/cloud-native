#!/usr/bin/env bash
#
# This nifty piece of code simply uses the Kubernetes API to check the
# readyReplicas which is a field in the status of the StatefulSets which
# Rancher uses to manage Prometheus instances. 
#
# Not much error handling is managed as this is a special-purpose piece of 
# code that is called programmatically.
#
# Usage: <script_name> <server_url> <token> [statefulset_name] [namespace]
#
# Author: Justin Cook

set -o errexit
set -o nounset
set -x

SERVER="$1"
TOKEN="$2"

# Since this is the cluster instance, there should only be one
NAMESPACE="cattle-prometheus"
STATEFULSET="prometheus-cluster-monitoring"
PODNAME="prometheus-cluster-monitoring-0"

# Get statefulset info
SSETINFO=`curl --silent --header "Authorization: Bearer ${TOKEN}" \
          -X GET \
          ${SERVER}/apis/apps/v1/namespaces/${NAMESPACE}/statefulsets/${STATEFULSET}`

# Get the pod info
PODINFO=`curl --silent --header "Authorization: Bearer ${TOKEN}" \
         -X GET \
         ${SERVER}/api/v1/namespaces/${NAMESPACE}/pods/${PODNAME}`

# Get the restartCount -- if it errors out there are no replicas and will be
# caught next.
#
# There are more than one container in this pod, so get them all and iterate
# through.
SSETRST=`jq -r '.status.containerStatuses[].restartCount' <<< "${PODINFO}" || \
         printf 0`

for cnt in ${SSETRST}
do
  if [ ${cnt} -gt 5 ]
  then
    exit 1
  fi
done

# Get the readyReplicas
REPLICAS=`jq -r '.status.readyReplicas' <<< "${SSETINFO}" || printf 0`

if [ ${REPLICAS} -lt 1 ]
then #Houston we have a problem
  exit 1
else
  exit 0
fi
