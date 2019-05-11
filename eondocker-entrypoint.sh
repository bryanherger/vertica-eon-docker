#!/bin/bash
set -e

STOP_LOOP="false"
REVIVE_DB="false"

# if DATABASE_NAME is not provided use default one: "eondocker"
export DATABASE_NAME="${DATABASE_NAME:-eondocker}"
# if DATABASE_PASSWORD is provided, use it as DB password, otherwise empty password
if [ -n "$DATABASE_PASSWORD" ]; then export DBPW="-p $DATABASE_PASSWORD" VSQLPW="-w $DATABASE_PASSWORD"; else export DBPW="" VSQLPW=""; fi
# check for required parameters
export COMMUNAL_STORAGE="${COMMUNAL_STORAGE:-s3://verticatest/db}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-AKIAIOSFODNN7EXAMPLE}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY}"
export AWS_ENDPOINT="${AWS_ENDPOINT:-192.168.1.206:9999}"
export AWS_REGION="${AWS_REGION:-us-west-1}"
export AWS_ENABLE_HTTPS="${AWS_ENABLE_HTTPS:-0}"
# create local folders
mkdir -p /eon/data
mkdir -p /eon/depot
mkdir -p /eon/catalog
chown -R dbadmin /eon
# nano /opt/vertica/config/admintools.conf

function setup_admintools() {
  echo "Setup admintools"
  # ... edit bootstrap params ... use IP address, not hostname! ...
  sed -i "s/awsendpoint =/awsendpoint = $AWS_ENDPOINT/g" /opt/vertica/config/admintools.conf
  sed -i "s/awsregion =/awsregion = $AWS_REGION/g" /opt/vertica/config/admintools.conf
  echo awsenablehttps = $AWS_ENABLE_HTTPS >> /opt/vertica/config/admintools.conf
  # cat /opt/vertica/config/admintools.conf
}

# Vertica should be shut down properly
function shut_down() {
  echo "Shutting Down"
  vertica_proper_shutdown
  #echo 'Saving configuration'
  #mkdir -p ${VERTICADATA}/config
  #/bin/cp /opt/vertica/config/admintools.conf ${VERTICADATA}/config/admintools.conf
  echo 'Stopping loop'
  STOP_LOOP="true"
}

function vertica_proper_shutdown() {
  echo 'Vertica: Closing active sessions'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT CLOSE_ALL_SESSIONS();'"
  echo 'Vertica: Flushing everything on disk'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT MAKE_AHM_NOW();'"
  echo 'Vertica: Sync catalog'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT sync_catalog();'"
  echo 'Vertica: Stopping database'
  /bin/su - dbadmin -c "/opt/vertica/bin/admintools -t stop_db ${DBPW} -d ${DATABASE_NAME} -i"
}

function fix_filesystem_permissions() {
  chown -R dbadmin:verticadba "${VERTICADATA}"
  chown dbadmin:verticadba /opt/vertica/config/admintools.conf
}

function create_cluster() {
  /opt/vertica/sbin/install_vertica --debug --license CE --accept-eula --hosts ${MY_IP_ADDR} --dba-user-password-disabled --failure-threshold NONE --no-system-configuration
  setup_admintools
  echo 'Fixing filesystem permissions'
  fix_filesystem_permissions
  echo "Creating Eon database on communal storage ${COMMUNAL_STORAGE}"
  # su - dbadmin -c "/opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW} -c ${VERTICADATA}/catalog -D ${VERTICADATA}/data"
  echo su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s ${MY_IP_ADDR} -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
  su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s ${MY_IP_ADDR} -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
}

function join_cluster() {
  echo 'Vertica: Adding host to cluster'
  ssh -o StrictHostKeyChecking=no vertica-0.`hostname -d` /opt/vertica/sbin/update_vertica --debug --add-hosts $MY_IP_ADDR --dba-user-password-disabled --failure-threshold NONE --no-system-configuration
  echo 'Vertica: Adding node to database'
  ssh -o StrictHostKeyChecking=no vertica-0.`hostname -d` gosu dbadmin /opt/vertica/bin/admintools -t db_add_node -d ${DATABASE_NAME} ${DBPW} -s $MY_IP_ADDR --skip-fs-checks
  echo 'Vertica: Rebalancing shards'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT rebalance_shards();'"
  # echo "(not supported - todo! hy hostname is ${ADD_HOST} at ${MY_IP_ADDR}, sleeping until stopped or scaled down)"
}

function do_kubernetes() {
  echo 'Begin Kubernetes pod config!'
  echo 'Starting SSH'
  ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
  ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
  /usr/sbin/sshd &
  # test for first node to create DB (todo: check for existing and restore!)
  if [[ `hostname` == *-0 ]]; then 
    echo 'First node in cluster'
    create_cluster
  else
    # if adding a node
    echo 'Adding a node to cluster'
    ADD_HOST=`hostname`
    join_cluster
  fi
  while [ "${STOP_LOOP}" == "false" ]; do
    sleep 1
  done
}

function setup_ssh() {
  echo 'Installing SSH keys'
  mkdir -p /root/.ssh/
  chmod -R 700 /root/.ssh/
  cp /mnt/verticakeys/* /root/.ssh/
  chmod 600 /root/.ssh/*
  mv /root/.ssh/vsshkey /root/.ssh/id_rsa
  mv /root/.ssh/vsshkey.pub /root/.ssh/id_rsa.pub
}

trap "shut_down" SIGKILL SIGTERM SIGHUP SIGINT

echo 'Starting up'
echo 'Setting up SSH keys'
if [ -f /mnt/verticakeys/vsshkey ]; then
  setup_ssh
else
  echo 'SSH keys not found, we can only start one node this way'
fi
export MY_IP_ADDR=`ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
echo "My IPv4 is $MY_IP_ADDR"
echo 'Checking for Kubernetes environment'
if [ -n "$IS_KUBERNETES" ]; then
  do_kubernetes
fi
echo "Checking for existing DB at ${COMMUNAL_STORAGE}"
echo s3cmd --host=$AWS_ENDPOINT --host-bucket=$AWS_ENDPOINT --access_key=$AWS_ACCESS_KEY_ID --secret_key=$AWS_SECRET_ACCESS_KEY --no-ssl ls $COMMUNAL_STORAGE
EXISTING_DB=`s3cmd --host=$AWS_ENDPOINT --host-bucket=$AWS_ENDPOINT --access_key=$AWS_ACCESS_KEY_ID --secret_key=$AWS_SECRET_ACCESS_KEY --no-ssl ls $COMMUNAL_STORAGE`
echo "s3cmd result: $EXISTING_DB"
if [[ $EXISTING_DB == *s3* ]]; then
  echo 'Fixing filesystem permissions'
  fix_filesystem_permissions
  echo 'Database exists!  Reviving.'
  echo su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t revive_db --communal-storage-location=${COMMUNAL_STORAGE} -s ${MY_IP_ADDR} --force -d ${DATABASE_NAME} ${DBPW} --get-aws-credentials-from-env-vars"
  su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t revive_db --communal-storage-location=${COMMUNAL_STORAGE} -s ${MY_IP_ADDR} --force -d ${DATABASE_NAME} ${DBPW} --get-aws-credentials-from-env-vars"
else
  echo 'Fixing filesystem permissions'
  fix_filesystem_permissions
  echo "Creating Eon database on communal storage ${COMMUNAL_STORAGE}"
  # su - dbadmin -c "/opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW} -c ${VERTICADATA}/catalog -D ${VERTICADATA}/data"
  echo su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s ${MY_IP_ADDR} -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
  su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s ${MY_IP_ADDR} -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
fi

echo
if [ -d /docker-entrypoint-initdb.d/ ]; then
  echo "Running entrypoint scripts ..."
  for f in $(ls /docker-entrypoint-initdb.d/* | sort); do
    case "$f" in
      *.sh)     echo "$0: running $f"; . "$f" ;;
      *.sql)    echo "$0: running $f"; su - dbadmin -c "/opt/vertica/bin/vsql -d ${DATABASE_NAME} ${DBPW} -f $f"; echo ;;
      *)        echo "$0: ignoring $f" ;;
    esac
   echo
  done
fi

echo "Vertica is now running on `hostname` with database ${DATABASE_NAME} located at ${COMMUNAL_STORAGE}"

while [ "${STOP_LOOP}" == "false" ]; do
  sleep 1
done
