#!/bin/bash
# author: jkuhnash@confluent.io @ github.com/jeremykuhnash
set -e

DEBUG=1
debug () {
    if [ ! -z "$DEBUG" ] ; then
        # print to sderr, allows debugging functions without returned values getting polluted.
        >&2 echo $@;
    fi
}

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters."
echo "Usage: 
    $0 <tenant> <app-name> <environment> <topics-list-file-relative>
    
Example: 
    $0 gf nuxeo dev topics.txt
"
    exit 1
fi

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $THIS_DIR/settings.sh

TENANT=$1
APP_NAME=$2
APP_ENVIRONMENT=$3
TOPICS_LIST_FILE=$THIS_DIR/$4
debug "Parameters: $TENANT $APP_NAME $APP_ENVIRONMENT $TOPICS_LIST_FILE"
debug ""
debug "from arguments -"
debug "    TENANT: $TENANT"
debug "    APP_NAME: $APP_NAME"
debug "    APP_ENVIRONMENT: $APP_ENVIRONMENT"
debug "    TOPICS_LIST_FILE: $TOPICS_LIST_FILE"
debug ""
debug "from settings*.sh -"
debug "    SERVICE_ACCOUNT_PREFIX: $SERVICE_ACCOUNT_PREFIX"
debug "    TOPICS_PREFIX: $TOPICS_PREFIX"
debug "    CCLOUD_BOOTSTRAP_SERVER: $CCLOUD_BOOTSTRAP_SERVER"
debug "    CCLOUD_ENVIRONMENT: $CCLOUD_ENVIRONMENT"
debug "    CCLOUD_CLUSTER_ID: $CCLOUD_CLUSTER_ID"


if [ ! -e $TOPICS_LIST_FILE ]; then
    echo "Couldn't find $TOPICS_LIST_FILE. Exiting."
    exit 1
fi

ccloud environment use $CCLOUD_ENVIRONMENT
ccloud kafka cluster describe $CCLOUD_CLUSTER_ID
ccloud kafka cluster use $CCLOUD_CLUSTER_ID

generate_topic_name () {
    topic=$1
    RETVAL="$TOPICS_PREFIX$TENANT.$APP_NAME.$APP_ENVIRONMENT.$topic"
    debug "generate_topic_name: $RETVAL"
    echo $RETVAL
}

generate_service-user_name () {
    RETVAL="$SERVICE_ACCOUNT_PREFIX$TENANT.$APP_NAME.$APP_ENVIRONMENT"
    #debug "generate_service-user_name: $RETVAL"
    echo $RETVAL
}

FULLSERVNAME="$(generate_service-user_name)"

API_KEY_LOCATION="$THIS_DIR/api_keys_$(generate_service-user_name).sh"
debug "API_KEY_LOCATION: $API_KEY_LOCATION"