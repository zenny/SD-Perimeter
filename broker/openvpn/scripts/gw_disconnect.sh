#!/bin/bash

. /etc/openvpn/scripts/config.sh

##insert data disconnected to table log
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway_log SET log_end_time=now(),log_received='$bytes_received',log_send='$bytes_sent' WHERE log_trusted_ip='$trusted_ip' AND log_trusted_port='$trusted_port' AND gateway_name='$common_name' AND log_end_time='0000-00-00 00:00:00'"
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway SET gateway_online='no' WHERE gateway_name='$common_name' AND gateway_name not in (select gateway_id from gateway_log where log_end_time='0000-00-00 00:00:00')"
