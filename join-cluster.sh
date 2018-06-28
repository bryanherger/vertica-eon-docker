#!/bin/bash
export MY_IP_ADDR=`ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
echo "arg* = $*"
echo "arg1 = $1"
/usr/sbin/sshd
ssh -o StrictHostKeyChecking=no $1 /opt/vertica/sbin/update_vertica --add-hosts $MY_IP_ADDR --rpm /tmp/vertica-9.1.0-1.x86_64.RHEL6.rpm --dba-user-password-disabled --failure-threshold NONE --no-system-configuration
ssh -o StrictHostKeyChecking=no $1 gosu dbadmin /opt/vertica/bin/admintools -t db_add_node -d eondocker -p eonmode -s $MY_IP_ADDR --skip-fs-checks
sleep 365d


