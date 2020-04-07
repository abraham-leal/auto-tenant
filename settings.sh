#!/bin/bash
# author: jkuhnash@confluent.io @ github.com/jeremykuhnash
set -e

export SERVICE_ACCOUNT_PREFIX="mck-"
export TOPICS_PREFIX="mck-"

export CCLOUD_BOOTSTRAP_SERVER="cluster-endpoint.confluent.cloud:9092"
export CCLOUD_ENVIRONMENT="t34375"
export CCLOUD_CLUSTER_ID="lkc-1j3qj"

# delay time in seconds to sleep between commands on the Kafka cluster. 
# Note: Admin commands @ cloud API do not need to sleep. 
export DELAY_TIME=10

# Not used, yet, but should go into the settings-private.sh
export CCLOUD_USERNAME="YourUserName@example.com"
export CCLOUD_PASSWORD="YourPassword"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Create a settings-private.sh in the current directory to override the above which is a template. 
# This creates a 'project' defaults settings file (this one)
# and a per-user version that isnt checked in but overrides project level. 
PRIVATE_SETTINGS=$THIS_DIR/settings-private.sh   
if [ -f "$PRIVATE_SETTINGS" ]; then
    source $PRIVATE_SETTINGS
fi
