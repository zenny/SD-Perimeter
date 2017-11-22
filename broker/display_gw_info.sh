#!/bin/bash

. /etc/openvpn/scripts/config.sh

echo ""
echo "The remaining configuration must be completed on your Gateway."
echo ""
echo "You will be prompted for the following details."
echo "RSA Public Key:"
echo `cat /home/sdpmanagement/.ssh/id_rsa.pub`
echo ""
echo "RSA Private Key:"
echo `cat /home/sdpmanagement/.ssh/id_rsa`
echo ""
echo "Broker IP Address:"
echo $PRIMARY_IP
