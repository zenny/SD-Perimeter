#!/bin/bash

. /etc/openvpn/scripts/config.sh

echo ""
echo "The remaining configuration must be completed on your Gateway."
echo ""
echo "Enter the following command on your Gateway to create the private key:"
echo ""
echo "echo \"`cat /home/sdpmanagement/.ssh/id_rsa`\" > /home/sdpmanagement/id_rsa"
echo ""
echo "Enter the Broker IP Address when prompted:"
echo $PRIMARY_IP
