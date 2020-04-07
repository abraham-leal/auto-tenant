#!/bin/bash

set -e

./create_tenant.sh serrala nuxio uat topics.txt && ./create_tenant.sh serrala nuxio prod topics.txt

