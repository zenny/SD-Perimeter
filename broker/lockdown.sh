#!/bin/bash

. /etc/openvpn/scripts/config.sh

ufw delete allow 22/tcp
ufw delete allow $CLIENT_VPN_PORT/udp
ufw delete allow $GATEWAY_VPN_PORT/udp
