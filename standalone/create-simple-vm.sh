#!/bin/bash

export OS_CLOUD=standalone

# Download and create cirros image
curl -k -L http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img > cirros.img
openstack image create cirros --file cirros.img --disk-format qcow2 --container-format bare --public

# Create flavor
openstack flavor create --disk 1 --ram 128 m1.tiny

# Network creation
## Create private network
openstack network create net1
openstack subnet create --subnet-range 192.168.100.0/24 --network net1 subnet1

## Create public network
openstack network create nova --external
openstack subnet create --subnet-range 10.0.0.0/24 --network nova subnova

## Setup router
openstack router create router1
openstack router add subnet router1 subnet1
openstack router set --external-gateway nova router1

# Create security groups
openstack security group create secgroup1
openstack security group rule create --protocol tcp --dst-port 22 secgroup1
openstack security group rule create --protocol icmp secgroup1

# Create server and FIP
openstack server create --nic net-id=net1 --flavor m1.tiny --image cirros --security-group secgroup1 server0
openstack floating ip create --port $(openstack port list --server server0 -c id -f value) nova

