#!/bin/bash

####Information Gathering
function infoGather {
  OPENVPN_DIR=/etc/openvpn
  DB_CONFIG=$OPENVPN_DIR/scripts/config.sh
  ##Check for pre-existing configuration and create if it does not exist
  if [ ! -e "$OPENVPN_DIR/scripts" ]
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
    ##Write out initial config script
    echo "#!/bin/bash" >> $DB_CONFIG
    echo "####Directories" >> $DB_CONFIG
    echo "OPENVPN_DIR=/etc/openvpn" >> $DB_CONFIG
    echo "DB_CONFIG=\$OPENVPN_DIR/scripts/config.sh" >> $DB_CONFIG
    echo "OPENVPN_CLIENT_FOLDER=\$OPENVPN_DIR/client" >> $DB_CONFIG
    echo "OUTPUT_DIR=\$OPENVPN_DIR/client-configs/files" >> $DB_CONFIG
    echo "BASE_CONFIG=\$OPENVPN_DIR/client-configs/base.conf" >> $DB_CONFIG
    echo "BASE_WIN_FILES=\$OPENVPN_DIR/client-configs/winfiles" >> $DB_CONFIG
    echo "OPENVPN_CLIENT_BASE=\$OPENVPN_CLIENT_FOLDER/sdp-base" >> $DB_CONFIG
    echo "" > $DB_CONFIG
  else
    . $DB_CONFIG
  fi  

  ##Prompt user for information if not already gathered
  if [ -n "$KEY_EMAIL" ]; then
    read -p "Choose your Admin email [Default: admin@mail.com]" KEY_EMAIL
    KEY_EMAIL=${KEY_EMAIL:-admin@mail.com}
    echo "####Easy-RSA variables" >> $DB_CONFIG
    echo "KEY_EMAIL=$KEY_EMAIL" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$EASY_RSA_DIR" ]; then
    read -p "Choose your EasyRSA installation Directory [Default: /etc/openvpn/easy-rsa]" OPENVPN_RSA_DIR
    OPENVPN_RSA_DIR=${OPENVPN_RSA_DIR:-/etc/openvpn/easy-rsa}
    OPENVPN_KEYS=$OPENVPN_RSA_DIR/keys
    echo "OPENVPN_RSA_DIR=$OPENVPN_RSA_DIR" >> $DB_CONFIG
    echo "OPENVPN_KEYS=\$OPENVPN_RSA_DIR/keys" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_NAME" ]; then
    read -p "Choose a name for your Certificate Authority [Default: MyCA]" KEY_NAME
    KEY_NAME=${KEY_NAME:-MyCA}
    echo "KEY_NAME=$KEY_NAME" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_COUNTRY" ]; then
    read -p "Choose the country for your CA [Default: US]" KEY_COUNTRY
    KEY_COUNTRY=${KEY_COUNTRY:-US}
    echo "KEY_COUNTRY=$KEY_COUNTRY" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_PROVINCE" ]; then
    read -p "Choose the state/province for your CA [Default: NA]" KEY_PROVINCE
    KEY_PROVINCE=${KEY_PROVINCE:-NA}
    echo "KEY_PROVINCE=$KEY_PROVINCE" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_CITY" ]; then
    read -p "Choose the city for your CA [Default: None]" KEY_CITY
    KEY_CITY=${KEY_CITY:-None}
    echo "KEY_CITY=$KEY_CITY" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_ORG" ]; then
    read -p "Choose the Orgonization for your CA [Default: None]" KEY_ORG
    KEY_ORG=${KEY_ORG:-None}
    echo "KEY_ORG=$KEY_ORG" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$KEY_OU" ]; then
    read -p "Choose the Organizational Unit for your CA [Default: None]" KEY_OU
    KEY_OU=${KEY_OU:-None}
    echo "KEY_OU=$KEY_OU" >> $DB_CONFIG
    echo ""
  fi
  if [ -n "$rootDBpass" ]; then
    read -sp "Choose a password for your database root user [Default: rootdbpass]" rootDBpass
    rootDBpass=${rootDBpass:-rootdbpass}
    echo ""
  fi
  if [ -n "$PASS" ]; then
    read -sp "Choose a password for your OpenVPN database user [Default: ovpnpass]" PASS
    PASS=${PASS:-ovpnpass}
    USER='openvpn'
    DB='openvpn'
    HOST='127.0.0.1'
    PORT='3306'
    echo "####Database Setting" >> DB_CONFIG
    echo "HOST=$HOST" >> $DB_CONFIG
    echo "PORT=$PORT" >> $DB_CONFIG
    echo "USER=$USER" >> $DB_CONFIG
    echo "PASS=$PASS" >> $DB_CONFIG
    echo "DB=$DB" >> $DB_CONFIG
    echo ""
  fi
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
  ## Equivalent of mysql_secure_installation
  ## Special thanks: http://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
  mysqladmin password "$rootDBpass"
  mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User=''"
  mysql -u root -p$rootDBpass -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
  mysql -u root -p$rootDBpass -e "DROP DATABASE test"
  mysql -u root -p$rootDBpass -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
  mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  ## Put small memory server configs in place
  MEMTOTAL=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
  if [ $MEMTOTAL -lt 1000000 ] ; then
    cp mariadbconf/50-server.cnf /etc/mysql/mariadb.conf.d/
  fi
  ## Source in OpenVPN database
  ## Special thanks: https://sysadmin.compxtreme.ro/how-to-install-a-openvpn-system-based-on-userpassword-authentication-with-mysql-day-control-libpam-mysql/
  mysql -u root -p$rootDBpass < mariadbconf/openvpn.sql
  ## Create OpenVPN database user
  mysql -u root -p$rootDBpass -e "CREATE USER $USER@'%' IDENTIFIED BY '${PASS}'"
  mysql -u root -p$rootDBpass -e "GRANT ALL PRIVILEGES ON $DB.* TO '$USER'@'%'"
  mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  ## Put default user file in place
  cp mariadbconf/50-client.cnf /etc/mysql/mariadb.conf.d/
  sed -i 's/user\=.*/user\=$USER/' /etc/mysql/mariadb.conf.d/50-client.cnf
  sed -i 's/password\=.*/password\=$PASS/' /etc/mysql/mariadb.conf.d/50-client.cnf
  ## Restart database
  service mysql restart
}

infoGather
installPackages
configureDatabase
