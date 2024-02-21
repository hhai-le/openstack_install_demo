#!/bin/bash

source config.sh

compute_discover() {
	echo "Discover new compute hosts"
	su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
}

compute_discover