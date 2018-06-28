#!/bin/bash
export AWS_ACCESS_KEY_ID="$1"
export AWS_SECRET_ACCESS_KEY="$2"
export MY_IP_ADDR=`ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
echo "My IPv4 is $MY_IP_ADDR"
/opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts $MY_IP_ADDR --dba-user-password-disabled --failure-threshold NONE --no-system-configuration
gosu dbadmin bash /tmp/create-start-db.sh $*
/usr/sbin/sshd -D


