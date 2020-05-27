#!/bin/bash
# author: jkuhnash@confluent.io @ github.com/jeremykuhnash
set -e

# This is an example of creating a "kafka tenant context" with the Confluent Cloud CLI 
# available here - https://docs.confluent.io/current/cloud/cli/install.html
# This script will create topics that are fully accessible via the created service-user
# but protected from access by any other user excluding superusers.
#

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THIS_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source $THIS_DIR/common.sh

echo
echo
echo

##############################
## SERVICE ACCOUNT CREATION
##############################
SERVICE_ACCOUNT=$(generate_service-user_name)
echo "Creating service-account: $SERVICE_ACCOUNT"
SERVICE_ACCOUNT_CREATE_COMMAND="ccloud service-account create $SERVICE_ACCOUNT --description 'Automated service account for $APP_NAME $APP_ENVIRONMENT'"
#debug "SERVICE_ACCOUNT_CREATE_COMMAND: $SERVICE_ACCOUNT_CREATE_COMMAND"
eval "$SERVICE_ACCOUNT_CREATE_COMMAND"
SERVICE_ACCOUNT_ID=$(ccloud service-account list | grep $SERVICE_ACCOUNT | awk '{print $1}' | awk '{$1=$1;print}')
#debug "SERVICE_ACCOUNT_ID: $SERVICE_ACCOUNT_ID"

echo
echo
echo

###############################
## API KEY CREATION
###############################

##### Commenting this section out. Key rotation rarely requires immediate deletion of previous keys.
##### This check was unused

# API_KEY=$(ccloud api-key list --service-account $SERVICE_ACCOUNT_ID | tail -n +3 | awk '{print $1}' | awk '{$1=$1;print}')
# debug $API_KEY
# if [ ! -z "$DEBUG" ] ; then
#     debug "API_KEY, line: $API_KEY"
#     if [ ! -z "$API_KEY"  ]; then
#         API_KEY_DELETE_COMMAND="ccloud api-key delete $API_KEY"
#         debug $API_KEY_DELETE_COMMAND 
#         eval "$API_KEY_DELETE_COMMAND" || true
#     fi
# fi

echo "Creating API key..."
API_KEY_CREATE_COMMAND="ccloud api-key create --service-account \"$SERVICE_ACCOUNT_ID\" --description \"Automated API KEY for $APP_NAME @ $APP_ENVIRONMENT\" --resource $CCLOUD_CLUSTER_ID"
#debug "API_KEY_CREATE_COMMAND: $API_KEY_CREATE_COMMAND"
KEY_INFO=$(eval "$API_KEY_CREATE_COMMAND")
#debug "KEY_INFO: $KEY_INFO"
API_KEY=$(echo $KEY_INFO | cut -f 3 -d "|" | awk '{$1=$1;print}')
debug "API_KEY: $API_KEY"
API_SECRET=$(echo $KEY_INFO | cut -f 6 -d "|" | awk '{$1=$1;print}')
debug "API_SECRET: $API_SECRET"
cat << EOF > $API_KEY_LOCATION
API_KEY="${API_KEY}"
API_SECRET="${API_SECRET}"
EOF

echo
echo
echo


#############
## Reading topics from file
#############
declare -A TopicPartitions

while IFS== read -r key value; do
    TopicPartitions[$key]=$value
done <<< "$(cat $TOPICS_LIST_FILE)"

echo "Topics found in topics.txt - If no partitions are declared, the default of 6 is applied"
echo
for key in "${!TopicPartitions[@]}"
do
    if [ -z ${TopicPartitions[$key]} ]
    then
       TopicPartitions[$key]="6"
    fi 
    echo "Topic  : $key, Partitions : ${TopicPartitions[$key]}"
done

echo

for key in "${!TopicPartitions[@]}"
do
    ############
    ## Creating Topic
    ############
    TOPIC_NAME=$(generate_topic_name $key)
    debug "TOPIC_NAME: $TOPIC_NAME"
    TOPIC_CREATE_COMMAND="ccloud kafka topic create $TOPIC_NAME  --partitions ${TopicPartitions[$key]}"
    debug "$TOPIC_CREATE_COMMAND"
    eval "$TOPIC_CREATE_COMMAND"
    echo "Letting cluster settle down for $DELAY_TIME seconds..."
    sleep $DELAY_TIME
    echo

    ##########
    ## Assigning ACLs for Topic
    ##########
    CREATE_ACL_READ_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --topic $TOPIC_NAME"
    debug $CREATE_ACL_READ_COMMAND
    eval $CREATE_ACL_READ_COMMAND
    CREATE_ACL_WRITE_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --topic $TOPIC_NAME"
    debug $CREATE_ACL_WRITE_COMMAND
    eval $CREATE_ACL_WRITE_COMMAND
    echo
done

echo
echo
echo

##################
## Assigning Global Read on Consumer Groups with the given topic prefix in settings.sh
##################

CG_PREFIX="$TOPICS_PREFIX$TENANT.$APP_NAME.$APP_ENVIRONMENT."
echo "Creating global read permission on consumer group prefixed with: $CG_PREFIX"
CREATE_ACL_READ_CG_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --prefix --consumer-group $CG_PREFIX"
debug $CREATE_ACL_READ_CG_COMMAND
eval $CREATE_ACL_READ_CG_COMMAND

echo
echo
echo

echo "Final view:"
echo
echo "Service Account Information"
echo "
   Id   |         Name          |          Description            
+-------+-----------------------+--------------------------------+
"
ccloud service-account list | grep "$SERVICE_ACCOUNT_ID"
echo
echo "Topics created for this pre-fix"
echo
ccloud kafka topic list | grep "$CG_PREFIX"
echo
echo "ACLs created for the service account"
echo
ccloud kafka acl list --service-account $SERVICE_ACCOUNT_ID

