#!/bin/bash

####Information Gathering
read -sp "Choose a password for your database root user [Default: rootdbpass]" rootDBpass
rootDBpass=${rootDBpass:-rootdbpass}
echo ""
read -sp "Choose a password for your OpenVPN database user [Default: ovpnpass]" ovpnDBpass
ovpnDBpass=${ovpnDBpass:-ovpnpass}
echo ""

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
  mysql -u root -p$rootDBpass < mariadbconf/openvpn.sql
  ## Create OpenVPN database user
  mysql -u root -p$rootDBpass -e "CREATE USER openvpn@'%' IDENTIFIED BY '${ovpnDBpass}'"
  mysql -u root -p$rootDBpass -e "GRANT ALL PRIVILEGES ON openvpn.* TO 'openvpn'@'%'"
  mysql -u root -p$rootDBpass -e "FLUSH PRIVILEGES"
  ## Put default user file in place
  cp mariadbconf/50-client.cnf /etc/mysql/mariadb.conf.d/
  sed -i 's/password\=.*/password\=$ovpnDBpass/' /etc/mysql/mariadb.conf.d/50-client.cnf
  ## Restart database
  service mysql restart
}


installPackages
configureDatabase
