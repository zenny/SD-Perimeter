#!/bin/bash

. /etc/openvpn/scripts/config.sh

apt-get autoremove --purge mariadb-server fwknop-server fwknop-client fwknop-apparmor-profile openvpn easy-rsa nginx squid zip unzip mutt redsocks postfix -y
add-apt-repository --remove ppa:cipherdyne/fwknop -y
add-apt-repository --remove 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main' -y
apt-key del C74CD1D8
apt-get update

rm -rf /etc/mysql
rm -rf /var/lib/mysql
rm -rf /var/spool/squid
rm -rf $OPENVPN_RSA_DIR
rm -rf /etc/openvpn
rm -rf /etc/fwknop
rm -rf /etc/squid
rm -f /etc/redsocks.conf*

userdel sdpmanagement
rm -rf /home/sdpmanagement
