#!/bin/bash

. /etc/openvpn/scripts/config.sh

apt-get autoremove --purge -y openvpn fwknop-client squid

rm -rf /etc/openvpn
rm -rf /etc/squiid
rm -f ~/.fwknoprc

userdel sdpmanagement
rm -rf /home/sdpmanagement
