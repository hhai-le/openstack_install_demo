#!/bin/bash

source config.sh

nova_kvm_install() {
    apt -y install nova-compute nova-compute-kvm qemu-kvm libvirt-daemon-system libvirt-daemon virtinst bridge-utils libosinfo-bin qemu-system-data
}


nova_config () {
	novafile=/etc/nova/nova.conf
	novafilebak=/etc/nova/nova.conf.bak
	cp $novafile  $novafilebak
	egrep -v "^ *#|^$" $novafilebak > $novafile

	crudini --set $novafile DEFAULT state_path /var/lib/nova
	crudini --set $novafile DEFAULT enabled_apis osapi_compute,metadata
	crudini --set $novafile DEFAULT log_dir /var/log/nova
	crudini --set $novafile DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_CTL

	crudini --set $novafile api auth_strategy keystone

	crudini --set $novafile vnc True
	crudini --set $novafile vnc server_listen $HOST_COM_IP
	crudini --set $novafile vnc server_proxyclient_address $HOST_COM_IP
	crudini --set $novafile vnc novncproxy_base_url http://$HOST_CTL:6080/vnc_auto.html

	crudini --set $novafile glance api_servers http://$HOST_CTL:9292

	crudini --set $novafile oslo_concurrency lock_path \$state_path/tmp

	crudini --set $novafile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
	crudini --set $novafile keystone_authtoken auth_url http://$HOST_CTL:5000
	crudini --set $novafile keystone_authtoken memcached_servers $HOST_CTL:11211
	crudini --set $novafile keystone_authtoken auth_type password
	crudini --set $novafile keystone_authtoken project_domain_name default
	crudini --set $novafile keystone_authtoken user_domain_name default
	crudini --set $novafile keystone_authtoken project_name service
	crudini --set $novafile keystone_authtoken username nova
	crudini --set $novafile keystone_authtoken password $NOVA_PASS

	crudini --set $novafile placement auth_url http://$HOST_CTL:5000
	crudini --set $novafile placement os_region_name RegionOne
	crudini --set $novafile placement auth_type password
	crudini --set $novafile placement project_domain_name default
	crudini --set $novafile placement user_domain_name default
	crudini --set $novafile placement project_name service
	crudini --set $novafile placement username placement
	crudini --set $novafile placement password $PLACEMENT_PASS

	crudini --set $novafile wsgi api_paste_config /etc/nova/api-paste.ini

	crudini --set $novafile oslo_policy enforce_new_defaults true

	chmod 640 $novafile
	chown root:nova $novafile
}

nova_service () {
	systemctl restart nova-compute
}

nova_kvm_install
nova_config
nova_service