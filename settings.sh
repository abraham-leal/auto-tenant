#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

export CCLOUD_KEY="YourCloudKey"
export CCLOUD_SECRET="YourCloudSecret"

export CCLOUD_USERNAME="YourUserName@example.com"
export CCLOUD_PASSWORD="YourPassword"

export CCLOUD_BOOTSTRAP_SERVER="cluster-endpoint.confluent.cloud:9092"
export CCLOUD_ENVIRONMENT="t33874"
export CCLOUD_CLUSTER_ID="lkc-1j3qj"

# Create a settings-private.sh in the current directory to override the above which is a template. 
# This creates a 'project' defaults settings file (this one)
# and a per-user version that isnt checked in but overrides project level. 
PRIVATE_SETTINGS=$THIS_DIR/settings-private.sh
if [ -f "$PRIVATE_SETTINGS" ]; then
    source $PRIVATE_SETTINGS
fi
