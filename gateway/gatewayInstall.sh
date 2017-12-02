#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG=/etc/openvpn/scripts/config.sh

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
    echo "No Config found. Getting config from Broker"
    RSAKEY=/home/sdpmanagement/id_rsa
    if [ ! -e $RSAKEY ]; then
      echo "No RSA key found. You need to register on new Gateway on the broker first and follow directions displayed there."
      exit
    fi
    chmod 600 $RSAKEY
    read -p "Enter the IP address of the broker: " PRIMARY_IP
    read -p "Enter the Gateway Name: " GW_HOSTNAME
    echo ""
    mkdir -p /etc/openvpn/scripts
    scp -i $RSAKEY -o StrictHostKeyChecking=no sdpmanagement@$PRIMARY_IP:/home/sdpmanagement/$GW_HOSTNAME.ovpn /etc/openvpn/gateway.conf
    scp -i $RSAKEY -o StrictHostKeyChecking=no sdpmanagement@$PRIMARY_IP:/home/sdpmanagement/${GW_HOSTNAME}_gw_config.sh $CONFIG
    chmod +x $CONFIG
  fi
}

####Install required Packages
function installPackages {
  echo "Installing packages"
  apt-get update
  apt install -y mysql-client fwknop-client openvpn squid
}

function configureFwknop {
  ##Create fwknoprc file so fwknop doesn't complain
  touch ~/.fwknoprc
  chmod 600 ~/.fwknoprc
}  

function configureOpenvpn {
  echo "Putting OpenVPN Configuration in place"
  ##Create OpenVPN/FWKNOP script
  OVPN_FWKNOP=$OPENVPN_DIR/scripts/openvpn_fwknop.sh
  chmod +x $OVPN_FWKNOP
  echo "#!/bin/bash" > $OVPN_FWKNOP
  echo "" >> $OVPN_FWKNOP
  echo "/bin/su - root -c \"/usr/bin/fwknop -A udp/$GATEWAY_VPN_PORT -f 10 --use-hmac -D $PRIMARY_IP -R --key-base64-hmac=$FWKNOP_HMAC --key-base64-rijndael=$FWKNOP_RIJNDAEL --wget-cmd /usr/bin/wget\"" >> $OVPN_FWKNOP
  echo "sleep 0.5" >> $OVPN_FWKNOP
  ##Stop and remove the old service
  service openvpn stop
  systemctl disable openvpn
  ##Put new service definition in place to send spa before starting OpenVPN
  OVPN_SERVICE=/etc/systemd/system/multi-user.target.wants/openvpn@gateway.service
  if [ ! -e $OVPN_SERVICE ]; then
    systemctl enable openvpn@gateway
  fi
  if [ -e $OVPN_SERVICE ] && [ `grep -c ExecStartPre $OVPN_SERVICE` -lt 1 ]; then
    echo "Adding fwknop script to service definition"
    sed -i "\|ExecStart\=.*| i ExecStartPre\=$OVPN_FWKNOP" $OVPN_SERVICE
  else
    echo "$OVPN_SERVICE Definition already updated"
  fi
  systemctl daemon-reload
  service openvpn@gateway start
  ##Create OpvnVPN service check
  OVPN_CHECK=$OPENVPN_DIR/scripts/openvpn_check.sh
  chmod +x $OVPN_CHECK
  echo "#!/bin/bash" > $OVPN_CHECK
  echo "" >> $OVPN_CHECK
  echo "ROUTER_IP=$GATEWAY_GATEWAY" >> $OVPN_CHECK
  echo "/bin/su - root -c \"( ! ping -c1 $GATEWAY_GATEWAY >/dev/null 2>&1 ) && service openvpn@gateway restart >/dev/null 2>&1\"" >> $OVPN_CHECK
  ##Add OpenVPN Check Script to Cronjob
  if [ `crontab -l | grep -c $OVPN_CHECK` -lt 1 ]; then
    crontab -l > tempcron
    echo "* * * * * $OVPN_CHECK" >> tempcron
    crontab tempcron
    rm tempcron
  fi
}

function configureSquid {
  echo "Putting Squid Configuration in place."
  SQUIDCONF=/etc/squid/squid.conf
    if [ ! -e ${SQUIDCONF}.orig ]; then
      mv $SQUIDCONF ${SQUIDCONF}.orig
    fi
    cp $DIR/scripts/squid.conf $SQUIDCONF
    cp $DIR/scripts/get_user_role_db.sh /etc/squid/get_user_role_db.sh
    chmod +x /etc/squid/get_user_role_db.sh
    sed -i "s@http\_port\ .*@http\_port\ $SQUID_PORT@" $SQUIDCONF 
    if [ ! -e ${SQUIDCONF}.d ]; then
      mkdir ${SQUIDCONF}.d
    fi
    if [ ! -e ${SQUIDCONF}.d/acl_sdp_clients.conf ]; then
      touch ${SQUIDCONF}.d/acl_sdp_clients.conf
    fi
    echo "acl sdp_clients src $CLIENT_NET" > ${SQUIDCONF}.d/acl_sdp_clients.conf
    if [ ! -e ${SQUIDCONF}.d/cache_peers.conf ]; then
      touch ${SQUIDCONF}.d/cache_peers.conf
    fi
    if [ ! -e ${SQUIDCONF}.d/acl_ports.conf ]; then
      touch ${SQUIDCONF}.d/acl_ports.conf
    fi
    echo "acl SSL_ports port 443" > ${SQUIDCONF}.d/acl_ports.conf
    if [ ! -e ${SQUIDCONF}.d/acl_user_roles.conf ]; then
      touch ${SQUIDCONF}.d/acl_user_roles.conf
    fi
    if [ ! -e ${SQUIDCONF}.d/acl_dstdomains.conf ]; then
      touch ${SQUIDCONF}.d/acl_dstdomains.conf
    fi
    if [ ! -e ${SQUIDCONF}.d/never_direct.conf ]; then
      touch ${SQUIDCONF}.d/never_direct.conf
    fi
    if [ ! -e ${SQUIDCONF}.d/http_access.conf ]; then
      touch  ${SQUIDCONF}.d/http_access.conf
    fi
    echo "Restarting Squid. This usually takes a few seconds."
    service squid restart
}

createManagementUser
retrieveConfig
. $CONFIG
installPackages
configureFwknop
configureOpenvpn
configureSquid
