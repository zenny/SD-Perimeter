#! /bin/bash

# Set where we're working from
## These will be installation specific
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

function listResources {
  title="List Configured Resource"
  whiptail --textbox --title "$title" --scrolltext /dev/stdin 25 78 <<<"$(
        echo 'Configured Resources:\n\n'
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e '
            SELECT CONCAT(
                  resource_name,";",
                  address_domain,";",
                  resource_type,";",
                  GROUP_CONCAT(DISTINCT(port_number)),";",
                  GROUP_CONCAT(DISTINCT(ugroup_name))
            ) "<RESOURCE NAME>;<DOMAIN/IP>;<TYPE>;<PORT>;<GROUPS>"
            FROM squid_rules_helper
            GROUP BY resource_name
            ORDER BY "Resource Name"
        ' | column -t -s ';')"
  optionsMenu
}

function checkResource {
  RESOURCE_EXISTS=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT count(*)
        FROM sdp_resource
        WHERE resource_name='$RESOURCE_NAME'"`
}

function getActiveResources {
  activeResources=$(mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe '
        SELECT resource_name
        FROM sdp_resource
        WHERE resource_enabled = "yes"
        ORDER BY resource_name
  ')
  activeResourcesArr=()
  for resource in $activeResources
  do
    activeResourcesArr+=("$resource" "")
  done
}

function getActiveGateways {
  activeGateways=$(mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe '
        SELECT gateway_ip,
            gateway_name
        FROM gateway
        WHERE gateway_ip != "'$GATEWAY_GATEWAY'"
  ')
  activeGatewaysArr=("DIRECT" "(Broker will serve as Gateway)")
  for gateway in $activeGateways
  do
    activeGatewaysArr+=("$gateway")
  done
}

function resourceGateway {
  getActiveGateways
  GATEWAY_ADDRESS=$(
    whiptail --title "$title" --menu "\nChoose the gateway that will protect this resource." \
    25 78 16 "${activeGatewaysArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?
}

function resourceType {
  RESOURCE_TYPE=$(
    whiptail --title "$title" --menu "\nWill this be a web resource or TCP resource?" \
    25 78 16 "Web" "" "TCP" "" 3>&2 2>&1 1>&3
  )
  exitstatus=$?
}

function resourceDomain {
  RESOURCE_DOMAIN=$(whiptail --inputbox "\nWhat is the DOMAIN or IP of your resource?" \
    8 78 --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?
}

function resourcePorts {
  newPort=$(
    whiptail --inputbox "\nEnter a new port for this resource:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if [ -z "$newPort" ]; then
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "You must choose at least one port!")
      resourcePorts
    elif [ "$newPort" -lt 1 ] || [ "$newPort" -gt 65535 ]; then
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "You must choose a valid port number! [1025-65535]")
      resourcePorts
    else
      RESOURCE_PORT+=("$newPort")
      unset newPort
      if (whiptail --yesno "Would you like to add another port?" \
          --title "$title" 8 78) then
        resourcePorts
      fi
    fi
  fi
}

function resourceGroups {
  newGroup=$(
    whiptail --inputbox "\nEnter a user group for this resource (Blank for \"all_users\"):" \
      8 78 --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if [ "$newGroup" != "" ]; then
      RESOURCE_GROUP+=("$newGroup")
      unset newGroup
    fi
    if [ `echo ${#RESOURCE_GROUP[@]}` -eq 0 ]; then
      RESOURCE_GROUP+=("all_users")
    else
      if (whiptail --yesno "Would you like to add another group?" \
          --title "$title" 8 78) then
        resourceGroups
      fi
    fi
  fi
}

function insertDB {
  ## Insert SDP Resource
  if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT count(*)
        FROM sdp_resource
        WHERE resource_name='$RESOURCE_NAME'
        AND resource_type='$RESOURCE_TYPE'"` -lt 1 ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_resource (
            resource_name, resource_type, resource_enabled,
            resource_start_date, resource_end_date
        ) VALUES (
            '$RESOURCE_NAME','$RESOURCE_TYPE','yes',
            now(),now() + INTERVAL 50 year
        )"
  fi

  ##Insert Domains
  if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT count(*)
        FROM sdp_resource sr
          INNER JOIN sdp_resource_address AS sra ON sr.resource_id = sra.resource_id 
        WHERE resource_name='$RESOURCE_NAME'"` -lt 1 ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_resource_address (
            address_name, address_domain, resource_id
        ) VALUES (
            '$RESOURCE_DOMAIN','$RESOURCE_DOMAIN',(
                SELECT resource_id
                FROM sdp_resource
                WHERE resource_name='$RESOURCE_NAME'
            )
        )"
  fi

  ##Insert Groups
  for name in "${RESOURCE_GROUP[@]}"
  do
    if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT count(*)
        FROM ugroup
        WHERE ugroup_name = '$name'"` -lt 1 ] && [ "$name" != "all_users" ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO ugroup (
            ugroup_name, ugroup_description
        ) VALUES (
            '$name','$name'
        )"
    fi
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_resource_group (
            resource_id,ugroup_id
        ) VALUES (
            (
                SELECT resource_id
                FROM sdp_resource
                WHERE resource_name='$RESOURCE_NAME'
            ),(
                SELECT ugroup_id
                FROM ugroup
                WHERE ugroup_name='$name'
            )
        )"
  done

  ##Insert Ports
  for number in "${RESOURCE_PORT[@]}"
  do
    if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT count(*) 
        FROM sdp_resource sr
          INNER JOIN sdp_resource_port AS srp ON sr.resource_id = srp.resource_id
        WHERE srp.port_number = '$number'
        AND sr.resource_name='$RESOURCE_NAME'"` -lt 1 ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_resource_port (
            port_name,port_number,port_protocol,resource_id
        ) VALUES (
            '$number','$number','tcp',(
                SELECT resource_id
                FROM sdp_resource
                WHERE resource_name='$RESOURCE_NAME'
            )
        )"
    fi
  done

  ##Gateway Association
  if [ "$GATEWAY_ADDRESS" != "DIRECT" ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_gateway_resource (
            gateway_id,resource_id
        ) VALUES (
            (
                SELECT gateway_id
                FROM gateway
                WHERE gateway_ip='$GATEWAY_ADDRESS'
            ),(
                SELECT resource_id
                FROM sdp_resource
                WHERE resource_name='$RESOURCE_NAME'
            )
        )"
  else
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        INSERT INTO sdp_gateway_resource (
            gateway_id,resource_id
        ) VALUES (
            (
                SELECT gateway_id
                FROM gateway
                WHERE gateway_ip='$GATEWAY_GATEWAY'
            ),(
                SELECT resource_id
                FROM sdp_resource
                WHERE resource_name='$RESOURCE_NAME'
            )
        )"
  fi

  ###RADIUS route rules for tcp resources
  #if [ $RESOURCE_TYPE == "tcp" ]; then
  #  for name in "${RESOURCE_GROUP[@]}"
  #  do
  #    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "
  #      INSERT INTO radgroupreply (
  #          groupname, attribute, op, value
  #      ) VALUES (
  #          '$name','Framed-Route','+=','${RESOURCE_DOMAIN}/32 ${CLIENT_GATEWAY}/32  1'
  #      )"
  #  done
  #fi
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

  #if [ $RESOURCE_TYPE == 'tcp' ]; then
  #  if [ ! -e "$OPENVPN_CLIENT_FOLDER/DEFAULT" ]; then
  #    touch $OPENVPN_CLIENT_FOLDER/DEFAULT
  #  fi
  #  echo "push \"route $RESOURCE_DOMAIN 255.255.255.255\"" >> $OPENVPN_CLIENT_FOLDER/DEFAULT
  #fi
}

function defineResource {
  RESOURCE_PORT=()
  RESOURCE_GROUP=()

  resourceGateway
  if [ $exitstatus = 0 ]; then
    resourceType
    if [ $exitstatus = 0 ]; then
      resourceDomain
      if [ $exitstatus = 0 ]; then
        resourcePorts
        if [ $exitstatus = 0 ]; then
          resourceGroups
          if [ $exitstatus = 0 ]; then
            whiptail --textbox --title "$title" --scrolltext /dev/stdin \
              16 78 <<<$(echo "\nRESOURCE DEFINITION:\n"
              echo "\nResource Name = $RESOURCE_NAME"
              echo "\nResource Type = $RESOURCE_TYPE"
              echo "\nResource Ports = ${RESOURCE_PORT[@]}"
              echo "\nResource Groups = ${RESOURCE_GROUP[@]}"
            )
          fi
        fi
      fi
    fi
  fi
}

function addResource {
  defineResource
  insertDB
  writeSquid
}

function addResourceStart {
  title="Add a New Resource"
  RESOURCE_NAME=$(
    whiptail --title "$title" --inputbox "\nEnter a name for the resource to add:" \
    8 78 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    RESOURCE_NAME="$(tr " " "_" <<<$RESOURCE_NAME)"
    checkResource
    if [ "$RESOURCE_EXISTS" -gt 0 ]; then
      if (whiptail --yesno "\"$RESOURCE_NAME\" already exists. Would you like to update instead?" \
          --title "$title" 8 78) then
        updateResource
      fi
    else
      addResource
    fi
  fi

  optionsMenu
}

function updateResource {
  whiptail --textbox --title "$title" --scrolltext /dev/stdin 25 78 <<<"$(
    echo 'Current definition of "'$RESOURCE_NAME'":\n'
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e '
        SELECT CONCAT(
            resource_name,";",
            address_domain,";",
            resource_type,";",
            GROUP_CONCAT(DISTINCT(port_number)),";",
            GROUP_CONCAT(DISTINCT(ugroup_name))
        ) "<RESOURCE NAME>;<DOMAIN/IP>;<TYPE>;<PORT>;<GROUPS>"
        FROM squid_rules_helper
        WHERE resource_name = "'$RESOURCE_NAME'"
        GROUP BY resource_name
        ORDER BY "Resource Name"
    ' | column -t -s ';' )"
  defineResource

  if [ $exitstatus = 0 ]; then
    deleteResource
    insertDB
    writeSquid
  fi
}

function updateResourceStart {
  title="Update an Existing Resource"
  getActiveResources
  RESOURCE_NAME=$(
    whiptail --title "$title" --menu "\nChoose the resource to update:" \
    25 78 16 "${activeResourcesArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    RESOURCE_NAME="$(tr " " "_" <<<$RESOURCE_NAME)"
    updateResource
  fi

  optionsMenu
}

function deleteResource {
  RESOURCE_DOMAIN=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
        SELECT sra.address_domain
        FROM sdp_resource_address sra
          INNER JOIN sdp_resource AS sr ON sra.resource_id = sr.resource_id
        WHERE sr.resource_name = '$RESOURCE_NAME'"`
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
        DELETE FROM sdp_resource
        WHERE resource_name='$RESOURCE_NAME'"
  #mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "
  #      DELETE FROM radgroupreply
  #      WHERE value LIKE '${RESOURCE_DOMAIN}%'"
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_port/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_group/d" $SQUID_ACL_CONF
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_CACHE_ACCESS
  sed -i "/\ ${RESOURCE_NAME}_domain/d" $SQUID_ACCESS
  service squid reload
}

function deleteResourceStart {
  title="Delete a Resource"
  getActiveResources
  RESOURCE_NAME=$(
    whiptail --title "$title" --menu "\nChoose the resource to delete:" \
    25 78 16 "${activeResourcesArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if (whiptail --yesno "You are about to delete $RESOURCE_NAME. Continue?" \
          --title "$title" 8 78) then
      deleteResource
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
        25 78 <<<$(echo "$RESOURCE_NAME has been deleted")
    fi
  fi

  optionsMenu
}

function optionsMenu {
  opt=$(
    whiptail --title "RESOURCE MANAGEMENT OPTIONS" --menu "\nChoose an item to continue:" \
    25 78 16 \
    "List Resources" "List configured resources." \
    "Add a Resource" "Add a new resource." \
    "Update a Resource" "Update an existing resource." \
    "Delete a Resource" "Remove a resource." \
    "Rebuild Squid Configuration" "Rebuild all squid configurations." 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    case $opt in
      "List Resources")
         listResources
         ;;
       "Add a Resource")
         addResourceStart
         ;;
       "Update a Resource")
         updateResourceStart
         ;;
       "Delete a Resource")
         deleteResourceStart
         ;;
       "Rebuild Squid Configuration")
         bash $SCRIPTS_DIR/rebuild_squid_config.sh
         ;;
    esac
  fi
}

optionsMenu

