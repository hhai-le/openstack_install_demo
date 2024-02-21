#!/bin/bash

source config.sh

neutron_install() {
	echo "install neutron packages"
	apt -y install neutron-server neutron-plugin-ml2 neutron-ovn-metadata-agent python3-neutronclient ovn-central ovn-host openvswitch-switch
}

neutron_create_domain_project_user_role() {
	source /root/admin-openrc
	echo "create neutron user, role"
	openstack user create --domain default --project service --password $NEUTRON_PASS neutron
	openstack role add --project service --user neutron admin
	openstack service create --name neutron --description "OpenStack Networking service" network
	openstack endpoint create --region RegionOne network public http://$HOST_CTL:9696
	openstack endpoint create --region RegionOne network internal http://$HOST_CTL:9696
	openstack endpoint create --region RegionOne network admin http://$HOST_CTL:9696
}

neutron_db_create () {
	echo "create neutron DB"
	cat << EOF | mysql
	create database neutron;
	grant all privileges on neutron.* to neutron@'localhost' identified by '$NEUTRON_DBPASS'; 
	grant all privileges on neutron.* to neutron@'%' identified by '$NEUTRON_DBPASS'; 
EOF
}

neutron_config () {
	echo "update neutron config"
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

	crudini --set $neutronfile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
	crudini --set $neutronfile keystone_authtoken auth_url http://$HOST_CTL:5000
	crudini --set $neutronfile keystone_authtoken memcached_servers $HOST_CTL:11211
	crudini --set $neutronfile keystone_authtoken auth_type password
	crudini --set $neutronfile keystone_authtoken project_domain_name default
	crudini --set $neutronfile keystone_authtoken user_domain_name default
	crudini --set $neutronfile keystone_authtoken project_name service
	crudini --set $neutronfile keystone_authtoken username neutron
	crudini --set $neutronfile keystone_authtoken password $NEUTRON_PASS

	crudini --set $neutronfile database connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOST_CTL/neutron

	crudini --set $neutronfile nova auth_url http://$HOST_CTL:5000
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
	chown root:neutron $neutronfile
}


neutron_ml2_ini () {
	echo "update neutron ml2 config"
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
	chown root:neutron $neutronini
}

neutron_ovn_metadata_agent() {
	echo "update neutron metadata agent"
	neutron_ovn_agent=/etc/neutron/neutron_ovn_metadata_agent.ini
	neutron_ovn_agentbak=/etc/neutron/neutron_ovn_metadata_agent.ini.bak
	cp $neutron_ovn_agent  $neutron_ovn_agentbak
	egrep -v "^ *#|^$" $neutron_ovn_agentbak > $neutron_ovn_agent

	crudini --set $neutron_ovn_agent DEFAULT nova_metadata_host $HOST_CTL
	crudini --set $neutron_ovn_agent DEFAULT nova_metadata_protocol http
	crudini --set $neutron_ovn_agent DEFAULT metadata_proxy_shared_secret $metadata_secret

	crudini --set $neutron_ovn_agent ovs ovsdb_connectiontcp:127.0.0.1:6640

	crudini --set $neutron_ovn_agent agent root_helpersudo neutron-rootwrap /etc/neutron/rootwrap.conf
	
	crudini --set $neutron_ovn_agent ovn ovn_sb_connectiontcp:$HOST_CTL_IP:6642
}

openvswitch_switch () {
	echo "update openvswitch config"
	sed -i 's/# OVS_CTL_OPTS=/OVS_CTL_OPTS="--ovsdb-server-options='--remote=ptcp:6640:$HOST_CTL_IP'"/' /etc/default/openvswitch-switch
}

neutron_nova_conf () {
	echo "update neutron setting in nova config file"
	novafile=/etc/nova/nova.conf
	crudini --set DEFAULT vif_plugging_is_fatal True
	crudini --set DEFAULT vif_plugging_timeout 300

	crudini --set $novafile neutron auth_url http://$HOST_CTL:5000
	crudini --set $novafile neutron auth_type password
	crudini --set $novafile neutron project_domain_name default
	crudini --set $novafile neutron user_domain_name default
	crudini --set $novafile neutron region_name RegionOne
	crudini --set $novafile neutron project_name service
	crudini --set $novafile neutron username neutron
	crudini --set $novafile neutron password $NEUTRON_PASS
	crudini --set $novafile neutron service_metadata_proxy True
	crudini --set $novafile neutron metadata_proxy_shared_secret $metadata_secret
}

neutron_initial () {
	echo "neutron initial"
	systemctl restart openvswitch-switch
	ovs-vsctl add-br br-int
	ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
	su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"
	systemctl restart ovn-central ovn-northd ovn-controller ovn-host
	ovn-nbctl set-connection ptcp:6641:$HOST_CTL_IP -- set connection . inactivity_probe=60000
	ovn-sbctl set-connection ptcp:6642:$HOST_CTL_IP -- set connection . inactivity_probe=60000
	ovs-vsctl set open . external-ids:ovn-remote=tcp:$HOST_CTL_IP:6642
	ovs-vsctl set open . external-ids:ovn-encap-type=geneve
	ovs-vsctl set open . external-ids:ovn-encap-ip=$HOST_CTL_IP
	systemctl restart neutron-server neutron-ovn-metadata-agent nova-api nova-compute
}


neutron_create_domain_project_user_role
neutron_db_create
neutron_install
neutron_config
neutron_ml2_ini
openvswitch_switch
neutron_nova_conf