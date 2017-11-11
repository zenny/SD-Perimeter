#!/bin/bash

apt-get update
apt-get install -y software-properties-common

## Add fwknop PPA repo
add-apt-repository ppa:cipherdyne/fwknop -y
## Add mariadb repo
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'

apt-get update
apt install -y mariadb-server fwknop-server fwknop-client squid zip unzip mutt redsocks
