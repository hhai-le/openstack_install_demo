#!/bin/bash

source config.sh

openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --project demo --password demopass demo
openstack role list
openstack role add --project demo --user demo member

openstack flavor create --public --id $(uuidgen) --ram 512   --vcpus 1 --disk 10  m1.tiny
openstack flavor create --public --id $(uuidgen) --ram 1024  --vcpus 1 --disk 20  m1.small
openstack flavor create --public --id $(uuidgen) --ram 2048  --vcpus 2 --disk 40  m1.medium
openstack flavor create --public --id $(uuidgen) --ram 4096  --vcpus 2 --disk 80  m1.large
openstack flavor create --public --id $(uuidgen) --ram 8192  --vcpus 4 --disk 160 m1.xlarge
openstack flavor create --public --id $(uuidgen) --ram 16384 --vcpus 6 --disk 320 m1.xxlarge
