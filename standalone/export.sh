#!/bin/bash

CONTROLLER_IP=192.168.24.2
SRC=/home/stack/ext/tripleo-ansible/scripts/tripleo-standalone-vars
INV=/home/stack/ext/tripleo-ansible/tripleo_ansible/inventory
OPT='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

scp $OPT $SRC stack@$CONTROLLER_IP:/home/stack/tripleo-standalone-vars

ssh $OPT $CONTROLLER_IP -l stack "python3 \
  tripleo-standalone-vars --force \
  -c \$(ls /home/stack/ | grep standalone-ansible) \
  -r Standalone"

scp $OPT stack@$CONTROLLER_IP:/home/stack/99-standalone-vars 99-standalone-vars

if [[ ! -e 99-standalone-vars ]]; then
    echo "Unable to get a copy of 99-standalone-vars from $CONTROLLER_IP"
    exit 1
fi

if [ $# -eq 1 ]; then
  # $! will have an IP that will be used on missing_vars
  # as "my_ip" to be able to use more than 1 compute
  python3 missing_vars.py $1
else
  python3 missing_vars.py
fi
diff -u 99-standalone-vars 99-standalone-vars-new
cp -fv 99-standalone-vars-new $INV/99-custom
#python3 add_ceph_vars_to_nova_conf.py
#diff -u 99-standalone-vars-new 99-standalone-vars-new-ceph
#cp -fv 99-standalone-vars-new-ceph $INV/99-custom

#python3 ceph_vars.py
#cp -fv 08-ceph $INV/
