#!/bin/bash

DB_CONFIG=/etc/openvpn/scripts/config.sh
. $DB_CONFIG

echo
echo "Configured Resources:"
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "select resource_name name, resource_type, resource_enabled from sdp_resource"
echo
