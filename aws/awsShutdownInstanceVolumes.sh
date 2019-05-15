#!/usr/bin/env bash
#
# This code queries AWS endpoints using the AWS CLI to query each region for a
# list of regions and a list of shutdown instances per region. The EBS volumes
# attached to the instances are enumerated and the total provisioned amount of
# storage is calculated.
#
# Usage: `basename $0` <aws_profile>
#
# Requires: AWS CLI, jq, and AWS tokens configured in credentials
#
# Author: Justin Cook <jhcook@secnix.com>

set -o errexit
set -o pipefail
set -o nounset

export LANG="en.GB.UTF-8"

usage() {
  echo "usage: `basename $0` [-hv] <aws_profile>"
}

err() {
  usage
  exit 1
}

trap err ERR

declare _profile_=""

while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -h|--help)
      usage
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

# Check if `aws` and `jq` are available -- if not, bail.
for cmd in 'aws --version' 'jq -h'
do 
  eval ${cmd} > /dev/null 2>&1 || { echo "${cmd} not found in PATH" 1>&2; \
                                    exit 1; }
done

# Check if aws profile is configured
PROFILELIST=`aws configure --profile ${_profile_} list`

# Set GiB to 0 and increment as appropriate.
declare -i gigs=0

# Get a list of all regions and iterate over each.
for region in `aws ec2 describe-regions --query Regions[*].[RegionName] \
               --output text --profile ${_profile_}`
do # For the specified region and profile, list all stopped instances.
  INSTANCES=`aws ec2 describe-instance-status --region ${region} --output text \
             --profile ${_profile_} --filter \
             Name=instance-state-name,Values=stopped,stopping --no-paginate \
             --include-all-instances | awk '/^INSTANCESTATUSES/{print$3}'`

  if [ -n "${INSTANCES}" ]
  then # If a list of instances was received, retrieve a list of attached volumes.
    VOLUMES="`jq -c '.Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' \
            <(aws ec2 describe-instances --region ${region} --output json \
             --profile ${_profile_} --instance-ids ${INSTANCES}) | sed 's/"//g'`"

    while read -r volname; read -r size
    do # Read in the VolumeId and Size for each volume.
      volname="`echo $volname | sed 's/"//g'`"
      gigs+=${size}
      echo "${region}: ${volname}: ${size}"
    done < <(jq -c '.Volumes[]|.VolumeId,.Size' <(aws ec2 \
           describe-volumes --region ${region} --output json --profile \
           ${_profile_} --volume-ids ${VOLUMES}))
  fi
done
  
echo "Stopped GiB: $gigs"
