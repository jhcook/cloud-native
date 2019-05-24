#!/usr/bin/env python3
#
# This code traverses each region in AWS and searches for resources in EC2
# that match tags provided.
#
# Usage: `basename $0` [-v][-r region1,region2] [-p profile] 
#                      <tag1=value,tag2=value,...,tagN=value>
#
# Requires: Python3, Boto 3
#
# Before you can begin using Boto 3, you should set up authentication 
# credentials. Credentials for your AWS account can be found in the IAM
# Console. You can create or use an existing user. Go to manage access keys and
# generate a new set of keys.
#
# If you have the AWS CLI installed, then you can use it to configure your credentials file:
# `aws configure`
#
# Author: Justin Cook <jhcook@secnix.com>

import sys, os, json, argparse, copy
from datetime import datetime

try:
  import boto3
  import dill as pickle
  from diskcache import Cache
except ModuleNotFoundError as err:
  print(err, file=sys.stderr)
  sys.exit(1)

class DateTimeEncoder(json.JSONEncoder):
  '''some objects are not serialisable to json'''
  def default(self, o):
    if isinstance(o, datetime):
      return o.isoformat()
    return json.JSONEncoder.default(self, o)

class EC2Resources:
  def __init__(self, session, filters, region=None):
    self.__session = session
    self.region = region
    self.__conn = self.__session.client("ec2", region_name=self.region)
    self.filters = filters
    self.instances = copy.copy(self.__conn.describe_instances)
    self.volumes = copy.copy(self.__conn.describe_volumes)

  @property
  def filters(self):
    return self.__filters
  
  @filters.setter
  def filters(self, filters):
    self.__filters = filters

  @property
  def region(self):
    return self.__region
  
  @region.setter
  def region(self, region):
    self.__region = region

  @property
  def instances(self):
    '''Get the instances'''
    return self.__instances

  @instances.setter
  def instances(self, callableFunc):
    self.__instances = callableFunc(Filters=self.filters)

  @property
  def volumes(self):
    '''Get the volumes'''
    return self.__volumes
  
  @volumes.setter
  def volumes(self, callableFunc):
    self.__volumes = callableFunc(Filters=self.filters)

  def __getstate__(self):
    return {'_EC2Resources__session': None, 
            '_EC2Resources__region': self.region, 
            '_EC2Resources__conn': None, 
            '_EC2Resources__filters': self.filters, 
            '_EC2Resources__instances': self.instances, 
            '_EC2Resources__volumes': self.volumes}  

def parse_args():
  parser = argparse.ArgumentParser()
  parser.add_argument("-v", "--verbosity", action="count", default=0,
                      help="print debugging messages. Multiple -v options " +
                      "increase verbosity.  The maximum is 3.")
  parser.add_argument("-r", "--region", type=str, 
                      help="use specified region(s) '-r us-west-1,us-west-2' " +
                      "defaults to configured region in profile. Use '-r all' " +
                      "for all regions.")
  parser.add_argument("-p", "--profile", type=str, 
                      help="use specified profile") 
  parser.add_argument("-i", "--ignore-cache", action="store_true", 
                      default=False, help="do not load but refresh the cache.")
  parser.add_argument("tags", type=str, help="specify tags to search, e.g. " +
                      "stack_name=test,test01;role=hadoop,hbase")
  args = parser.parse_args()
  args.region = args.region.split(',')
  args.tags = [dict(item.split("=") for item in args.tags.split(";"))]
  return args

def main():
  # Sort command-line parameters
  args = parse_args()

  filters = [{'Name':'tag:{}'.format(list(item.keys())[0]), 
              'Values':list(item.values())} for item in args.tags]
  if args.verbosity: print("filters: {}".format(filters))

  # Create a session and connection to ec2
  session = boto3.Session(profile_name=args.profile)
  conn = session.client('ec2')

  # Create region list
  if args.region[0] == 'all':
    userRegion = [ region['RegionName'] for region in [ region for region in 
    conn.describe_regions()['Regions']]]
  else:
    userRegion = args.region
  if args.verbosity: print("userRegion: {}".format(userRegion))

  # Cache results to disk
  cache = Cache(os.path.expanduser('~') + '/.awstools')
  
  regions = []
  for region in userRegion:
    k = "{}_{}_{}".format(args.profile, region, '_'.join(["{}_{}".format(x, y) 
                                     for f in filters for x, y in f.items()]))
    if args.verbosity > 3: print(k)
    try:
      if not args.ignore_cache:
        regions.append({k:pickle.loads(cache[k])})
        if args.verbosity > 1: print("{} from cache".format(k))
      else:
        raise KeyError
    except KeyError:
      regions.append({k:EC2Resources(session, filters, region)})
      if args.verbosity > 1: print("{} skipped cache".format(k))

  if args.verbosity>1: print("regions: {}".format(regions))
  
  for rdict in regions:
    for region, ec2Instance in rdict.items():
      if args.verbosity > 3: print(k)
      # Convert to JSON -> Python data structure -> JSON for proper formatting
      jsonContent = json.dumps(ec2Instance.instances, cls=DateTimeEncoder)
      from_json = json.loads(jsonContent) # Shrugs
      print(json.dumps(from_json, indent=4))
      if args.verbosity > 3: print(ec2Instance.__dict__)
      cache.set(region, pickle.dumps(ec2Instance), expire=3600)
  
  cache.close()

if __name__ == "__main__":
  try:
    main()
  except KeyboardInterrupt:
    print("Exiting on user interrupt")
    sys.exit(0)
