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
	source /root/admin-openrc
	openstack user create --domain default --project service --password $GLANCE_PASS glance
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
	crudini --set $glancefile DEFAULT bind_host 127.0.0.1
	crudini --set $glancefile DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_CTL
	
	crudini --set $glancefile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
	crudini --set $glancefile keystone_authtoken auth_url http://$HOST_CTL:5000
	crudini --set $glancefile keystone_authtoken memcached_servers $HOST_CTL:11211
	crudini --set $glancefile keystone_authtoken auth_type password
	crudini --set $glancefile keystone_authtoken project_domain_name default
	crudini --set $glancefile keystone_authtoken user_domain_name default
	crudini --set $glancefile keystone_authtoken project_name service
	crudini --set $glancefile keystone_authtoken username glance
	crudini --set $glancefile keystone_authtoken password $GLANCE_PASS
	
	crudini --set $glancefile paste_deploy flavor keystone
	crudini --set $glancefile oslo_policy enforce_new_defaults true

	chmod 640 $glancefile
	chown root:glance $glancefile

}


glance_install() {
	apt -y install glance
}

glance_db_sync() {
	su -s /bin/bash glance -c "glance-manage db_sync"
}

glance_service() {
	systemctl restart glance-api
	systemctl enable glance-api
}

glance_create_db
glance_install
glance_create_domain_project_user_role
glance_config
glance_db_sync
glance_service