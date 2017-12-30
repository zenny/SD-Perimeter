#!/bin/bash

DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

RESOURCE_PORT=()
RESOURCE_GROUP=()
SQUID_DIR="/etc/squid"
SQUID_DIR_CONF="$SQUID_DIR/squid.conf.d"
SQUID_PEER_CONF="$SQUID_DIR_CONF/cache_peers.conf"
SQUID_ACL_CONF="$SQUID_DIR_CONF/acl_sdp.conf"
SQUID_ACCESS="$SQUID_DIR_CONF/http_access.conf"
SQUID_CACHE_ACCESS="$SQUID_DIR_CONF/never_direct.conf"

function resourceGateway {
  echo
  echo "Your available gateways are:"
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "select gateway_name,gateway_ip from gateway where gateway_ip != '$GATEWAY_GATEWAY'"
  echo
  read -p "Enter the IP of the gateway that will be protecting this resource?  Enter DIRECT if this resource does not have a gateway: " GATEWAY_ADDRESS
  if [ "$GATEWAY_ADDRESS" != "`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select gateway_ip from gateway where gateway_ip='$GATEWAY_ADDRESS'"`" ]; then
    echo "Value entered does not exist, using DIRECT"
    GATEWAY_ADDRESS="DIRECT"
  fi
}

function resourceType {
  echo
  read -r -p "Will this be a Web Resource or TCP Resource ['web/tcp'] " RESOURCE_TYPE
  case "$RESOURCE_TYPE" in
    [wW][eE][bB]|[wW]) 
        RESOURCE_TYPE=web
        ;;
    [tT][cC][pP]|[tT])
        RESOURCE_TYPE=tcp
        ;;
    *)
        echo "You did not enter a value. Exiting."
        exit
        ;;
  esac
}

function resourceDomain {
  echo
  read -p "What is the DOMAIN or IP of your resource? " RESOURCE_DOMAIN
}

function resourcePorts {
  echo
  read -p "Enter a new port for this resource? " newPort
  if [ -z "$newPort" ]; then
    echo
    echo "You must choose at least one port!"
    resourcePorts
  fi
  if [ "$newPort" -lt 1 ] || [ "$newPort" -gt 65535 ]; then
    echo
    echo "You must choose a valid port number! [1-65535] "
    resourcePorts
  fi
  RESOURCE_PORT+=("$newPort")
  unset newPort
  read -r -p "Would you you like to add another port? [Y/n] " addPort
  case "$addPort" in
    [yY][eE][sS]|[yY]) 
        resourcePorts
        ;;
    *)
        echo ""
        ;;
  esac
}

function resourceGroups {
  echo
  read -p "Enter a new group for this resource? " newGroup
  RESOURCE_GROUP+=("$newGroup")
  unset newGroup
  read -r -p "Would you you like to add another group? [Y/n] " addGroup
  case "$addGroup" in
    [yY][eE][sS]|[yY])
        resourceGroups
        ;;
    *)
        echo ""
        ;;
  esac
  if [ `echo ${#RESOURCE_GROUP[@]}` -eq 0  ]; then
    RESOURCE_GROUP+=("all_users")
  fi
}

function insertDB {
  ## Insert SDP Resource
  if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from sdp_resource where resource_name='$RESOURCE_NAME' and resource_type='$RESOURCE_TYPE'"` -lt 1 ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_resource (resource_name, resource_type, resource_enabled, resource_start_date, resource_end_date) values ('$RESOURCE_NAME','$RESOURCE_TYPE','yes',now(),now() + INTERVAL 50 year)"
  fi
  ##Insert Domains
  if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from sdp_resource_address where resource_id = (select resource_id from sdp_resource where resource_name='$RESOURCE_NAME')"` -lt 1 ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_resource_address (address_name, address_domain, resource_id) values ('$RESOURCE_DOMAIN','$RESOURCE_DOMAIN',(select resource_id from sdp_resource where resource_name='$RESOURCE_NAME'))"
  fi
  ##Insert Groups
  for name in "${RESOURCE_GROUP[@]}"
  do
    if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from ugroup where ugroup_name = '$name'"` -lt 1 ] && [ "$name" != "all_users" ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into ugroup (ugroup_name, ugroup_description) values ('$name','$name')"
    fi
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_resource_group (resource_id,ugroup_id) values ((select resource_id from sdp_resource where resource_name='$RESOURCE_NAME'),(select ugroup_id from ugroup where ugroup_name='$name'))"
  done
  ##Insert Ports
  for number in "${RESOURCE_PORT[@]}"
  do
    if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from sdp_resource_port where port_number = '$number' and resource_id = (select resource_id from sdp_resource where resource_name='$RESOURCE_NAME')"` -lt 1 ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_resource_port (port_name,port_number,port_protocol,resource_id) values ('$number','$number','tcp',(select resource_id from sdp_resource where resource_name='$RESOURCE_NAME'))"
    fi
  done
  ##Gateway Association
  if [ "$GATEWAY_ADDRESS" != "DIRECT" ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_gateway_resource (gateway_id,resource_id) values ((select gateway_id from gateway where gateway_ip='$GATEWAY_ADDRESS'),(select resource_id from sdp_resource where resource_name='$RESOURCE_NAME'))"
  else
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into sdp_gateway_resource (gateway_id,resource_id) values ((select gateway_id from gateway where gateway_ip='$GATEWAY_GATEWAY'),(select resource_id from sdp_resource where resource_name='$RESOURCE_NAME'))"
  fi
}

function writeSquid {
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACL_CONF
  echo "acl ${RESOURCE_NAME}_domain dstdomain $RESOURCE_DOMAIN" >> $SQUID_ACL_CONF

  sed -i "/\ ${RESOURCE_NAME}_group/d" $SQUID_ACL_CONF
  echo "acl ${RESOURCE_NAME}_group external sdp_user_groups $RESOURCE_NAME" >> $SQUID_ACL_CONF

  sed -i "/\ ${RESOURCE_NAME}_port/d" $SQUID_ACL_CONF
  echo "acl ${RESOURCE_NAME}_port port ${RESOURCE_PORT[@]}" >> $SQUID_ACL_CONF

  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_CACHE_ACCESS
  if [ "$GATEWAY_ADDRESS" != "DIRECT" ]; then
    echo "cache_peer_access $GATEWAY_ADDRESS allow ${RESOURCE_NAME}_domain" >> $SQUID_CACHE_ACCESS
    echo "never_direct allow ${RESOURCE_NAME}_domain" >> $SQUID_CACHE_ACCESS
  fi

  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACCESS
  echo "http_access allow ${RESOURCE_NAME}_domain ${RESOURCE_NAME}_port ${RESOURCE_NAME}_group" >> $SQUID_ACCESS

  echo "http_access deny ${RESOURCE_NAME}_domain" >> $SQUID_ACCESS

  service squid reload

  #### Shouldn't have to do anything special for tcp resources, but just in case, this is a start
  ##if [ $RESOURCE_TYPE == "tcp" ]; then
  ##  for port in "${RESOURCE_PORT[@]}"
  ##  do
  ##    if [ `grep -c -e "-A REDSOCKS -s $CLIENT_NET -p tcp --dport $port -j RETURN"` -lt 1 ]; then
  ##    fi
  ##  done
  ##fi

  if [ $RESOURCE_TYPE == 'tcp' ]; then
    if [ ! -e "$OPENVPN_CLIENT_FOLDER/DEFAULT" ]; then
      touch $OPENVPN_CLIENT_FOLDER/DEFAULT
    fi
    echo "push \"route $RESOURCE_DOMAIN 255.255.255.255\"" >> $OPENVPN_CLIENT_FOLDER/DEFAULT
  fi
}

function deleteResource {
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "delete from sdp_resource where resource_name='$RESOURCE_NAME'"
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_port/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_group/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_CACHE_ACCESS
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACCESS
  service squid reload
}

function defineResource {
  resourceGateway
  resourceType
  resourceDomain
  resourcePorts
  resourceGroups
  
  echo "Resource Definition:"
  echo
  echo "Resource Name = $RESOURCE_NAME"
  echo "Resource Type = $RESOURCE_TYPE"
  echo "Resource Ports = ${RESOURCE_PORT[@]}"
  echo "Resource Groups = ${RESOURCE_GROUP[@]}"
}

function startAgain {
  echo
  read -r -p "Would you like to manage another? [y/N] " ANSWER
  case "$ANSWER" in
    [yY][eE][sS]|[yY])
        start
        ;;
    *)
        exit
        ;;
  esac
}

function start {
  unset RESOURCE_NAME
  unset RESOURCE_TYPE
  unset RESOURCE_PORT
  unset RESOURCE_GROUP
  read -p "What name would you like to use for your resource? " RESOURCE_NAME
  RESOURCE_EXISTS=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from sdp_resource where resource_name='$RESOURCE_NAME'"`
  if [ "$RESOURCE_EXISTS" -gt 0 ]; then
    echo "Resource exists, what would you like to do?"
    PS3='Choose an Option to Continue: '
    options=("Update Resource" "Delete Resource" "Cancel")
    select opt in "${options[@]}"
    do
      case $opt in
        "Update Resource")
          echo "Rebuilding resource definition for $RESOURCE_NAME"
          deleteResource
          defineResource
          insertDB
          writeSquid
          startAgain
          break
          ;;
        "Delete Resource")
          deleteResource
          startAgain
          break
          ;;
        "Cancel")
          startAgain
          exit
          ;;
        *) echo invalid option;;
      esac
    done
    exit
  else
    defineResource
    insertDB
    writeSquid
    startAgain
  fi
}

start

