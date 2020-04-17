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

##############################
## SERVICE ACCOUNTS
# Similar topic naming conventions discussed here - https://riccomini.name/how-paint-bike-shed-kafka-topic-naming-conventions
SERVICE_ACCOUNT=$(generate_service-user_name)
echo "Creating service-account: $SERVICE_ACCOUNT"
SERVICE_ACCOUNT_CREATE_COMMAND="ccloud service-account create $SERVICE_ACCOUNT --description 'Automated service account for $APP_NAME $APP_ENVIRONMENT'"
debug "SERVICE_ACCOUNT_CREATE_COMMAND: $SERVICE_ACCOUNT_CREATE_COMMAND"
eval "$SERVICE_ACCOUNT_CREATE_COMMAND"
SERVICE_ACCOUNT_ID=$(ccloud service-account list | grep $SERVICE_ACCOUNT | awk '{print $1}' | awk '{$1=$1;print}')
debug "SERVICE_ACCOUNT_ID: $SERVICE_ACCOUNT_ID"

###############################
## API KEY
API_KEY=$(ccloud api-key list --service-account $SERVICE_ACCOUNT_ID | tail -n +3 | awk '{print $1}' | awk '{$1=$1;print}')
debug $API_KEY
if [ ! -z "$DEBUG" ] ; then
    debug "API_KEY, line: $API_KEY"
    if [ ! -z "$API_KEY"  ]; then
        API_KEY_DELETE_COMMAND="ccloud api-key delete $API_KEY"
        debug $API_KEY_DELETE_COMMAND 
        eval "$API_KEY_DELETE_COMMAND" || true
    fi
fi
echo "Creating API key..."
API_KEY_CREATE_COMMAND="ccloud api-key create --service-account \"$SERVICE_ACCOUNT_ID\" --description \"Automated API KEY for $APP_NAME @ $APP_ENVIRONMENT\" --resource $CCLOUD_CLUSTER_ID"
debug "API_KEY_CREATE_COMMAND: $API_KEY_CREATE_COMMAND"
KEY_INFO=$(eval "$API_KEY_CREATE_COMMAND")
debug "KEY_INFO: $KEY_INFO"
API_KEY=$(echo $KEY_INFO | cut -f 3 -d "|" | awk '{$1=$1;print}')
debug "API_KEY: $API_KEY"
API_SECRET=$(echo $KEY_INFO | cut -f 6 -d "|" | awk '{$1=$1;print}')
debug "API_SECRET: $API_SECRET"
cat << EOF > $API_KEY_LOCATION
API_KEY="${API_KEY}"
API_SECRET="${API_SECRET}"
EOF

###############################
## Topics
# pull the topics file into an array named TENANT_TOPICS_LIST
IFS=$'\r\n' GLOBIGNORE='*' command eval 'TENANT_TOPICS_LIST=($(cat $TOPICS_LIST_FILE))'
debug "Topics found in $TOPICS_LIST_FILE - "
for topic in "${TENANT_TOPICS_LIST[@]}"
do
    debug "   Found: $topic"
done

for topic in "${TENANT_TOPICS_LIST[@]}"
do
    TOPIC_NAME=$(generate_topic_name $topic)
    debug "TOPIC_NAME: $TOPIC_NAME"
    sleep $DELAY_TIME
    # if [ ! -z "$DEBUG" ] ; then
    #     debug "Deleting $TOPIC_NAME if it exists..."
    #     TOPIC_DELETE_COMMAND="ccloud kafka topic delete $TOPIC_NAME > /dev/null 2>&1 || true"
    #     debug $TOPIC_DELETE_COMMAND
    #     eval "$TOPIC_DELETE_COMMAND"
    # fi
# https://docs.confluent.io/current/cloud/cli/command-reference/ccloud_kafka_topic_create.html
#     --cluster string      Kafka cluster ID.
#     --partitions uint32   Number of topic partitions. (default 6)
#     --config strings      A comma-separated list of topics. Configuration ('key=value') overrides for the topic being created.
#     --dry-run             Run the command without committing changes to Kafka.
# -h, --help                help for create
    echo "Letting cluster settle down for $DELAY_TIME seconds..."
    sleep $DELAY_TIME
    TOPIC_CREATE_COMMAND="ccloud kafka topic create $TOPIC_NAME"
    debug "$TOPIC_CREATE_COMMAND"
    eval "$TOPIC_CREATE_COMMAND"
    echo "Letting cluster settle down for $DELAY_TIME seconds..."

#https://docs.confluent.io/current/cloud/cli/command-reference/ccloud_kafka_acl_create.html
#     --allow                     Set the ACL to grant access.
#     --deny                      Set the ACL to restrict access to resource.
#     --service-account int       The service account ID.
#     --operation string          Set ACL Operation to: (alter, alter-configs, cluster-action, create, delete, describe, describe-configs, idempotent-write, read, write).
#     --cluster-scope             Set the cluster resource. With this option the ACL grants
#                                 access to the provided operations on the Kafka cluster itself.
#     --consumer-group string     Set the Consumer Group resource.
#     --prefix                    Set to match all resource names prefixed with this value.
#     --topic string              Set the topic resource. With this option the ACL grants the provided
#                                 operations on the topics that start with that prefix, depending on whether
#                                 the --prefix option was also passed.
#     --transactional-id string   Set the TransactionalID resource.
# -h, --help                      help for create    
    # echo "Assigning full control ACLs for $SERVICE_ACCOUNT on $topic"
    CREATE_ACL_READ_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --topic $TOPIC_NAME"
    debug $ACL_READ_COMMAND
    eval $CREATE_ACL_READ_COMMAND
    CREATE_ACL_READ_CG_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --consumer-group $TOPIC_NAME"
    debug $CREATE_ACL_READ_CG_COMMAND
    eval $CREATE_ACL_READ_CG_COMMAND
    CREATE_ACL_WRITE_COMMAND="ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --topic $TOPIC_NAME"
    debug $CREATE_ACL_WRITE_COMMAND
    eval $CREATE_ACL_WRITE_COMMAND
done

echo "Final view:"
ccloud service-account list 
ccloud kafka topic list
ccloud kafka acl list

