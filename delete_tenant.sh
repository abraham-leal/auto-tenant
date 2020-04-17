#!/bin/bash
# author: jkuhnash@confluent.io @ github.com/jeremykuhnash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $THIS_DIR/common.sh

# Clean ACLs
# ACLS=$(ccloud kafka acl list)
# debug "ACLS: $ACLS"
ACL_LIST=$(ccloud kafka acl list | tail -n +3)
debug "ACL_LIST: $ACL_LIST"
if [ ! -z "$ACL_LIST" ]; then
    while IFS= read -r line; do
        TOPIC_NAME=$(echo $line\ | cut -d "|" -f 5 | awk '{$1=$1;print}')
        echo "Deleting ACL w/ Topic name: $TOPIC_NAME -- "
        IS_TOPIC_ACL=$(echo $line | cut -d "|" -f 4 | awk '{$1=$1;print}')
        if [ "$IS_TOPIC_ACL" = "TOPIC" ]; then
            ACL_SERVICE_ACCOUNT_ID=$(echo $line | cut -d " " -f 1 | cut -d ":" -f 2)
            debug "     SERVICE_ACCOUNT_ID_FOR_ACL: $ACL_SERVICE_ACCOUNT_ID"
            ACL_OPERATION=$(echo $line | cut -d "|" -f 3 | awk '{$1=$1;print}' | tr '[:upper:]' '[:lower:]')
            debug "     ACL_OPERATION: $ACL_OPERATION"
            ACL_TYPE=$(echo $line | cut -d "|" -f 2 | awk '{$1=$1;print}')
            debug "     ACL_TYPE: $ACL_TYPE"
            if [ "$ACL_TYPE" = "ALLOW" ]; then
                ACL_TYPE="--allow"
            else 
                ACL_TYPE="--deny"
            fi
            #ccloud kafka acl create --allow --service-account $ACL_SERVICE_ACCOUNT_ID --operation READ --topic $topic
            DELETE_COMMAND="ccloud kafka acl delete $ACL_TYPE --operation $ACL_OPERATION --service-account $ACL_SERVICE_ACCOUNT_ID --topic $TOPIC_NAME"
            debug "$DELETE_COMMAND"
            eval "$DELETE_COMMAND"
        else 
            debug "Only deleting ACLs of TOPIC type. Skipping $TOPIC_NAME"
        fi
    done <<< "$ACL_LIST"
else 
    debug "Didn't find any ACLs to delete."
fi

# Clean service-users
CANDIDATE_USERS_IN=$(ccloud service-account list | tail -n +3 )
while IFS= read -r user; do
    debug "user: $user"
    SERVICE_USER_ID=$(echo $user | cut -d "|" -f 1 | awk '{$1=$1;print}')
    SERVICE_USERNAME=$(echo $user | cut -d "|" -f 2 | awk '{$1=$1;print}')
    debug "SERVICE_USER_ID: $SERVICE_USER_ID"
    debug "SERVICE_USERNAME: $SERVICE_USERNAME"
    if [[ $SERVICE_USERNAME == $SERVICE_ACCOUNT_PREFIX* ]]; then 
        USER_DELETE_COMMAND="ccloud service-account delete $SERVICE_USER_ID"
        debug $USER_DELETE_COMMAND
        eval "$USER_DELETE_COMMAND"
    fi
done <<< "$CANDIDATE_USERS_IN"

# Clean topics
IFS=$'\r\n' GLOBIGNORE='*' command eval 'TENANT_TOPICS_LIST=($(cat $TOPICS_LIST_FILE))'
debug "Topics found in $TOPICS_LIST_FILE - "
for topic in "${TENANT_TOPICS_LIST[@]}"
do
    debug "   Found: $topic"
done

for topic in "${TENANT_TOPICS_LIST[@]}"
do
    TOPIC_TO_DELETE=$(generate_topic_name $topic)
    echo "Deleting Topic $TOPIC_TO_DELETE..."
    ccloud kafka topic delete $TOPIC_TO_DELETE || true
    echo "Letting the cluster catch up...."
    # sleep $DELAY_TIME
done

# Clean related API-KEY/SECRET pairs
echo "Deleting API Pairs associated with tenant"
CANDIDATE_KEYS_IN=$(ccloud api-key list --service-account $ACL_SERVICE_ACCOUNT_ID | tail -n +3 )
while IFS= read -r apikey; do
    debug "api-key: $apikey"
    KEY_PAIR=$(echo $apikey | cut -d "|" -f 1 | awk '{$1=$1;print}')
    RESOURCE=$(echo $apikey | cut -d "|" -f 5 | awk '{$1=$1;print}')
    debug "KEY_PAIR: $KEY_PAIR"
    debug "RESOURCE: $RESOURCE"
    if [[ $RESOURCE == $CCLOUD_CLUSTER_ID ]]; then 
        KEY_DELETE_COMMAND="ccloud api-key delete $KEY_PAIR"
        debug $KEY_DELETE_COMMAND
        eval "$KEY_DELETE_COMMAND"
    fi
done <<< "$CANDIDATE_KEYS_IN"


echo "Check: "
echo $(ccloud service-account list | tail -n +3 | grep $SERVICE_ACCOUNT_PREFIX)
