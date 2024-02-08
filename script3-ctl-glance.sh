#!/bin/bash
source config.sh

glance_create_db () {
	cat << EOF | mysql
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
EOF
}

glance_create_domain_project_user_role () {
	openstack user create --domain default --project service --password servicepassword $GLANCE_PASS
	openstack role add --project service --user glance admin
	openstack service create --name glance --description "OpenStack Image service" image
	openstack endpoint create --region RegionOne image public http://$HOST_CTL:9292
	openstack endpoint create --region RegionOne image internal http://$HOST_CTL:9292
	openstack endpoint create --region RegionOne image admin http://$HOST_CTL:9292
}

glance_config () {
	glancefile=/etc/glance/glance-api.conf
	glancefilebak=/etc/glance/glance-api.conf.bak
	cp $glancefile  $glancefilebak
	egrep -v "^ *#|^$" $glancefilebak > $glancefile
	crudini --set $glancefile database connection mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_CTL/glance
	crudini --set $glancefile glance_store stores file,http
	crudini --set $glancefile glance_store default_store file
	crudini --set $glancefile glance_store filesystem_store_datadir /var/lib/glance/images/
	
}

glance_install() {
	apt -y install glance
}

glance_create_db
glance_install
glance_create_domain_project_user_role
glance_config