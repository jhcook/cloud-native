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

# We always know the pod name
PODNAME="prometheus-project-monitoring-0"

if [ $# -lt 4 ]
then
  #Get namespace
  NAMESPACE=`curl --silent --header "Authorization: Bearer ${TOKEN}" -X GET \
             ${SERVER}/api/v1/namespaces | \
             jq -r '.items[].metadata | select(.name | contains("cattle-prometheus-")) | .name'`
else
  NAMESPACE=$4
fi

if [ $# -lt 3 ]
then 
  #Get statefulset
  STATEFULSET=`curl --silent --header "Authorization: Bearer ${TOKEN}" -X GET \
               ${SERVER}/apis/apps/v1/namespaces/${NAMESPACE}/statefulsets | \
               jq -r '.items[].metadata.name'`
else
  STATEFULSET=$3
fi

# Get statefulset info
SSETINFO=`curl --silent --header "Authorization: Bearer ${TOKEN}" \
          -X GET \
          ${SERVER}/apis/apps/v1/namespaces/${NAMESPACE}/statefulsets/${STATEFULSET}`

# Get the pod info
PODINFO=`curl --silent --header "Authorization: Bearer ${TOKEN}" \
         -X GET \
         ${SERVER}/api/v1/namespaces/${NAMESPACE}/pods/${PODNAME}`

# Get the restartCount -- if it errors out that means there are no replicas,
# and it will be caught next.
#
# There are more than one container in this pod, so get them all and iterate
# through.
SSETRST=`jq -r '.status.containerStatuses[].restartCount' <<< "${PODINFO}" || \
         printf 0`

for cnt in $SSETRST
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
