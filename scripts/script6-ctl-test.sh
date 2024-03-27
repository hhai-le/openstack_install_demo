#!/bin/bash

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demopass
export OS_AUTH_URL=http://openstack0:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack flavor list
openstack image list
openstack network list
openstack security group create secgroup01
openstack security group list
#ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
openstack keypair list
netID=$(openstack network list | grep sharednet1 | awk '{ print $2 }')
openstack server create --flavor m1.small --image Ubuntu2204 --security-group secgroup01 --nic net-id=$netID --key-name mykey Ubuntu-2204
openstack server list
openstack server list
