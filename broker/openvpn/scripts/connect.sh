#!/bin/bash

. /opt/sdp/scripts/config.sh

##Dynamically find routes to push to client
TMPFILE=$1
IPQuery=$(mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -Nse "
        select distinct(sra.address_domain) 
        from sdp_resource_address sra
        inner join sdp_resource as sr on sr.resource_id = sra.resource_id
        inner join sdp_resource_group as srg on sr.resource_id = srg.resource_id
        inner join ugroup as g on g.ugroup_id = srg.ugroup_id
        inner join user_group as ug on g.ugroup_id = ug.ugroup_id 
        inner join user u on ug.user_id = u.user_id
        where sr.resource_type = 'tcp'
        and u.user_mail = '$common_name'")

touch $TMPFILE
echo "push \"dhcp-option DNS 8.8.8.8\"" > $TMPFILE
echo "push \"dhcp-option PROXY_HTTP $CLIENT_GATEWAY 3128\"" >> $TMPFILE
echo "push \"dhcp-option PROXY_HTTPS $CLIENT_GATEWAY 3128\"" >> $TMPFILE
echo "push \"dhcp-option PROXY_AUTO_CONFIG_URL http://${CLIENT_GATEWAY}/sdp_pac.php\"" >> $TMPFILE
for value in $IPQuery
do
  echo "push \"route $value 255.255.255.255\"" >> $TMPFILE
done

##Close out any sessions with the same IP as us
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE log SET log_end_time=now(),log_received='0',log_send='0' WHERE log_remote_ip='$ifconfig_pool_remote_ip' AND log_end_time='0000-00-00 00:00:00'"

##insert data connection to table log
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE user SET user_online='yes' WHERE user_mail='$common_name'"

mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "INSERT INTO log (log_id,user_id,log_trusted_ip,log_trusted_port,log_remote_ip,log_remote_port,log_start_time,log_end_time,log_received,log_send) VALUES(NULL,'$common_name','$trusted_ip','$trusted_port','$ifconfig_pool_remote_ip','$remote_port_1',now(),'0000-00-00 00:00:00','0','0')"

##Lookup Geo Data about Clients originating IP
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

## Insert Geo Data
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "update log set log_country_code='$GEO_CC',log_country_name='$GEO_CN',log_region='$GEO_RC',log_region_name='$GEO_RN',log_city='$GEO_CITY',log_zip='$GEO_ZIP',log_timezone='$GEO_TZ',log_lat='$GEO_LAT',log_long='$GEO_LON' where log_end_time='0000-00-00 00:00:00' and log_trusted_ip='$trusted_ip'"
