#!/bin/bash

function createManagementUser {
  if [ `grep -c sdpmanagement /etc/passwd` -lt '1' ]; then
    echo "Creating Management User"
    SDP_MANAGE_HOME=/home/sdpmanagement
    groupadd sdpmanagement
    useradd sdpmanagement -g sdpmanagement -s /bin/bash -p '*' -N -d $SDP_MANAGE_HOME -m
    mkdir -p $SDP_MANAGE_HOME/.ssh
    chown sdpmanagement:sdpmanagement -R $SDP_MANAGE_HOME
  fi
}

function retrieveConfig {
  if [ ! -e /etc/openvpn/scripts/config.sh ]; then
    RSAKEY=/home/sdpmanagement/id_rsa
    chmod 600 $RSAKEY
    read -p "Enter the IP address of the broker: " PRIMARY_IP
    read -p "Enter the Gateway Name: " GW_HOSTNAME
    echo ""
    mkdir -p /etc/openvpn/scripts
    scp -i $RSAKEY -o StrictHostKeyChecking=no sdpmanagement@$PRIMARY_IP:/home/sdpmanagement/$GW_HOSTNAME.ovpn /etc/openvpn/$GW_HOSTNAME.conf
    scp -i $RSAKEY -o StrictHostKeyChecking=no sdpmanagement@$PRIMARY_IP:/home/sdpmanagement/gw_config.sh /etc/openvpn/scripts/config.sh
  fi
}

####Install required Packages
function installPackages {
  echo "Installing packages"
  apt-get update
  apt install -y mysql-client fwknop-client openvpn squid
}

createManagementUser
retrieveConfig
installPackages
