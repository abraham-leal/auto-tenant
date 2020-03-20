#!/bin/bash
set -e

# This is an example of creating a "kafka context" with the Confluent Cloud CLI 
# available here - https://docs.confluent.io/current/cloud/cli/install.html
# This script will create topics that are fully accessible via the created service-user
# but protected from access by any other user excluding superusers.
#

DEBUG=1
debug () {
    if [ ! -z "$DEBUG" ] ; then
        echo "debug: $@"
    fi
}

if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters."
echo "Usage: 
    create_tenant.sh <tenant> <app-name> <environment> <topics-list-file-relative>
    
Example: 
    create_tenant.sh serrala nuxio dev topics.txt
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

TENANT=$1
APP_NAME=$2
APP_ENVIRONMENT=$3
TOPICS_LIST_FILE=$THIS_DIR/$4

debug $TENANT $APP_NAME $APP_ENVIRONMENT $TOPICS_LIST_FILE

if [ ! -e $TOPICS_LIST_FILE ] ; then
    echo "Couldn't find $TOPICS_LIST_FILE. Exiting."
    exit 1
fi

source ./settings.sh

echo "from settings*.sh -  
    CCLOUD_ENVIRONMENT: $CCLOUD_ENVIRONMENT
    CCLOUD_CLUSTER_ID: $CCLOUD_CLUSTER_ID"

ccloud environment use $CCLOUD_ENVIRONMENT
ccloud kafka cluster describe $CCLOUD_CLUSTER_ID
ccloud kafka cluster use $CCLOUD_CLUSTER_ID

##############################
## SERVICE ACCOUNTS
SERVICE_ACCOUNT="sa-$TENANT-$APP_NAME-$APP_ENVIRONMENT"
debug "Service Account: $SERVICE_ACCOUNT"
if [ ! -z "$DEBUG" ] ; then
    SERVICE_ACCOUNT_ID=$(ccloud service-account list | grep sa-serrala-nuxio-dev | awk '{print $1}')
    echo "debug mode: Deleting service-account if it exists: $SERVICE_ACCOUNT with ID of $SERVICE_ACCOUNT_ID"
    ccloud service-account delete $SERVICE_ACCOUNT_ID > /dev/null 2>&1 || true
fi
echo "Creating service-account: $SERVICE_ACCOUNT"
ccloud service-account create $SERVICE_ACCOUNT --description "Automated service account for $APP_NAME @ $APP_ENVIRONMENT" 
SERVICE_ACCOUNT_ID=$(ccloud service-account list | grep sa-serrala-nuxio-dev | awk '{print $1}')
debug "Service Account ID: $SERVICE_ACCOUNT_ID"

###############################
## API KEY
API_KEY=$(ccloud api-key list --service-account $SERVICE_ACCOUNT_ID | head -n 4 | tail -1 | awk '{print $1}')
debug $API_KEY
if [ ! -z "$DEBUG" ] ; then
    echo "debug mode: Deleting api-key if it exists..."
    # assuming single API key for this example script.... may blow up with multiple.
    ccloud api-key delete $API_KEY > /dev/null 2>&1 || true
fi
echo "Creating API key..."
ccloud api-key create --service-account "$SERVICE_ACCOUNT_ID" --description "Automated API KEY for $APP_NAME @ $APP_ENVIRONMENT" --resource $CCLOUD_CLUSTER_ID

# pull the topics file into an array named TENANT_TOPICS_LIST
IFS=$'\r\n' GLOBIGNORE='*' command eval  'TENANT_TOPICS_LIST=($(cat $TOPICS_LIST_FILE))'
for topic in "${TENANT_TOPICS_LIST[@]}"
do
    debug $topic
done

for topic in "${TENANT_TOPICS_LIST[@]}"
do
# https://docs.confluent.io/current/cloud/cli/command-reference/ccloud_kafka_topic_create.html
#     --cluster string      Kafka cluster ID.
#     --partitions uint32   Number of topic partitions. (default 6)
#     --config strings      A comma-separated list of topics. Configuration ('key=value') overrides for the topic being created.
#     --dry-run             Run the command without committing changes to Kafka.
# -h, --help                help for create
    echo "Creating topic: $topic.."
    ccloud kafka topic create $topic --cluster $CCLOUD_CLUSTER_ID

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
    echo "Assigning full control ACLs for $SERVICE_ACCOUNT on $topic"
    ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation READ --topic $topic
    ccloud kafka acl create --allow --service-account $SERVICE_ACCOUNT_ID --operation WRITE --topic $topic
done



# echo "Step 1 (again)"
# echo "-----------------"
# #kafka-console-producer

# echo "Step 2-7 Writing to Topics with producer by using a file as input via < my_data.txt"
# echo "-----------------"
# kafka-console-producer --broker-list $CCLOUD_BOOTSTRAP_SERVER --topic testing < my_data.txt

# echo "Press Enter to Continue"
# read just_enter

# echo "Step 8-9 Consuming from Topics with consumer"
# kafka-console-consumer \
#  --bootstrap-server $CCLOUD_BOOTSTRAP_SERVER \
#  --from-beginning \
#  --topic testing &

# echo "Press Enter to Continue"
# read just_enter

# echo "Killing consumer..."
# kill $!

# echo "OPTIONAL: Working with record keys - use automatic keys to create messages"
# kafka-console-producer \
#  --broker-list $CCLOUD_BOOTSTRAP_SERVER \
#  --topic testing \
#  --property parse.key=true \
#  --property key.separator=, < my_data_keyed.txt

# echo "Press Enter to Continue"
# read just_enter

# echo "Retrieving keyed records with consumer:"
# kafka-console-consumer \
#  --bootstrap-server $CCLOUD_BOOTSTRAP_SERVER \
#  --from-beginning \
#  --topic testing \
#  --property print.key=true &

# echo "Press Enter to Continue"
# read just_enter
# echo "Killing consumer..."
# kill $!

#  echo "Done with lab 2"