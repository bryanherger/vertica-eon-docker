#!/bin/bash
export AWS_ACCESS_KEY_ID="$1"
export AWS_SECRET_ACCESS_KEY="$2"
export MY_IP_ADDR=`ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
echo "$1 | $2 | My IPv4 is $MY_IP_ADDR"
# run as dbadmin
/opt/vertica/bin/admintools -t create_db --hosts $MY_IP_ADDR --database eondocker --data_path /tmp --catalog_path /tmp --shard-count 3 --communal-storage-location s3://eondocker/ --depot-path /tmp -p eonmode --get-aws-credentials-from-env-vars --skip-fs-checks
# run as dbadmin to revive
# /opt/vertica/bin/admintools -t revive_db --hosts 172.17.0.2 --database eondocker --communal-storage-location s3://eondocker/ --get-aws-credentials-from-env-vars
# then start
# though the create step above should start it
/opt/vertica/bin/admintools -t start_db -d eondocker -p eonmode --ignore-cluster-lease

