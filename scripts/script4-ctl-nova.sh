#!/bin/bash

source config.sh

nova_create_domain_project_user_role() {
	echo "create nova user"
	source /root/admin-openrc
	openstack user create --domain default --project service --password $NOVA_PASS nova
	openstack role add --project service --user nova admin
	openstack service create --name nova --description "OpenStack Compute service" compute
	openstack endpoint create --region RegionOne compute public http://$HOST_CTL:8774/v2.1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne compute internal http://$HOST_CTL:8774/v2.1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne compute admin http://$HOST_CTL:8774/v2.1/%\(tenant_id\)s
}

placement_create_domain_project_user_role() {
	echo "create placement user"
	source /root/admin-openrc
	openstack user create --domain default --project service --password $PLACEMENT_PASS placement
	openstack role add --project service --user placement admin
	openstack service create --name placement --description "OpenStack Compute Placement service" placement
	openstack endpoint create --region RegionOne placement public http://$HOST_CTL:8778
	openstack endpoint create --region RegionOne placement internal http://$HOST_CTL:8778
	openstack endpoint create --region RegionOne placement admin http://$HOST_CTL:8778
}


nova_create_db () {
	echo "create nova DB"
	cat << EOF | mysql
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF
}

nova_api_create_db () {
	echo "create nova api db"
	cat << EOF | mysql
CREATE DATABASE nova_api;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF
}

placement_create_db () {
	echo "create placement db"
	cat << EOF | mysql
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$PLACEMENT_DBPASS';
FLUSH PRIVILEGES;
EOF
}

cell_create_db () {
	echo "create cell db"
	cat << EOF | mysql
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF
}

nova_install() {
	echo "create nova packages"
    apt -y install nova-api nova-conductor nova-scheduler nova-novncproxy placement-api python3-novaclient
}

kvm_install() {
	echo "create KVM on machine"
	apt -y install qemu-kvm libvirt-daemon-system libvirt-daemon virtinst bridge-utils libosinfo-bin
}

compute_install() {
    apt -y install nova-compute nova-compute-kvm guestmount
}

nova_config () {
	echo "updating nova config"
	novafile=/etc/nova/nova.conf
	novafilebak=/etc/nova/nova.conf.bak
	mv $novafile  $novafilebak
cat > $novafile << EOF
[DEFAULT]
debug = True
osapi_compute_listen = $HOST_CTL_IP
osapi_compute_listen_port = 8774
metadata_listen = $HOST_CTL_IP
metadata_listen_port = 8775
state_path = /var/lib/nova
enabled_apis = osapi_compute,metadata
log_dir = /var/log/nova
transport_url = rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_CTL
compute_driver = libvirt.LibvirtDriver
[api]
auth_strategy = keystone
[vnc]
enabled = True
novncproxy_host = $HOST_CTL_IP
novncproxy_port = 6080
novncproxy_base_url = http://$HOST_CTL:6080/vnc_auto.html
server_listen = $HOST_CTL_IP
server_proxyclient_address = $HOST_CTL_IP
[glance]
api_servers = http://$HOST_CTL:9292
[oslo_concurrency]
lock_path = \$state_path/tmp
[api_database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOST_CTL/nova_api
[database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOST_CTL/nova
[keystone_authtoken]
www_authenticate_uri = http://$HOST_CTL:5000
auth_url = http://$HOST_CTL:5000
memcached_servers = $HOST_CTL:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = $NOVA_PASS
[placement]
auth_url = http://$HOST_CTL:5000
os_region_name = RegionOne
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = placement
password = $PLACEMENT_PASS
[wsgi]
api_paste_config = /etc/nova/api-paste.ini
[oslo_policy]
enforce_new_defaults = true
[libvirt]
virt_type = kvm

EOF
#	crudini --set $novafile DEFAULT osapi_compute_listen $HOST_CTL_IP
#	crudini --set $novafile DEFAULT osapi_compute_listen_port 8774
#	crudini --set $novafile DEFAULT metadata_listen $HOST_CTL_IP
#	crudini --set $novafile DEFAULT metadata_listen_port 8775
#	crudini --set $novafile DEFAULT state_path /var/lib/nova
#	crudini --set $novafile DEFAULT enabled_apis osapi_compute,metadata
#	crudini --set $novafile DEFAULT log_dir /var/log/nova
#	crudini --set $novafile DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_CTL
#
#	crudini --set $novafile api auth_strategy keystone
#
#	crudini --set $novafile vnc enabled True
#	crudini --set $novafile vnc server_listen $HOST_CTL_IP
#	crudini --set $novafile vnc server_proxyclient_address $HOST_CTL_IP
#	crudini --set $novafile vnc novncproxy_host $HOST_CTL_IP
#	crudini --set $novafile vnc novncproxy_port 6080
#	crudini --set $novafile vnc novncproxy_base_url http://$HOST_CTL:6080/vnc_auto.html
#	crudini --set $novafile glance api_servers http://$HOST_CTL:9292
#
#	crudini --set $novafile oslo_concurrency lock_path \$state_path/tmp
#
#	crudini --set $novafile api_database connection mysql+pymysql://nova:$NOVA_DBPASS@$HOST_CTL/nova_api
#	crudini --set $novafile database connection mysql+pymysql://nova:$NOVA_DBPASS@$HOST_CTL/nova
#
#	crudini --set $novafile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
#	crudini --set $novafile keystone_authtoken auth_url http://$HOST_CTL:5000
#	crudini --set $novafile keystone_authtoken memcached_servers $HOST_CTL:11211
#	crudini --set $novafile keystone_authtoken auth_type password
#	crudini --set $novafile keystone_authtoken project_domain_name default
#	crudini --set $novafile keystone_authtoken user_domain_name default
#	crudini --set $novafile keystone_authtoken project_name service
#	crudini --set $novafile keystone_authtoken username nova
#	crudini --set $novafile keystone_authtoken password $NOVA_PASS
#
#	crudini --set $novafile placement auth_url http://$HOST_CTL:5000
#	crudini --set $novafile placement os_region_name RegionOne
#	crudini --set $novafile placement auth_type password
#	crudini --set $novafile placement project_domain_name default
#	crudini --set $novafile placement user_domain_name default
#	crudini --set $novafile placement project_name service
#	crudini --set $novafile placement username placement
#	crudini --set $novafile placement password $PLACEMENT_PASS
#
#	crudini --set $novafile wsgi api_paste_config /etc/nova/api-paste.ini
#
#	crudini --set $novafile oslo_policy enforce_new_defaults true

	chmod 640 $novafile
	chown root:nova $novafile
}


placement_config() {
	echo "update placement config"
	placementfile=/etc/placement/placement.conf
	placementfilebak=/etc/placement/placement.conf.bak
	mv $placementfile  $placementfilebak
cat > $placementfile << EOF
[DEFAULT]
debug = true
[api]
auth_strategy = keystone
[keystone_authtoken]
www_authenticate_uri = http://$HOST_CTL:5000
auth_url = http://$HOST_CTL:5000
memcached_servers = $HOST_CTL:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = placement
password = $PLACEMENT_PASS
[placement_database]
connection = mysql+pymysql://placement:$PLACEMENT_DBPASS@$HOST_CTL/placement

EOF

#	crudini --set $placementfile DEFAULT debug false
#
#	crudini --set $placementfile api auth_strategy keystone
#
#	crudini --set $placementfile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
#	crudini --set $placementfile keystone_authtoken auth_url http://$HOST_CTL:5000
#	crudini --set $placementfile keystone_authtoken memcached_servers $HOST_CTL:11211
#	crudini --set $placementfile keystone_authtoken auth_type password
#	crudini --set $placementfile keystone_authtoken project_domain_name default
#	crudini --set $placementfile keystone_authtoken user_domain_name default
#	crudini --set $placementfile keystone_authtoken project_name service
#	crudini --set $placementfile keystone_authtoken username placement
#	crudini --set $placementfile keystone_authtoken password $PLACEMENT_PASS
#
#	crudini --set $placementfile placement_database connection mysql+pymysql://placement:$PLACEMENT_DBPASS@$HOST_CTL/placement

	chmod 640 $placementfile
	chown root:placement $placementfile
}


placement_nova_db_sync() {
	echo "nova db synchronize"
	su -s /bin/bash placement -c "placement-manage db sync"
	su -s /bin/bash nova -c "nova-manage api_db sync"
	su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0"
	su -s /bin/bash nova -c "nova-manage db sync"
	su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1"
}


placement_nova_service() {
	echo "nova service restart"
	systemctl restart nova-api nova-conductor nova-scheduler nova-novncproxy
	systemctl enable nova-api nova-conductor nova-scheduler nova-novncproxy
}

nova_install
kvm_install
compute_install
nova_create_db 
nova_api_create_db 
placement_create_db 
nova_create_domain_project_user_role
placement_create_domain_project_user_role
cell_create_db 
nova_config 
placement_config
placement_nova_db_sync
placement_nova_service