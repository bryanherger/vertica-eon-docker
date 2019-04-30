#!/bin/sh
#
# Minio Cloud Storage, (C) 2017 Minio, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

## Look for docker secrets in default documented location.
docker_secrets_env() {
    local ACCESS_KEY_FILE="/run/secrets/$MINIO_ACCESS_KEY_FILE"
    local SECRET_KEY_FILE="/run/secrets/$MINIO_SECRET_KEY_FILE"

    if [ -f $ACCESS_KEY_FILE -a -f $SECRET_KEY_FILE ]; then
        if [ -f $ACCESS_KEY_FILE ]; then
            export MINIO_ACCESS_KEY="$(cat "$ACCESS_KEY_FILE")"
        fi
        if [ -f $SECRET_KEY_FILE ]; then
            export MINIO_SECRET_KEY="$(cat "$SECRET_KEY_FILE")"
        fi
    fi
}

## Set access env from secrets if necessary.
docker_secrets_env

minio server /data &

# Vertica entry point
set -e

# Vertica should be shut down properly
function shut_down() {
  echo "Shutting Down"
  gosu dbadmin /opt/vertica/bin/admintools -t stop_db -d docker -i
  exit
}

trap "shut_down" SIGKILL SIGTERM SIGHUP SIGINT EXIT

# chown -R dbadmin:verticadba "$VERTICADATA"

ulimit -n 32768

# start MC
#/opt/vconsole/bin/mctl start

exec "$@"
