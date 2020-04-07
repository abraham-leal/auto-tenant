alias delete="./delete_tenant.sh serrala nuxio dev topics.txt"
alias create=" ./create_tenant.sh serrala nuxio dev topics.txt"
source settings.sh
ccloud environment use $CCLOUD_ENVIRONMENT
ccloud kafka cluster describe $CCLOUD_CLUSTER_ID
ccloud kafka cluster use $CCLOUD_CLUSTER_ID

