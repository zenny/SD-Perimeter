#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

####Information Gathering
function infoGather {
  OPENVPN_DIR=/etc/openvpn
  DB_CONFIG=$OPENVPN_DIR/scripts/config.sh
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
    read -p "Choose your Admin email [Default: admin@mail.com]" KEY_EMAIL
    KEY_EMAIL=${KEY_EMAIL:-admin@mail.com}
    echo ""
  fi
  if [ -z ${OPENVPN_RSA_DIR+x} ]; then
    read -p "Choose your EasyRSA installation Directory [Default: /etc/openvpn/easy-rsa]" OPENVPN_RSA_DIR
    OPENVPN_RSA_DIR=${OPENVPN_RSA_DIR:-/etc/openvpn/easy-rsa}
    OPENVPN_KEYS=$OPENVPN_RSA_DIR/keys
    echo ""
  fi
  if [ -z ${KEY_NAME+x} ]; then
    read -p "Choose a name for your Certificate Authority [Default: MyCA]" KEY_NAME
    KEY_NAME=${KEY_NAME:-MyCA}
    echo ""
  fi
  if [ -z ${KEY_COUNTRY+x} ]; then
    read -p "Choose the country for your CA [Default: US]" KEY_COUNTRY
    KEY_COUNTRY=${KEY_COUNTRY:-US}
    echo ""
  fi
  if [ -z ${KEY_PROVINCE+x} ]; then
    read -p "Choose the state/province for your CA [Default: NA]" KEY_PROVINCE
    KEY_PROVINCE=${KEY_PROVINCE:-NA}
    echo ""
  fi
  if [ -z ${KEY_CITY+x} ]; then
    read -p "Choose the city for your CA [Default: None]" KEY_CITY
    KEY_CITY=${KEY_CITY:-None}
    echo ""
  fi
  if [ -z ${KEY_ORG+x} ]; then
    read -p "Choose the Orgonization for your CA [Default: None]" KEY_ORG
    KEY_ORG=${KEY_ORG:-None}
    echo ""
  fi
  if [ -z ${KEY_OU+x} ]; then
    read -p "Choose the Organizational Unit for your CA [Default: None]" KEY_OU
    KEY_OU=${KEY_OU:-None}
    echo ""
  fi
  if [ -z ${rootDBpass+x} && ! -f /etc/mysql/debian.conf ]; then
    read -sp "Choose a password for your database root user [Default: rootdbpass]" rootDBpass
    rootDBpass=${rootDBpass:-rootdbpass}
    echo ""
  fi
  if [ -z ${PASS+x} ]; then
    read -sp "Choose a password for your OpenVPN database user [Default: ovpnpass]" PASS
    PASS=${PASS:-ovpnpass}
    USER='openvpn'
    DB='openvpn'
    HOST='127.0.0.1'
    PORT='3306'
    echo ""
  fi
  if [ -z ${CLIENT_NET+x} ]; then
    read -p "Choose the network Subnet for the client VPN [Default: 10.255.4.0/22]" CLIENT_NET
    CLIENT_NET=${CLIENT_NET:-10.255.4.0/22}
    echo ""
  fi
  if [ -z ${GATEWAY_NET+x} ]; then
    read -p "Choose the network Subnet for the gateway VPN [Default: 10.255.8.0/24]" GATEWAY_NET
    GATEWAY_NET=${GATEWAY_NET:-10.255.8.0/24}
    echo ""
  fi
  if [ -z ${CLIENT_VPN_PORT+x} ]; then
    read -p "Choose the VPN port for the client VPN [Default: 1195]" CLIENT_VPN_PORT
    CLIENT_VPN_PORT=${CLIENT_VPN_PORT:-1195}
    echo ""
  fi
  if [ -z ${GATEWAY_VPN_PORT+x} ]; then
    read -p "Choose the VPN port for the gateway VPN [Default: 1194]" GATEWAY_VPN_PORT
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
  echo "CLIENT_NET=$CLIENT_NET" >> $DB_CONFIG
  echo "GATEWAY_NET=$GATEWAY_NET" >> $DB_CONFIG
  echo "CLIENT_VPN_PORT=$CLIENT_VPN_PORT" >> $DB_CONFIG
  echo "GATEWAY_VPN_PORT=$GATEWAY_VPN_PORT" >> $DB_CONFIG
  echo "SQUID_PORT=$SQUID_PORT" >> $DB_CONFIG
  echo "REDSOCKS_PORT=$REDSOCKS_PORT" >> $DB_CONFIG
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
  apt install -y mariadb-server fwknop-server fwknop-client squid zip unzip mutt redsocks postfix
}

####Configure Mariadb Installation
function configureDatabase {
  DBPASSWDCOUNT=`grep -c password /etc/mysql/debian.cnf`
  if [ $DBPASSWDCOUNT -lt 1 ]; then
    ## Equivalent of mysql_secure_installation
    ## Special thanks: http://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
    mysqladmin password "$rootDBpass"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User=''"
    mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    mysql -u root -p$rootDBpass -e "DROP DATABASE test"
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
  if [ ! -e "/var/lib/mysql/$DB" ]; then
    mysql -u root -p$rootDBpass -e "CREATE DATABASE $DB"
    mysql -u root -p$rootDBpass -e "CREATE USER $USER@'%' IDENTIFIED BY '${PASS}'"
    mysql -u root -p$rootDBpass -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'%'"
    mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  fi
  ## Source in OpenVPN database
  ## Special thanks: https://sysadmin.compxtreme.ro/how-to-install-a-openvpn-system-based-on-userpassword-authentication-with-mysql-day-control-libpam-mysql/
  mysql -u $USER -p$PASS $DB < $DIR/mariadbconf/openvpn.sql
  ## Put default user file in place
  if [ ! -e "/etc/mysql/mariadb.conf.d/50-client.cnf" ]; then
    cp $DIR/mariadbconf/50-client.cnf /etc/mysql/mariadb.conf.d/
    sed -i 's/user\=.*/user\=$USER/' /etc/mysql/mariadb.conf.d/50-client.cnf
    sed -i 's/password\=.*/password\=$PASS/' /etc/mysql/mariadb.conf.d/50-client.cnf
  fi
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

function configureFwknop {

}

function configureEasyrsa {

}

function configureOpenvpn {

}

function configureSquid {

}

function configureRedsocks {

}

### Execute order
infoGather
installPackages
configureDatabase
configureFirewall
configureFwknop
configureEasyrsa
configureOpenvpn
configureSquid
configureRedsocks

echo ""
echo "Configuration is now complete!!"
echo "Next, go configure your gateway"
