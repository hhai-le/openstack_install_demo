#!/bin/bash
sed -i '/^metadata_secret.*/d' config.sh 
echo "metadata_secret=\"$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24; echo)\"" | tee -a config.sh
