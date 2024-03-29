#!/bin/bash
source config.sh
#Install crudini.
apt install crudini -y
install_rabbitmq() {
	echo "Installing RabbitMQ Server"
    apt install rabbitmq-server -y
    rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS
    rabbitmqctl set_permissions $RABBIT_USER ".*" ".*" ".*"
    systemctl restart rabbitmq-server
    systemctl enable rabbitmq-server
}
install_memcached () {
	echo "Install Memcached"
	apt install memcached -y
	MEMCAHCEFILE=/etc/memcached.conf
	sed -i "s/-l 127.0.0.1/-l $HOST_CTL_IP/" $MEMCAHCEFILE
    systemctl restart memcached
    systemctl enable memcached
} 
install_mysql(){
	echo "Install MariaDB Server"
    apt install -y mariadb-server python3-pymysql
    mysqlfile="/etc/mysql/mariadb.conf.d/50-server.cnf"
    crudini --set $mysqlfile mysqld bind-address $HOST_CTL_IP
    crudini --set $mysqlfile mysqld max_connections 500
    crudini --set $mysqlfile mysqld character-set-server utf8mb4
    crudini --set $mysqlfile mysqld collation-server utf8mb4_general_ci
    systemctl restart mariadb
    systemctl enable mariadb
}
install_rabbitmq
install_memcached
install_mysql