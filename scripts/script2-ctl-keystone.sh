#!/bin/bash
source config.sh
keystone_create_db () {
	echo "Create database for Keystone"
#
#mysqladmin -u root password $mysql_pass
#mysql -uroot -p$mysql_pass -e "create database keystone"
#mysql -uroot -p$mysql_pass -e "grant all privileges on keystone.* to keystone@'localhost' identified by '$mysql_pass'; "
#mysql -uroot -p$mysql_pass -e "grant all privileges on keystone.* to keystone@'%' identified by 'password'; "
#mysql -uroot -p$mysql_pass -e "flush privileges; "
#
#mysql -u root <<-EOF
#CREATE DATABASE keystone;
#GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
#GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
#FLUSH PRIVILEGES;
#EOF
cat << EOF | mysql
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
FLUSH PRIVILEGES;
EOF
}
keystone_install () {
	echo "Installing keystone packages"
    apt -y install keystone python3-openstackclient apache2 libapache2-mod-wsgi-py3 python3-oauth2client
}
keystone_config () {
	echo "Updating keystone config"
	keystonefile=/etc/keystone/keystone.conf
	keystonefilebak=/etc/keystone/keystone.conf.bak
	mv $keystonefile $keystonefilebak
cat > $keystonefile << EOF
[DEFAULT]
debug = True
log_dir = /var/log/keystone
[application_credential]
[assignment]
[auth]
[cache]
memcache_servers = $HOST_CTL_IP:11211
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOST_CTL/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[extra_headers]
Distribution = Ubuntu
[federation]
[fernet_receipts]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[jwt_tokens]
[ldap]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[policy]
[profiler]
[receipt]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[token]
provider = fernet
[tokenless_auth]
[totp]
[trust]
[unified_limit]
[wsgi]
EOF
	#crudini --set $keystonefile database connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOST_CTL/keystone
	#crudini --set $keystonefile token provider fernet
	#crudini --set $keystonefile cache memcache_servers $HOST_CTL_IP:11211
	
	chmod 640 $keystonefile
	chown root:keystone $keystonefile
}
keystone_populate_db () {
	echo "DB Synchronize"
	su -s /bin/bash keystone -c "keystone-manage db_sync"
}
keystone_initialize_key () {
	echo "Keystone initial"
	keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
	keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
}
	
keystone_bootstrap () {
	echo "keystone bootstrapping"
	keystone-manage bootstrap --bootstrap-password $ADMIN_PASS --bootstrap-admin-url http://$HOST_CTL:5000/v3/ --bootstrap-internal-url http://$HOST_CTL:5000/v3/ --bootstrap-public-url http://$HOST_CTL:5000/v3/ --bootstrap-region-id RegionOne
}
keystone_config_apache () {
	echo "Configure the Apache HTTP server"
	echo "ServerName $HOST_CTL" >> /etc/apache2/apache2.conf
}
# Function finalize the installation
keystone_finalize_install () {
	echo "Finalize the installation"
	systemctl restart apache2
	systemctl enable apache2
}
keystone_create_domain_project_user_role () {
	export OS_USERNAME=admin
	export OS_PASSWORD=$ADMIN_PASS
	export OS_PROJECT_NAME=admin
	export OS_USER_DOMAIN_NAME=Default
	export OS_PROJECT_DOMAIN_NAME=Default
	export OS_AUTH_URL=http://$HOST_CTL:5000/v3
	export OS_IDENTITY_API_VERSION=3
	
	echo "Create domain, projects, users and roles"
	openstack project create --domain default --description "Service Project" service
}
# Function create OpenStack client environment scripts
keystone_create_opsclient_scripts () {
	echo "Create OpenStack client environment scripts" 
	cat << EOF > /root/admin-openrc
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$HOST_CTL:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
	chmod +x /root/admin-openrc
}
# Function verifying keystone
keystone_verify () {
	echo "Verifying keystone"
	source /root/admin-openrc
	openstack token issue
}

keystone_create_db
keystone_install
keystone_config
keystone_populate_db
keystone_initialize_key
keystone_bootstrap
keystone_config_apache
keystone_finalize_install
keystone_create_domain_project_user_role
keystone_create_opsclient_scripts
keystone_verify