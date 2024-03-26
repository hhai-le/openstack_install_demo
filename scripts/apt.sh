#!/bin/bash
apt install -y software-properties-common
add-apt-repository cloud-archive:bobcat -y
apt update  -y
apt upgrade -y 
apt install -y chrony