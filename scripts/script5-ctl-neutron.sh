#!/bin/bash

source config.sh

neutron_install() {
	apt -y install neutron-server neutron-plugin-ml2 neutron-ovn-metadata-agent python3-neutronclient ovn-central ovn-host openvswitch-switch
}

neutron_create_domain_project_user_role() {
	openstack user create --domain default --project service --password $NEUTRON_PASS neutron
	openstack role add --project service --user neutron admin
	openstack service create --name neutron --description "OpenStack Networking service" network
	openstack endpoint create --region RegionOne network public http://$HOST_CTL:9696
	openstack endpoint create --region RegionOne network internal http://$HOST_CTL:9696
	openstack endpoint create --region RegionOne network admin http://$HOST_CTL:9696
}

neutron_db_create () {
	cat << EOF | mysql
	create database neutron;
	grant all privileges on neutron.* to neutron@'localhost' identified by '$NEUTRON_DBPASS'; 
	grant all privileges on neutron.* to neutron@'%' identified by '$NEUTRON_DBPASS'; 
EOF
}

neutron_config () {
	neutronfile=/etc/neutron/neutron.conf 
	neutronfilebak=/etc/neutron/neutron.conf.bak
	cp $neutronfile  $neutronfilebak
	egrep -v "^ *#|^$" $neutronfilebak > $neutronfile
	crudini --set $neutronfile DEFAULT bind_host $HOST_CTL_IP
	crudini --set $neutronfile DEFAULT bind_port 9696
	crudini --set $neutronfile DEFAULT core_plugin ml2
	crudini --set $neutronfile DEFAULT service_plugins ovn-router
	crudini --set $neutronfile DEFAULT auth_strategy keystone
	crudini --set $neutronfile DEFAULT state_path /var/lib/neutron
	crudini --set $neutronfile DEFAULT allow_overlapping_ips True
	crudini --set $neutronfile DEFAULT notify_nova_on_port_status_changes True
	crudini --set $neutronfile DEFAULT notify_nova_on_port_data_changes True
	crudini --set $neutronfile DEFAULT transport_url rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_CTL

	crudini --set $neutronfile keystone_authtoken www_authenticate_uri https://$HOST_CTL:5000
	crudini --set $neutronfile keystone_authtoken auth_url https://$HOST_CTL:5000
	crudini --set $neutronfile keystone_authtoken memcached_servers $HOST_CTL:11211
	crudini --set $neutronfile keystone_authtoken auth_type password
	crudini --set $neutronfile keystone_authtoken project_domain_name default
	crudini --set $neutronfile keystone_authtoken user_domain_name default
	crudini --set $neutronfile keystone_authtoken project_name service
	crudini --set $neutronfile keystone_authtoken username neutron
	crudini --set $neutronfile keystone_authtoken password $NEUTRON_PASS

	crudini --set $neutronfile database connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOST_CTL/neutron

	crudini --set $neutronfile nova auth_url https://$HOST_CTL:5000
	crudini --set $neutronfile nova auth_type password
	crudini --set $neutronfile nova project_domain_name default
	crudini --set $neutronfile nova user_domain_name default
	crudini --set $neutronfile nova region_name RegionOne
	crudini --set $neutronfile nova project_name service
	crudini --set $neutronfile nova username nova
	crudini --set $neutronfile nova password $NOVA_PASS

	crudini --set $neutronfile oslo_concurrency lock_path \$state_path/tmp
	crudini --set $neutronfile oslo_policy enforce_new_defaults true
	
	chmod 640 $neutronfile
	chown root:nova $neutronfile
}


neutron_ml2_ini () {
	neutronini=/etc/neutron/plugins/ml2/ml2_conf.ini 
	neutroninibak=/etc/neutron/plugins/ml2/ml2_conf.ini.bak
	cp $neutronini  $neutroninibak
	egrep -v "^ *#|^$" $neutroninibak > $neutronini
	crudini --set $neutronini DEFAULT debug false

	crudini --set $neutronini ml2 type_drivers flat,geneve
	crudini --set $neutronini ml2 tenant_network_types geneve
	crudini --set $neutronini ml2 mechanism_drivers ovn
	crudini --set $neutronini ml2 extension_drivers port_security
	crudini --set $neutronini ml2 overlay_ip_version 4
	crudini --set $neutronini ml2_type_geneve vni_ranges 1:65536
	crudini --set $neutronini ml2_type_geneve max_header_size 38
	crudini --set $neutronini ml2_type_flat flat_networks *

	crudini --set $neutronini securitygroup enable_security_group True
	crudini --set $neutronini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

	crudini --set $neutronini ovn ovn_nb_connection tcp:$HOST_CTL_IP:6641
	crudini --set $neutronini ovn ovn_sb_connection tcp:$HOST_CTL_IP:6642
	crudini --set $neutronini ovn ovn_l3_scheduler leastloaded
	crudini --set $neutronini ovn ovn_metadata_enabled True

	chmod 640 $neutronini
	chown root:nova $neutronini
}

neutron_ovn_metadata_agent() {
	neutron_ovn_agent=/etc/neutron/neutron_ovn_metadata_agent.ini
	neutron_ovn_agentbak=/etc/neutron/neutron_ovn_metadata_agent.ini.bak
	cp $neutron_ovn_agent  $neutron_ovn_agentbak
	egrep -v "^ *#|^$" $neutron_ovn_agentbak > $neutron_ovn_agent

	crudini --set neutron_ovn_agent DEFAULT nova_metadata_host $HOST_CTL
	crudini --set neutron_ovn_agent DEFAULT nova_metadata_protocol http
	crudini --set neutron_ovn_agent DEFAULT metadata_proxy_shared_secret metadata_secret

	crudini --set neutron_ovn_agent ovs ovsdb_connectiontcp:127.0.0.1:6640

	crudini --set neutron_ovn_agent agent root_helpersudo neutron-rootwrap /etc/neutron/rootwrap.conf
	
	crudini --set neutron_ovn_agent ovn ovn_sb_connectiontcp:$HOST_CTL_IP:6642
}

#openvswitch_switch () {
#	
#}


neutron_create_domain_project_user_role
neutron_db_create
neutron_install
neutron_config
neutron_ml2_ini