#!/bin/bash

. /etc/openvpn/scripts/config.sh

##Ensure any open sessions are marked closed
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway_log SET log_end_time=now() WHERE log_end_time='0000-00-00 00:00:00'"
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway SET gateway_online='no' WHERE gateway_name='$common_name' AND gateway_name not in (select gateway_id from gateway_log where log_end_time='0000-00-00 00:00:00')"
