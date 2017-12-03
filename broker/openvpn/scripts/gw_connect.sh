#!/bin/bash

. /etc/openvpn/scripts/config.sh

##Close out any sessions with the same IP as us
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway_log SET log_end_time=now(),log_received='0',log_send='0' WHERE log_remote_ip='$ifconfig_pool_remote_ip' AND log_end_time='0000-00-00 00:00:00'"

##insert data connection to table log
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE gateway SET gateway_online='yes' WHERE gateway_name='$common_name'"

mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "INSERT INTO gateway_log (log_id,gateway_id,log_trusted_ip,log_trusted_port,log_remote_ip,log_remote_port,log_start_time,log_end_time,log_received,log_send) VALUES(NULL,'$common_name','$trusted_ip','$trusted_port','$ifconfig_pool_remote_ip','$remote_port_1',now(),'0000-00-00 00:00:00','0','0')"

GEODATA=`curl -s freegeoip.net/json/$trusted_ip`
GEO_CC=`echo $GEODATA | jq -r '.country_code'`
GEO_CN=`echo $GEODATA | jq -r '.country_name'`
GEO_RC=`echo $GEODATA | jq -r '.region_code'`
GEO_RN=`echo $GEODATA | jq -r '.region_name'`
GEO_CITY=`echo $GEODATA | jq -r '.city'`
GEO_ZIP=`echo $GEODATA | jq -r '.zip_code'`
GEO_TZ=`echo $GEODATA | jq -r '.time_zone'`
GEO_LAT=`echo $GEODATA | jq -r '.latitude'`
GEO_LON=`echo $GEODATA | jq -r '.longitude'`

mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "update gateway_log set log_country_code='$GEO_CC',log_country_name='$GEO_CN',log_region='$GEO_RC',log_region_name='$GEO_RN',log_city='$GEO_CITY',log_zip='$GEO_ZIP',log_timezone='$GEO_TZ',log_lat='$GEO_LAT',log_long='$GEO_LON' where log_end_time='0000-00-00 00:00:00' and log_trusted_ip='$trusted_ip'"
