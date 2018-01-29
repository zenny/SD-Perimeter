#!/bin/bash

DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG


SQUID_DIR="/etc/squid"
SQUID_DIR_CONF="$SQUID_DIR/squid.conf.d"
SQUID_PEER_CONF="$SQUID_DIR_CONF/cache_peers.conf"
SQUID_PEER_DENY_CONF="$SQUID_DIR_CONF/cache_peer_deny.conf"
SQUID_ACL_CONF="$SQUID_DIR_CONF/acl_sdp.conf"
SQUID_ACCESS="$SQUID_DIR_CONF/http_access.conf"
SQUID_CACHE_ACCESS="$SQUID_DIR_CONF/never_direct.conf"
SQUID_ACL_CLIENTS="$SQUID_DIR_CONF/acl_sdp_clients.conf"

## Remove all existing Squid entries
rm -f $SQUID_PEER_CONF
rm -f $SQUID_PEER_DENY_CONF
rm -f $SQUID_ACL_CONF
rm -f $SQUID_ACCESS
rm -f $SQUID_CACHE_ACCESS
rm -f $SQUID_ACL_CLIENTS
touch $SQUID_PEER_CONF
touch $SQUID_PEER_DENY_CONF
touch $SQUID_ACL_CONF
touch $SQUID_ACCESS
touch $SQUID_CACHE_ACCESS
touch $SQUID_ACL_CLIENTS

## Rebuild Clients ACL
echo "acl sdp_clients src $CLIENT_NET" >> $SQUID_ACL_CLIENTS

## Rebuild Squid Cache Peer Files
GATEWAY_IPS=($(
    for i in `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT GROUP_CONCAT(gateway_ip separator ' ') 
        FROM gateway WHERE gateway_ip != '$GATEWAY_GATEWAY'"`
    do 
      echo $i
    done
))
for gateway in "${GATEWAY_IPS[@]}"
do
  echo "cache_peer $gateway parent $SQUID_PORT 0 no-netdb-exchange proxy-only" >> $SQUID_PEER_CONF
  echo "cache_peer_access $gateway deny all" >> $SQUID_PEER_DENY_CONF
done


## Get names of existing resources
RESOURCE_NAMES=($(
    for i in `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT resource_name FROM sdp_resource"`
    do
      echo $i
    done
))

## Write out squid configs for each resource
for resource in "${RESOURCE_NAMES[@]}"
do
  RESOURCE_DOMAIN=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT sra.address_domain 
        FROM sdp_resource sr
          INNER JOIN sdp_resource_address AS sra ON sr.resource_id = sra.resource_id
        WHERE sr.resource_name='$resource'"`
  echo "acl ${resource}_domain dstdomain $RESOURCE_DOMAIN" >> $SQUID_ACL_CONF
  GATEWAY_ADDRESS=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT g.gateway_ip
        FROM gateway g
          INNER JOIN sdp_gateway_resource AS sgr ON g.gateway_id=sgr.gateway_id
          INNER JOIN sdp_resource AS r ON r.resource_id=sgr.resource_id
        WHERE r.resource_name='$resource'"`
  if [ "$GATEWAY_ADDRESS" != "$GATEWAY_GATEWAY" ]; then
    echo "cache_peer_access $GATEWAY_ADDRESS allow ${resource}_domain" >> $SQUID_CACHE_ACCESS
    echo "never_direct allow ${resource}_domain" >> $SQUID_CACHE_ACCESS
  fi
  RESOURCE_PORT=($(
      for i in `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT srp.port_number 
        FROM sdp_resource r
          INNER JOIN sdp_resource_port AS srp ON r.resource_id=srp.resource_id
        WHERE r.resource_name='$resource'"`
      do
        echo $i
      done
  ))
  echo "acl ${resource}_port port ${RESOURCE_PORT[@]}" >> $SQUID_ACL_CONF
  RESOURCE_GROUP=($(
      for i in `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT g.ugroup_name
        FROM ugroup g
          INNER JOIN sdp_resource_group AS srg ON g.ugroup_id=srg.ugroup_id
          INNER JOIN sdp_resource AS r ON r.resource_id=srg.resource_id
        WHERE r.resource_name='$resource'"`
      do
        echo $i
      done
  ))
  for name in "${RESOURCE_GROUP[@]}"
  do
    if [ `grep -c ${resource}_group $SQUID_ACL_CONF` -lt 1 ]; then
      echo "acl ${resource}_group external sdp_user_groups $resource" >> $SQUID_ACL_CONF
    fi
  done
  for name in "${RESOURCE_GROUP[@]}"
  do
    echo "http_access allow ${resource}_domain ${resource}_port ${resource}_group" >> $SQUID_ACCESS
  done
  echo "http_access deny ${resource}_domain" >> $SQUID_ACCESS
done

## Reload the fresh config
service squid reload
