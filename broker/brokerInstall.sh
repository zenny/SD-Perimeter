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
    OPENVPN_CLIENT_BASE=$OPENVPN_CLIENT_FOLDER/sdp-base
    touch $DB_CONFIG
    chmod +x $DB_CONFIG
    mkdir -p $OPENVPN_CLIENT_FOLDER
    mkdir -p $OUTPUT_DIR
    mkdir -p $BASE_WIN_FILES
    mkdir -p $OPENVPN_CLIENT_BASE
  fi
  . $DB_CONFIG
    
  ##Prompt user for information if not already gathered
  if [ -z ${KEY_EMAIL+x} ]; then
    read -p "Choose your Admin email [Default: admin@mail.com]: " KEY_EMAIL
    KEY_EMAIL=${KEY_EMAIL:-admin@mail.com}
    echo ""
  fi
  if [ -z ${OPENVPN_RSA_DIR+x} ]; then
    read -p "Choose your EasyRSA installation Directory [Default: /etc/openvpn/easy-rsa]: " OPENVPN_RSA_DIR
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
  if [ -z ${rootDBpass+x} ] && [ ! -f /etc/mysql/debian.conf ]; then
    NEWDATABASE=true
    read -sp "Choose a password for your database root user [Default: rootdbpass]: " rootDBpass
    rootDBpass=${rootDBpass:-rootdbpass}
    echo ""
  fi
  if [ -z ${PASS+x} ]; then
    read -sp "Choose a password for your OpenVPN database user [Default: ovpnpass]: " PASS
    PASS=${PASS:-ovpnpass}
    USER='openvpn'
    DB='openvpn'
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
    read -p "Choose the VPN port for the client VPN [Default: 1195]: " CLIENT_VPN_PORT
    CLIENT_VPN_PORT=${CLIENT_VPN_PORT:-1195}
    echo ""
  fi
  if [ -z ${GATEWAY_VPN_PORT+x} ]; then
    read -p "Choose the VPN port for the gateway VPN [Default: 1194]: " GATEWAY_VPN_PORT
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
  apt-get update
  apt-get install -y software-properties-common
  ## Add fwknop PPA repo
  add-apt-repository ppa:cipherdyne/fwknop -y
  ## Add mariadb repo
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'
  export DEBIAN_FRONTEND="noninteractive"
  apt-get update
  apt install -y mariadb-server fwknop-server fwknop-client openvpn easy-rsa nginx squid zip unzip mutt redsocks postfix
}

####Configure Mariadb Installation
function configureDatabase {
  if [ "$NEWDATABASE" == "true" ]; then
    ## Equivalent of mysql_secure_installation
    ## Special thanks: http://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
    mysqladmin password "$rootDBpass"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User=''"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    mysql -u root -p$rootDBpass -e "DROP DATABASE IF EXISTS test"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
    mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
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
  mysql -u root -p$rootDBpass -e "CREATE DATABASE IF NOT EXISTS $DB"
  mysql -u root -p$rootDBpass -e "CREATE USER $USER@'%' IDENTIFIED BY '${PASS}'"
  mysql -u root -p$rootDBpass -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'%'"
  mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  ## Source in OpenVPN database
  ## Special thanks: https://sysadmin.compxtreme.ro/how-to-install-a-openvpn-system-based-on-userpassword-authentication-with-mysql-day-control-libpam-mysql/
  mysql -u $USER -p$PASS $DB < $DIR/mariadbconf/openvpn.sql
  ## Put default user file in place
  #if [ ! -e "/etc/mysql/mariadb.conf.d/50-client.cnf" ]; then
  #  cp $DIR/mariadbconf/50-client.cnf /etc/mysql/mariadb.conf.d/
  #  sed -i "s/user\=.*/user\=$USER/" /etc/mysql/mariadb.conf.d/50-client.cnf
  #  sed -i "s/password\=.*/password\=$PASS/" /etc/mysql/mariadb.conf.d/50-client.cnf
  #fi
}

####Configure Firewall Rules
function configureFirewall {
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
  ##These will be removed with the lockdown script once everything has been confirmed
  ufw allow 22/tcp
  ufw allow ${CLIENT_VPN_PORT}/udp
  ufw allow ${GATEWAY_VPN_PORT}/udp
  ufw --force enable
}

####Configure fwknop
function configureFwknop {
  ## Create Keys
  FWKNOP_DIR=/etc/fwknop
  FWKNOP_KEYS=$FWKNOP_DIR/fwknop_keys.conf
  FWKNOP_ACCESS=$FWKNOP_DIR/access.conf
  FWKNOP_FWKNOPD=$FWKNOP_DIR/fwknopd.conf
  fwknop --key-gen --key-gen-file $FWKNOP_KEYS
  FWKNOP_HMAC=`grep HMAC_KEY_BASE64 /etc/fwknop/fwknop_keys.conf | awk '{print $2}'`
  FWKNOP_RIJNDAEL=`grep KEY_BASE64 /etc/fwknop/fwknop_keys.conf | grep -v HMAC | awk '{print $2}'`
  ## Make Backups of default config files
  if [ ! -e "${FWKNOP_ACCESS}.orig" ]; then
    mv $FWKNOP_ACCESS ${FWKNOP_ACCESS}.orig
  fi
  if [ ! -e "${FWKNOP_FWKNOPD}.orig" ]; then
    mv $FWKNOP_FWKNOPD ${FWKNOP_FWKNOPD}.orig
  fi
  ## Create access.conf
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
  ## Restart fwknop
  service fwknop-server restart
}

##Generate initial set of certs if a ca is not already present
function configureEasyrsa {
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
  ##Lay Down Config Files
  cp $DIR/openvpn/scripts/up.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/down.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/connect.sh $OPENVPN_DIR/scripts/
  cp $DIR/openvpn/scripts/disconnect.sh $OPENVPN_DIR/scripts/
  chmod +x $OPENVPN_DIR/scripts/*.sh
  mkdir -p $OPENVPN_DIR/client
  touch $OPENVPN_DIR/client_vpn-status.log
  touch $OPENVPN_DIR/client_vpn_ipp.txt
  if [ ! -e "$OPENVPN_DIR/client_vpn.conf" ]; then
    cp $DIR/openvpn/client_vpn.conf $OPENVPN_DIR/
  fi
  touch $OPENVPN_DIR/gateway_vpn-status.log
  if [ ! -e "$OPENVPN_DIR/gateway_vpn.conf" ]; then
    cp $DIR/openvpn/gateway_vpn.conf $OPENVPN_DIR/
  fi
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
  sed -i "s@port\ .*@port\ $GATEWAY_VPN_PORT@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@ca\ .*@ca\ $OPENVPN_KEYS\/ca\.crt@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@crl\-verify\ .*@crl\-verify\ $OPENVPN_KEYS\/crl\.pem@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@cert\ .*@cert\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.crt@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@key\ .*@key\ $OPENVPN_KEYS\/$BROKER_HOSTNAME\.key@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@dh\ .*@dh\ $OPENVPN_KEYS\/dh2048\.pem@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@tls\-auth\ .*@tls\-auth\ $OPENVPN_KEYS\/ta\.key\ 0@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@server\ .*@server\ $GATEWAY_NETWORK\ $GATEWAY_NETMASK@" $OPENVPN_DIR/gateway_vpn.conf
  sed -i "s@status\ .*@status\ $OPENVPN_DIR\/gateway\_vpn\-status\.log@" $OPENVPN_DIR/gateway_vpn.conf
  ## Configure Services to start
  service openvpn stop
  systemctl disable openvpn
  systemctl enable openvpn@client_vpn
  systemctl enable openvpn@gateway_vpn
  service openvpn@client_vpn restart
  service openvpn@gateway_vpn restart
}

function installClientManagement {
  echo ""
}

function configureSquid {
  echo ""
}

function configureRedsocks {
  echo ""
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
configureSquid
configureRedsocks

echo ""
echo "Configuration is now complete!!"
echo "Next, go configure your gateway"
