#!/bin/bash

source config.sh

horizon_install () {
	echo "Installing horizon packages"
    apt -y install openstack-dashboard
}

horizon_config () {
    sed -i "s/'LOCATION':.*/'LOCATION': '$HOST_CTL_IP:11211',/" /etc/openstack-dashboard/local_settings.py
    sed -i "/^#SESSION_ENGINE =.*/a SESSION_ENGINE = \"django.contrib.sessions.backends.cache\"" /etc/openstack-dashboard/local_settings.py
    sed -i "s/^OPENSTACK_HOST.*/OPENSTACK_HOST = \"$HOST_CTL_IP\"/" /etc/openstack-dashboard/local_settings.py
    sed -i "s/^OPENSTACK_KEYSTONE_URL.*/OPENSTACK_KEYSTONE_URL = \"http:\/\/$HOST_CTL:5000\/v3\"/" /etc/openstack-dashboard/local_settings.py
cat >> /etc/openstack-dashboard/local_settings.py << EOF
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'
EOF
}

service_restart () {
    systemctl restart apache2 nova-api
}