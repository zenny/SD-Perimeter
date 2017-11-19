#!/bin/bash

. /etc/openvpn/scripts/config.sh

ufw delete allow 22
ufw delete allow $CLIENT_VPN_PORT
ufw delete allow $GATEWAY_VPN_PORT
