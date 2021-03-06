#!/usr/bin/env bash
#
# This code queries AWS endpoints using the AWS CLI to query each region for a
# list of regions and a list of volumes per region. If the volume does not have
# an attachment, it is printed to the screen with total provisioned amount of 
# storage.
#
# Usage: `basename $0` <aws_profile>
#
# Requires: AWS CLI, jq, and AWS tokens configured in credentials
#
# Author: Justin Cook <jhcook@secnix.com>

set -o errexit
set -o pipefail
set -o nounset

usage() {
  echo "usage: `basename $0` [-hv] <aws_profile>"
}

err() {
  usage
  exit 1
}

trap err ERR

declare _profile_

while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -h|--help)
      exit 0
    ;;
    -v|--verbose)
      set -o xtrace
      shift
    ;;
    *)
      _profile_="$1"
      shift
    ;;
  esac
done

test -z ${_profile_} && err

# Check if `aws` and `jq` are available. If not, bail
for cmd in 'aws --version' 'jq -h'
do 
  eval  ${cmd} > /dev/null 2>&1 || { echo "${cmd} not found in PATH" 1>&2; \
                                       exit 1; }
done

# Check if the aws profile is configures
PROFILE_LIST=`aws configure --profile ${_profile_} list`

# Set unattached GiB to 0 and increment as appropriate
declare -i gigs=0

# Get a list of all regions and iterate over each for EBS volume data on 
# unattached volumes
for region in `aws ec2 describe-regions --query Regions[*].[RegionName] \
               --output text --profile ${_profile_}`
do
  while read -r volname; read -r attachments; read -r size
  do
    if [ "${attachments}" = "[]" ]
    then
      volname="`echo $volname | sed 's/"//g'`"
      gigs+=${size}
      echo "${region}: ${volname}: ${size}"
    fi
  done < <(jq -c '.Volumes[]|.VolumeId,.Attachments,.Size' <(aws ec2 \
    describe-volumes --region ${region} --output json --profile ${_profile_}))
done

echo "Unattached GiB: ${gigs}"

