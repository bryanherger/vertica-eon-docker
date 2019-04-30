#!/bin/bash
set -e

STOP_LOOP="false"

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
# create local folders
mkdir -p /eon/data
mkdir -p /eon/depot
mkdir -p /eon/catalog
chown -R dbadmin /eon
# nano /opt/vertica/config/admintools.conf
# ... edit bootstrap params ... use IP address, not hostname! ...
sed -i "s/awsendpoint =/awsendpoint = $AWS_ENDPOINT/g" /opt/vertica/config/admintools.conf
sed -i "s/awsregion =/awsregion = $AWS_REGION/g" /opt/vertica/config/admintools.conf
echo awsenablehttps = 0 >> /opt/vertica/config/admintools.conf
cat /opt/vertica/config/admintools.conf

# Vertica should be shut down properly
function shut_down() {
  echo "Shutting Down"
  vertica_proper_shutdown
  echo 'Saving configuration'
  mkdir -p ${VERTICADATA}/config
  /bin/cp /opt/vertica/config/admintools.conf ${VERTICADATA}/config/admintools.conf
  echo 'Stopping loop'
  STOP_LOOP="true"
}

function vertica_proper_shutdown() {
  echo 'Vertica: Closing active sessions'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT CLOSE_ALL_SESSIONS();'"
  echo 'Vertica: Flushing everything on disk'
  /bin/su - dbadmin -c "/opt/vertica/bin/vsql -U dbadmin -d ${DATABASE_NAME} ${VSQLPW} -c 'SELECT MAKE_AHM_NOW();'"
  echo 'Vertica: Stopping database'
  /bin/su - dbadmin -c "/opt/vertica/bin/admintools -t stop_db ${DBPW} -d ${DATABASE_NAME} -i"
}

function fix_filesystem_permissions() {
  chown -R dbadmin:verticadba "${VERTICADATA}"
  chown dbadmin:verticadba /opt/vertica/config/admintools.conf
}

trap "shut_down" SIGKILL SIGTERM SIGHUP SIGINT


echo 'Starting up'
if [ ! -f ${VERTICADATA}/config/admintools.conf ]; then
  echo 'Fixing filesystem permissions'
  fix_filesystem_permissions
  echo "Creating Eon database on communal storage ${COMMUNAL_STORAGE}"
  # su - dbadmin -c "/opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW} -c ${VERTICADATA}/catalog -D ${VERTICADATA}/data"
  echo su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
  su - dbadmin -c "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY /opt/vertica/bin/admintools -t create_db --skip-fs-checks -s localhost -d ${DATABASE_NAME} ${DBPW} --data_path /eon/data --catalog_path /eon/catalog --shard-count 3 --communal-storage-location ${COMMUNAL_STORAGE} --depot-path /eon/depot --get-aws-credentials-from-env-vars"
else
  echo 'Restoring configuration'
  cp ${VERTICADATA}/config/admintools.conf /opt/vertica/config/admintools.conf
  echo 'Fixing filesystem permissions'
  fix_filesystem_permissions
  echo 'Starting Database'
  su - dbadmin -c "/opt/vertica/bin/admintools -t start_db -d ${DATABASE_NAME} ${DBPW} -i"
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

echo "Vertica is now running"

while [ "${STOP_LOOP}" == "false" ]; do
  sleep 1
done
