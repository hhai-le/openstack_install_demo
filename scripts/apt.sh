#!/bin/bash
sed -i 's/vn.archive/us.archive/g' /etc/apt/sources.list
apt update -y 
apt install -y software-properties-common
add-apt-repository cloud-archive:antelope -y
apt update  -y
apt upgrade -y 
apt install -y chrony