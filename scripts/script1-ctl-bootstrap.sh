#!/bin/bash
source config.sh
#Install crudini.
apt install crudini -y
install_rabbitmq() {
	echo "Installing RabbitMQ Server"
    apt install rabbitmq-server -y
    rabbitmqctl add_user openstack $RABBIT_PASS
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"
}
install_memcached () {
	echo "Install Memcached"
	apt-get install memcached -y
	MEMCAHCEFILE=/etc/memcached.conf
	sed -i "s/-l 127.0.0.1/-l $HOST_CTL_IP/" $MEMCAHCEFILE
	service memcached restart
} 
install_mysql(){
	echocolor "Install MariaDB Server"
    apt install -y mariadb-server python3-pymysql
    crudini --set /etc/mysql/mariadb.conf.d/50-server.cnf mysqld bind-address $HOST_CTL_IP
    crudini --set /etc/mysql/mariadb.conf.d/50-server.cnf mysqld max_connections 500
    crudini --set /etc/mysql/mariadb.conf.d/50-server.cnf mysqld character-set-server utf8mb4
    crudini --set /etc/mysql/mariadb.conf.d/50-server.cnf mysqld collation-server utf8mb4_general_ci
}
install_rabbitmq
install_memcached
install_mysql