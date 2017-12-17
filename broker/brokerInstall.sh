#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

####Information Gathering
function infoGather {
  OPENVPN_DIR=/etc/openvpn
  DB_CONFIG=$OPENVPN_DIR/scripts/config.sh
  PRIMARY_IP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
  PRIMARY_IF=`ifconfig | grep -B1 "inet addr:$PRIMARY_IP" | awk '$1!="inet" && $1!="--" {print $1}'`
  BROKER_HOSTNAME=sdp-broker
  ##Check for pre-existing configuration and create if it does not exist
  if [ ! -e "$OPENVPN_DIR/scripts" ]; then
    mkdir -p $OPENVPN_DIR/scripts
  fi
  if [ ! -e "$DB_CONFIG" ]; then
    OPENVPN_CLIENT_FOLDER=$OPENVPN_DIR/client
    OUTPUT_DIR=$OPENVPN_DIR/client-configs/files
    BASE_CONFIG=$OPENVPN_DIR/client-configs/base.conf
    BASE_WIN_FILES=$OPENVPN_DIR/client-configs/winfiles
    GATEWAY_BASE_CONFIG=$OPENVPN_DIR/gateway-configs/gatewaybase.conf
    GATEWAY_OUTPUT_DIR=/home/sdpmanagement
    OPENVPN_CLIENT_BASE=$OPENVPN_CLIENT_FOLDER/sdp-base
    touch $DB_CONFIG
    chmod +x $DB_CONFIG
    mkdir -p $OPENVPN_CLIENT_FOLDER
    mkdir -p $OUTPUT_DIR
    mkdir -p $BASE_WIN_FILES
    mkdir -p $OPENVPN_CLIENT_BASE
  else
    . $DB_CONFIG
  fi
    
  ##Prompt user for information if not already gathered
  if [ -z ${KEY_EMAIL+x} ]; then
    read -p "Choose your Admin email [Default: admin@mail.com]: " KEY_EMAIL
    KEY_EMAIL=${KEY_EMAIL:-admin@mail.com}
    echo ""
  fi
  if [ -z ${OPENVPN_RSA_DIR+x} ]; then
    #read -p "Choose your EasyRSA installation Directory [Default: /etc/openvpn/easy-rsa]: " OPENVPN_RSA_DIR
    OPENVPN_RSA_DIR=${OPENVPN_RSA_DIR:-/etc/openvpn/easy-rsa}
    OPENVPN_KEYS=$OPENVPN_RSA_DIR/keys
    echo ""
  fi
  if [ -z ${KEY_NAME+x} ]; then
    read -p "Choose a name for your Certificate Authority [Default: MyCA]: " KEY_NAME
    KEY_NAME=${KEY_NAME:-MyCA}
    echo ""
  fi
  if [ -z ${KEY_COUNTRY+x} ]; then
    read -p "Choose the country for your CA [Default: US]: " KEY_COUNTRY
    KEY_COUNTRY=${KEY_COUNTRY:-US}
    echo ""
  fi
  if [ -z ${KEY_PROVINCE+x} ]; then
    read -p "Choose the state/province for your CA [Default: NA]: " KEY_PROVINCE
    KEY_PROVINCE=${KEY_PROVINCE:-NA}
    echo ""
  fi
  if [ -z ${KEY_CITY+x} ]; then
    read -p "Choose the city for your CA [Default: None]: " KEY_CITY
    KEY_CITY=${KEY_CITY:-None}
    echo ""
  fi
  if [ -z ${KEY_ORG+x} ]; then
    read -p "Choose the Organization for your CA [Default: None]: " KEY_ORG
    KEY_ORG=${KEY_ORG:-None}
    echo ""
  fi
  if [ -z ${KEY_OU+x} ]; then
    read -p "Choose the Organizational Unit for your CA [Default: None]: " KEY_OU
    KEY_OU=${KEY_OU:-None}
    echo ""
  fi
  if [ -z ${rootDBpass+x} ] && [ ! -f /etc/mysql/debian.cnf ]; then
    NEWDATABASE=true
    read -sp "Choose a password for your database root user [Default: rootdbpass]: " rootDBpass
    rootDBpass=${rootDBpass:-rootdbpass}
    echo ""
  fi
  if [ -z ${PASS+x} ]; then
    read -sp "Choose a password for your SDP database user [Default: sdpdbpass]: " PASS
    PASS=${PASS:-sdpdbpass}
    USER='sdpuser'
    DB='sdpdb'
    HOST='127.0.0.1'
    PORT='3306'
    echo ""
  fi
  if [ -z ${CLIENT_NET+x} ]; then
    #read -p "Choose the network Subnet for the client VPN [Default: 10.255.4.0/22]: " CLIENT_NET
    CLIENT_NET=${CLIENT_NET:-10.255.4.0/22}
    CLIENT_GATEWAY=10.255.4.1
    CLIENT_BROADCAST=10.255.7.255
    CLIENT_NETWORK=10.255.4.0
    CLIENT_NETMASK=255.255.252.0
    echo ""
  fi
  if [ -z ${GATEWAY_NET+x} ]; then
    #read -p "Choose the network Subnet for the gateway VPN [Default: 10.255.8.0/24]: " GATEWAY_NET
    GATEWAY_NET=${GATEWAY_NET:-10.255.8.0/24}
    GATEWAY_GATEWAY=10.255.8.1
    GATEWAY_BROADCAST=10.255.8.255
    GATEWAY_NETWORK=10.255.8.0
    GATEWAY_NETMASK=255.255.255.0
    echo ""
  fi
  if [ -z ${CLIENT_VPN_PORT+x} ]; then
    #read -p "Choose the VPN port for the client VPN [Default: 1195]: " CLIENT_VPN_PORT
    CLIENT_VPN_PORT=${CLIENT_VPN_PORT:-1195}
    echo ""
  fi
  if [ -z ${GATEWAY_VPN_PORT+x} ]; then
    #read -p "Choose the VPN port for the gateway VPN [Default: 1194]: " GATEWAY_VPN_PORT
    GATEWAY_VPN_PORT=${GATEWAY_VPN_PORT:-1194}
    echo ""
  fi
  if [ -z ${SQUID_PORT+x} ]; then
    SQUID_PORT=3128
    echo ""
  fi
  if [ -z ${REDSOCKS_PORT+x} ]; then
    REDSOCKS_PORT=3129
    echo ""
  fi
  if [ -z ${NGINX_PORT+x} ]; then
    NGINX_PORT=80
    echo ""
  fi
}

function writeConfig {
  ##Re-Write Config File with latest info
  echo "Writing master config file"
  echo "#!/bin/bash" > $DB_CONFIG
  echo "" >> $DB_CONFIG
  echo "####Directories" >> $DB_CONFIG
  echo "OPENVPN_DIR=/etc/openvpn" >> $DB_CONFIG
  echo "DB_CONFIG=\$OPENVPN_DIR/scripts/config.sh" >> $DB_CONFIG
  echo "OPENVPN_CLIENT_FOLDER=\$OPENVPN_DIR/client" >> $DB_CONFIG
  echo "OUTPUT_DIR=\$OPENVPN_DIR/client-configs/files" >> $DB_CONFIG
  echo "BASE_CONFIG=\$OPENVPN_DIR/client-configs/base.conf" >> $DB_CONFIG
  echo "BASE_WIN_FILES=\$OPENVPN_DIR/client-configs/winfiles" >> $DB_CONFIG
  echo "OPENVPN_CLIENT_BASE=\$OPENVPN_CLIENT_FOLDER/sdp-base" >> $DB_CONFIG
  echo "GATEWAY_BASE_CONFIG=\$OPENVPN_DIR/gateway-configs/gatewaybase.conf" >> $DB_CONFIG
  echo "GATEWAY_OUTPUT_DIR=/home/sdpmanagement" >> $DB_CONFIG
  echo "" >> $DB_CONFIG
  echo "####Easy-RSA variables" >> $DB_CONFIG
  echo "KEY_EMAIL=$KEY_EMAIL" >> $DB_CONFIG
  echo "OPENVPN_RSA_DIR=$OPENVPN_RSA_DIR" >> $DB_CONFIG
  echo "OPENVPN_KEYS=\$OPENVPN_RSA_DIR/keys" >> $DB_CONFIG
  echo "KEY_NAME=$KEY_NAME" >> $DB_CONFIG
  echo "KEY_COUNTRY=$KEY_COUNTRY" >> $DB_CONFIG
  echo "KEY_PROVINCE=$KEY_PROVINCE" >> $DB_CONFIG
  echo "KEY_CITY=$KEY_CITY" >> $DB_CONFIG
  echo "KEY_ORG=$KEY_ORG" >> $DB_CONFIG
  echo "KEY_OU=$KEY_OU" >> $DB_CONFIG
  echo "" >> $DB_CONFIG
  echo "####Database Setting" >> $DB_CONFIG
  echo "HOST=$HOST" >> $DB_CONFIG
  echo "PORT=$PORT" >> $DB_CONFIG
  echo "USER=$USER" >> $DB_CONFIG
  echo "PASS=$PASS" >> $DB_CONFIG
  echo "DB=$DB" >> $DB_CONFIG
  echo "" >> $DB_CONFIG
  echo "####Network Setting" >> $DB_CONFIG
  echo "BROKER_HOSTNAME=$BROKER_HOSTNAME" >> $DB_CONFIG
  echo "PRIMARY_IP=$PRIMARY_IP" >> $DB_CONFIG
  echo "PRIMARY_IF=$PRIMARY_IF" >> $DB_CONFIG
  echo "CLIENT_NET=$CLIENT_NET" >> $DB_CONFIG
  echo "CLIENT_GATEWAY=$CLIENT_GATEWAY" >> $DB_CONFIG
  echo "CLIENT_BROADCAST=$CLIENT_BROADCAST" >> $DB_CONFIG
  echo "CLIENT_NETWORK=$CLIENT_NETWORK" >> $DB_CONFIG
  echo "CLIENT_NETMASK=$CLIENT_NETMASK" >> $DB_CONFIG
  echo "GATEWAY_NET=$GATEWAY_NET" >> $DB_CONFIG
  echo "GATEWAY_GATEWAY=$GATEWAY_GATEWAY" >> $DB_CONFIG
  echo "GATEWAY_BROADCAST=$GATEWAY_BROADCAST" >> $DB_CONFIG
  echo "GATEWAY_NETWORK=$GATEWAY_NETWORK" >> $DB_CONFIG
  echo "GATEWAY_NETMASK=$GATEWAY_NETMASK" >> $DB_CONFIG
  echo "CLIENT_VPN_PORT=$CLIENT_VPN_PORT" >> $DB_CONFIG
  echo "GATEWAY_VPN_PORT=$GATEWAY_VPN_PORT" >> $DB_CONFIG
  echo "SQUID_PORT=$SQUID_PORT" >> $DB_CONFIG
  echo "REDSOCKS_PORT=$REDSOCKS_PORT" >> $DB_CONFIG
  echo "NGINX_PORT=$NGINX_PORT" >> $DB_CONFIG
}

####Install required Packages
function installPackages {
  echo "Installing packages"
  apt-get update
  apt-get install -y software-properties-common
  ## Add fwknop PPA repo
  add-apt-repository ppa:cipherdyne/fwknop -y
  ## Add mariadb repo
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'
  export DEBIAN_FRONTEND="noninteractive"
  apt-get update
  apt install -y mariadb-server fwknop-server fwknop-client fwknop-apparmor-profile openvpn easy-rsa nginx squid zip unzip mutt redsocks postfix jq php-fpm php-mysql
}

####Configure Mariadb Installation
function configureDatabase {
  echo "Configuring Database"
  if [ "$NEWDATABASE" == "true" ]; then
    ## Equivalent of mysql_secure_installation
    ## Special thanks: http://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
    mysqladmin password "$rootDBpass"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User=''"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    mysql -u root -p$rootDBpass -e "DROP DATABASE IF EXISTS test"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
    mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
    if [ ! -e "/etc/mysql/my.cnf.orig" ]; then
      mv /etc/mysql/my.cnf /etc/mysql/my.cnf.orig
      cp $DIR/mariadbconf/my.cnf /etc/mysql/my.cnf
    fi
  fi
  if [ ! -e "/etc/mysql/mariadb.conf.d/50-server.cnf" ]; then
    ## Put small memory server configs in place
    MEMTOTAL=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
    if [ $MEMTOTAL -lt 1000000 ] ; then
      cp $DIR/mariadbconf/50-server.cnf /etc/mysql/mariadb.conf.d/
      ## Restart database
      service mysql restart
    fi
  fi  
  ## Create OpenVPN database user
  if [ "$NEWDATABASE" == "true" ]; then
    mysql -u root -p$rootDBpass -e "CREATE DATABASE IF NOT EXISTS $DB"
    mysql -u root -p$rootDBpass -e "CREATE USER IF NOT EXISTS $USER@'%' IDENTIFIED BY '${PASS}'"
    mysql -u root -p$rootDBpass -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'%'"
    mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  fi
  ## Source in OpenVPN database
  ## Special thanks: https://sysadmin.compxtreme.ro/how-to-install-a-openvpn-system-based-on-userpassword-authentication-with-mysql-day-control-libpam-mysql/
  mysql -u $USER -p$PASS $DB < $DIR/mariadbconf/sdp.sql
  if [ "$NEWDATABASE" == "true" ]; then
    mysql -u $USER -p$PASS $DB < $DIR/mariadbconf/sampledata.sql
  fi
  ## Put default user file in place
  #if [ ! -e "/etc/mysql/mariadb.conf.d/50-client.cnf" ]; then
  #  cp $DIR/mariadbconf/50-client.cnf /etc/mysql/mariadb.conf.d/
  #  sed -i "s/user\=.*/user\=$USER/" /etc/mysql/mariadb.conf.d/50-client.cnf
  #  sed -i "s/password\=.*/password\=$PASS/" /etc/mysql/mariadb.conf.d/50-client.cnf
  #fi
}

####Configure Firewall Rules
function configureFirewall {
  echo "Configuring Firewall"
  FWCONFIG=/etc/ufw/before.rules
  FWRULESEXIST=`grep -c REDSOCKS $FWCONFIG`
  if [ $FWRULESEXIST -lt 1 ]; then
    echo "" >> $FWCONFIG
    echo "##Redsocks Proxy Rules" >> $FWCONFIG
    echo "*nat" >> $FWCONFIG
    echo ":PREROUTING ACCEPT [0:0]" >> $FWCONFIG
    echo ":REDSOCKS - [0:0]" >> $FWCONFIG
    echo "-A PREROUTING -s $CLIENT_NET -p tcp -j REDSOCKS" >> $FWCONFIG
    echo "-A REDSOCKS -s $CLIENT_NET -p tcp --dport $NGINX_PORT -j RETURN" >> $FWCONFIG
    echo "-A REDSOCKS -s $CLIENT_NET -p tcp --dport $SQUID_PORT -j RETURN" >> $FWCONFIG
    echo "-A REDSOCKS -s $CLIENT_NET -p tcp -j REDIRECT --to-ports $REDSOCKS_PORT" >> $FWCONFIG
    echo "COMMIT" >> $FWCONFIG
    echo "##End Redsocks Proxy Rules" >> $FWCONFIG
  fi
  ##UFW rules
  ufw allow from $CLIENT_NET to any port $NGINX_PORT proto tcp
  ufw allow from $CLIENT_NET to any port $SQUID_PORT proto tcp
  ufw allow from $CLIENT_NET to any port $REDSOCKS_PORT proto tcp
  ufw allow from $GATEWAY_NET to any port 3306 proto tcp
  ##These will be removed with the lockdown script once everything has been confirmed
  ufw allow 22/tcp
  ufw allow ${CLIENT_VPN_PORT}/udp
  ufw --force enable
}

####Configure fwknop
function configureFwknop {
  echo "Configuring fwknop"
  if [ ! -e "/var/fwknop" ]; then
    mkdir /var/fwknop
  fi 
  ## Create Keys
  FWKNOP_DIR=/etc/fwknop
  FWKNOP_KEYS=$FWKNOP_DIR/fwknop_keys.conf
  FWKNOP_ACCESS=$FWKNOP_DIR/access.conf
  FWKNOP_FWKNOPD=$FWKNOP_DIR/fwknopd.conf
  ## Make Backups of default config files
  if [ ! -e "${FWKNOP_ACCESS}.orig" ]; then
    mv $FWKNOP_ACCESS ${FWKNOP_ACCESS}.orig
  fi
  if [ ! -e "${FWKNOP_FWKNOPD}.orig" ]; then
    mv $FWKNOP_FWKNOPD ${FWKNOP_FWKNOPD}.orig
  fi
  ## Create access.conf
  if [ ! -e "$FWKNOP_KEYS" ]; then
    fwknop --key-gen --key-gen-file $FWKNOP_KEYS
  fi
  FWKNOP_HMAC=`grep HMAC_KEY_BASE64 $FWKNOP_KEYS | awk '{print $2}'`
  FWKNOP_RIJNDAEL=`grep KEY_BASE64 $FWKNOP_KEYS | grep -v HMAC | awk '{print $2}'`
  echo "OPEN_PORTS    udp/${CLIENT_VPN_PORT},udp/${GATEWAY_VPN_PORT},tcp/22" > $FWKNOP_ACCESS
  echo "FW_ACCESS_TIMEOUT    10" >> $FWKNOP_ACCESS
  echo "" >> $FWKNOP_ACCESS
  echo "SOURCE    ANY" >> $FWKNOP_ACCESS
  echo "KEY_BASE64    $FWKNOP_RIJNDAEL" >> $FWKNOP_ACCESS
  echo "HMAC_KEY_BASE64    $FWKNOP_HMAC" >> $FWKNOP_ACCESS
  chmod 600 $FWKNOP_ACCESS
  ## Create fwknopd.conf
  echo "PCAP_INTF    ${PRIMARY_IF};" > $FWKNOP_FWKNOPD
  echo "MAX_SPA_PACKET_AGE    30;" >> $FWKNOP_FWKNOPD
  chmod 600 $FWKNOP_FWKNOPD
  ## Update default config so fwknop can run as a daemon
  sed -i "s/START_DAEMON\=.*/START_DAEMON\=\"yes\"/" /etc/default/fwknop-server
  ## Fix apparmor permissions
  if [ -e "/etc/apparmor.d/usr.sbin.fwknopd" ]; then
    if [ `grep -c -e 'network inet6 dgram,' /etc/apparmor.d/usr.sbin.fwknopd` -lt 1 ]; then
      sed -i "s/\}//" /etc/apparmor.d/usr.sbin.fwknopd
      echo "  /run/xtables.lock rwk,
  network inet dgram,
  network inet6 dgram,
}" >> /etc/apparmor.d/usr.sbin.fwknopd
      service apparmor restart
    fi
  fi
  ## Restart fwknop
  service fwknop-server restart
}

##Generate initial set of certs if a ca is not already present
function configureEasyrsa {
  echo "Configuring EasyRSA"
  if [ ! -e "$OPENVPN_RSA_DIR" ]; then
    make-cadir $OPENVPN_RSA_DIR
    cd $OPENVPN_RSA_DIR
    sed -i 's/\-\-interact/\-\-batch/' build-ca
    sed -i 's/\-\-interact/\-\-batch/' build-key-server
    sed -i "s/export KEY\_COUNTRY\=.*/export KEY\_COUNTRY\="$KEY_COUNTRY"/" vars
    sed -i "s/export KEY\_PROVINCE\=.*/export KEY\_PROVINCE\="$KEY_PROVINCE"/" vars
    sed -i "s/export KEY\_CITY\=.*/export KEY\_CITY\="$KEY_CITY"/" vars
    sed -i "s/export KEY\_ORG\=.*/export KEY\_ORG\="$KEY_ORG"/" vars
    sed -i "s/export KEY\_EMAIL\=.*/export KEY\_EMAIL\="$KEY_EMAIL"/" vars
    sed -i "s/export KEY\_OU\=.*/export KEY\_OU\="$KEY_OU"/" vars
    sed -i "s/export KEY\_NAME\=.*/export KEY\_NAME\="$KEY_NAME"/" vars
    source vars
    ./clean-all
    ./build-ca
    ./build-dh
    ./build-key-server $BROKER_HOSTNAME
    openvpn --genkey --secret $OPENVPN_KEYS/ta.key
    ## Create and revoke one certificate so that the CRL file is created
    sed -i 's/\-\-interact/\-\-batch/' build-key
    ./build-key revokeme
    ./revoke-full revokeme
  else
    echo "CA Directory already exists.  Moving on."
  fi
}

function configureOpenvpn {
  echo "Configuring OpenVPN"
  cp $DIR/openvpn/scripts/up.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/down.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/connect.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/disconnect.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/gw_up.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/gw_down.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/gw_connect.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/gw_disconnect.sh $OPENVPN_DIR/scripts/
  chmod +x $OPENVPN_DIR/scripts/*.sh
  mkdir -p $OPENVPN_DIR/client
  touch $OPENVPN_DIR/client_vpn-status.log
  touch $OPENVPN_DIR/client_vpn_ipp.txt
  cp $DIR/openvpn/client_vpn.conf $OPENVPN_DIR/
  touch $OPENVPN_DIR/gateway_vpn-status.log
  cp $DIR/openvpn/gateway_vpn.conf $OPENVPN_DIR/
  ## Set Client VPN Configs
  sed -i "s@port\ .*@port\ $CLIENT_VPN_PORT@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@ca\ .*@ca\ $OPENVPN_KEYS\/ca\.crt@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@crl\-verify\ .*@crl\-verify\ $OPENVPN_KEYS\/crl\.pem@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@cert\ .*@cert\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.crt@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@key\ .*@key\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.key@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@dh\ .*@dh\ $OPENVPN_KEYS\/dh2048\.pem@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@tls\-auth\ .*@tls\-auth\ $OPENVPN_KEYS\/ta\.key\ 0@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@server\ .*@server\ $CLIENT_NETWORK\ $CLIENT_NETMASK@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@client\-config\-dir\ .*@client\-config\-dir\ $OPENVPN_CLIENT_FOLDER@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@ifconfig\-pool\-persist\ .*@ifconfig\-pool\-persist\ $OPENVPN_DIR\/client_vpn_ipp.txt 60@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@status\ .*@status\ $OPENVPN_DIR\/client\_vpn\-status\.log@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@up\ .*@up\ $OPENVPN_DIR\/scripts\/up\.sh@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@down\ .*@down\ $OPENVPN_DIR\/scripts\/down\.sh@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@client\-connect\ .*@client\-connect\ $OPENVPN_DIR\/scripts\/connect\.sh@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@client\-disconnect\ .*@client\-disconnect\ $OPENVPN_DIR\/scripts\/disconnect\.sh@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@push\ \"dhcp-option\ PROXY\_AUTO\_CONFIG\_URL\ .*@push\ \"dhcp\-option\ PROXY\_AUTO\_CONFIG\_URL\ http\:\/\/$CLIENT_GATEWAY\/sdp\_pac\.php\"@" $OPENVPN_DIR/client_vpn.conf
  ## Set Gateway VPN Configs
  sed -i "s@port\ .*@port\ $GATEWAY_VPN_PORT@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@ca\ .*@ca\ $OPENVPN_KEYS\/ca\.crt@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@crl\-verify\ .*@crl\-verify\ $OPENVPN_KEYS\/crl\.pem@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@cert\ .*@cert\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.crt@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@key\ .*@key\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.key@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@dh\ .*@dh\ $OPENVPN_KEYS\/dh2048\.pem@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@tls\-auth\ .*@tls\-auth\ $OPENVPN_KEYS\/ta\.key\ 0@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@server\ .*@server\ $GATEWAY_NETWORK\ $GATEWAY_NETMASK@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@client\-config\-dir\ .*@client\-config\-dir\ $OPENVPN_CLIENT_FOLDER@" $OPENVPN_DIR/client_vpn.conf
  sed -i "s@status\ .*@status\ $OPENVPN_DIR\/gateway\_vpn\-status\.log@" $OPENVPN_DIR/gateway_vpn.conf
  ## Add entry for broker into the OpenVPN database
  if [ `mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) from gateway where gateway_ip='$GATEWAY_GATEWAY'"` -lt 1 ]; then
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into gateway (gateway_name,gateway_ip,gateway_proxy_port,gateway_start_date,gateway_end_date) values ('$BROKER_HOSTNAME', '$GATEWAY_GATEWAY','$SQUID_PORT',now(), now() + INTERVAL 50 year)"
  fi
  ## Configure Services to start
  service openvpn stop
  systemctl disable openvpn
  systemctl enable openvpn@client_vpn
  systemctl enable openvpn@gateway_vpn
  service openvpn@client_vpn restart
  service openvpn@gateway_vpn restart
}

function installClientManagement {
  echo "Putting Client Management in Place"
  if [ ! -e $OPENVPN_DIR/client-configs ]; then
    mkdir $OPENVPN_DIR/client-configs
    mkdir $OUTPUT_DIR
    mkdir $BASE_WIN_FILES
  fi
  cp $DIR/openvpn/client-configs/base.conf $OPENVPN_DIR/client-configs/
  cp $DIR/openvpn/client-configs/winfiles/* $BASE_WIN_FILES/
  cp $DIR/openvpn/scripts/manage_clients.sh $OPENVPN_DIR/scripts/
  chmod +x $OPENVPN_DIR/scripts/manage_clients.sh
  sed -i "s/verify\-x509\-name\ .*/verify\-x509\-name\ \'C\=$KEY_COUNTRY\,\ ST\=$KEY_PROVINCE\,\ L\=KEY_CITY\,\ O\=$KEY_ORG\,\ OU\=$KEY_OU\,\ CN\=$BROKER_HOSTNAME\,\ name\=$KEY_NAME\,\ emailAddress\=$KEY_EMAIL'/" $BASE_CONFIG
  sed -i "s/remote\ .*/remote\ $PRIMARY_IP\ $CLIENT_VPN_PORT/" $BASE_CONFIG
  wget http://www.dstuart.org/fwknop/fwknop-2.6.9-w81.exe -O $BASE_WIN_FILES/fwknop.exe
  wget http://www.dstuart.org/fwknop/libfko.dll-2.6.9-w81 -O $BASE_WIN_FILES/libfko.dll
  FWKNOP_KEYS=$FWKNOP_DIR/fwknop_keys.conf
  FWKNOP_HMAC=`grep HMAC_KEY_BASE64 /etc/fwknop/fwknop_keys.conf | awk '{print $2}'`
  FWKNOP_RIJNDAEL=`grep KEY_BASE64 /etc/fwknop/fwknop_keys.conf | grep -v HMAC | awk '{print $2}'`
  sed -i "s@fwknop\.exe.*@fwknop\.exe\ \-A\ udp\/$CLIENT_VPN_PORT\ \-\-use\-hmac\ \-D\ $PRIMARY_IP\ \-s\ \-\-key\-base64\-hmac\=$FWKNOP_HMAC\ \-\-key\-base64\-rijndael\=$FWKNOP_RIJNDAEL@" $BASE_WIN_FILES/sdp-client_pre.bat
}

function installGatewayManagement {
  echo "Putting Gateway Management in Place"
  if [ ! -e $OPENVPN_DIR/gateway-configs ]; then
    mkdir $OPENVPN_DIR/gateway-configs
  fi
  cp $DIR/openvpn/gateway-configs/gatewaybase.conf $OPENVPN_DIR/gateway-configs/
  cp $DIR/openvpn/scripts/manage_gateways.sh $OPENVPN_DIR/scripts/
  chmod +x $OPENVPN_DIR/scripts/manage_gateways.sh
  sed -i "s/verify\-x509\-name\ .*/verify\-x509\-name\ \'C\=$KEY_COUNTRY\,\ ST\=$KEY_PROVINCE\,\ L\=$KEY_CITY\,\ O\=$KEY_ORG\,\ OU\=$KEY_OU\,\ CN\=$BROKER_HOSTNAME\,\ name\=$KEY_NAME\,\ emailAddress\=$KEY_EMAIL'/" $GATEWAY_BASE_CONFIG
  sed -i "s/remote\ .*/remote\ $PRIMARY_IP\ $GATEWAY_VPN_PORT/" $GATEWAY_BASE_CONFIG
}

function configureSquid {
  echo "Configuring Squid"
  SQUIDCONF=/etc/squid/squid.conf
  if [ ! -e ${SQUIDCONF}.orig ]; then
    mv $SQUIDCONF ${SQUIDCONF}.orig
  fi
  cp $DIR/squid/squid.conf $SQUIDCONF
  cp $DIR/squid/get_user_role_db.sh /etc/squid/get_user_role_db.sh
  chmod +x /etc/squid/get_user_role_db.sh
  sed -i "s@http\_port\ .*@http\_port\ $SQUID_PORT@" $SQUIDCONF 
  if [ ! -e ${SQUIDCONF}.d ]; then
    mkdir ${SQUIDCONF}.d
  fi
  if [ ! -e ${SQUIDCONF}.d/acl_sdp.conf ]; then
    touch ${SQUIDCONF}.d/acl_sdp.conf
  fi
  if [ ! -e ${SQUIDCONF}.d/acl_sdp_clients.conf ]; then
    touch ${SQUIDCONF}.d/acl_sdp_clients.conf
  fi
  echo "acl sdp_clients src $CLIENT_NET" > ${SQUIDCONF}.d/acl_sdp_clients.conf
  if [ ! -e ${SQUIDCONF}.d/cache_peers.conf ]; then
    touch ${SQUIDCONF}.d/cache_peers.conf
  fi
  if [ ! -e ${SQUIDCONF}.d/never_direct.conf ]; then
    touch ${SQUIDCONF}.d/never_direct.conf
  fi
  if [ ! -e ${SQUIDCONF}.d/cache_peer_deny.conf ]; then
    touch ${SQUIDCONF}.d/cache_peer_deny.conf
  fi
  if [ ! -e ${SQUIDCONF}.d/http_access.conf ]; then
    touch  ${SQUIDCONF}.d/http_access.conf
  fi
  echo "Restarting Squid. This usually takes a few seconds."
  service squid restart
}

function configureNginx {
  ## Put nginx configuration in place
  NGINX_DIR=/etc/nginx
  NGINX_ENABLED=$NGINX_DIR/sites-enabled
  NGINX_AVAIL=$NGINX_DIR/sites-available
  if [ -e $NGINX_ENABLED/default ]; then
    rm -f /etc/nginx/sites-enabled/default
  fi
  cp $DIR/nginx/sdp.conf $NGINX_AVAIL/sdp.conf
  if [ ! -e $NGINX_ENABLED/sdp.conf ]; then
    ln -s $NGINX_AVAIL/sdp.conf $NGINX_ENABLED/sdp.conf
  fi
  ## Put PAC script in place
  PAC_DIR=/var/www/html
  cp $DIR/nginx/sdp_pac.php $PAC_DIR/sdp_pac.php
  sed -i "s@\$servername =.*@\$servername = \"$HOST\";@" $PAC_DIR/sdp_pac.php
  sed -i "s@\$username =.*@\$username = \"$USER\";@" $PAC_DIR/sdp_pac.php
  sed -i "s@\$password =.*@\$password = \"$PASS\";@" $PAC_DIR/sdp_pac.php
  sed -i "s@\$dbname =.*@\$dbname = \"$DB\";@" $PAC_DIR/sdp_pac.php
  sed -i "s/return\ \"PROXY\ .*/return\ \"PROXY\ $CLIENT_GATEWAY\:$SQUID_PORT\"\;/" $PAC_DIR/sdp_pac.php
  ## Restart Nginx service
  service php7.0-fpm restart
  service nginx restart
}

function configureRedsocks {
  echo "Configuring Redsocks"
  REDSOCKSVERSION=`dpkg -l redsocks | grep redsocks | awk '{print $3}' | sed 's/\+.*//' | sed 's/\-.*//'`
  if [ "$REDSOCKSVERSION" == "0.4" ]; then
    wget http://archive.ubuntu.com/ubuntu/pool/universe/r/redsocks/redsocks_0.5-1_amd64.deb
    echo "Installing updated redsocks via dpkg. The ouput will probably have a dpkg error."
    dpkg -i redsocks_0.5-1_amd64.deb
    echo "Fixing dpkg error via apt-get"
    apt-get -f install -y
  fi
  REDSOCKSCONF=/etc/redsocks.conf
  if [ ! -e "${REDSOCKSCONF}.orig" ]; then
    mv $REDSOCKSCONF ${REDSOCKSCONF}.orig
  fi
  cp $DIR/redsocks/redsocks.conf $REDSOCKSCONF  
  sed -i "s@ip\ .*@ip\ \=\ ${CLIENT_GATEWAY}\;@" $REDSOCKSCONF
  sed -i "s@port\ .*@port\ \=\ ${SQUID_PORT}\;@" $REDSOCKSCONF
  sed -i "s@local\_ip\ .*@local\_ip\ \=\ 0\.0\.0\.0\;@" $REDSOCKSCONF
  sed -i "s@local\_port\ .*@local\_port\ \=\ ${REDSOCKS_PORT}\;@" $REDSOCKSCONF
  service redsocks restart
}

function createManagementUser {
  if [ `grep -c sdpmanagement /etc/passwd` -lt '1' ]; then
    echo "Creating Management User"
    SDP_MANAGE_HOME=/home/sdpmanagement
    groupadd sdpmanagement
    useradd sdpmanagement -g sdpmanagement -s /bin/bash -p '*' -N -d $SDP_MANAGE_HOME -m
    mkdir -p $SDP_MANAGE_HOME/.ssh
    ssh-keygen -b 2048 -t rsa -f $SDP_MANAGE_HOME/.ssh/id_rsa -q -N ""
    cat $SDP_MANAGE_HOME/.ssh/id_rsa.pub >> $SDP_MANAGE_HOME/.ssh/authorized_keys
    chown sdpmanagement:sdpmanagement -R $SDP_MANAGE_HOME
  fi
}

### Execute order
infoGather
installPackages
writeConfig
configureDatabase
configureFirewall
configureFwknop
configureEasyrsa
configureOpenvpn
installClientManagement
installGatewayManagement
configureSquid
configureNginx
configureRedsocks
createManagementUser

echo ""
echo "Broker Configuration is now complete!!"

function stage_gateway_now {
  read -p "Choose a gateway hostname [Default: gateway1]: " GW_HOSTNAME
  GW_HOSTNAME=${GW_HOSTNAME:-gateway1}
  bash $OPENVPN_DIR/scripts/manage_gateways.sh $GW_HOSTNAME
}

echo ""
read -r -p "Would you like to configure a new Gateway? [Y/n] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        stage_gateway_now
        ;;
    *)
        echo ""
        ;;
esac

echo ""
echo "Configuration is now complete!  Goodbye!"
