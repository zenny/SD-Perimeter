#! /bin/bash
# Script to automate creating new OpenVPN clients
# The client cert and key, along with the CA cert is
# zipped up and placed somewhere to download securely
#
# H Cooper - 05/02/11
#
# Usage: new-openvpn-client.sh <common-name>

# Set where we're working from
## These will be installation specific
OPENVPN_RSA_DIR=/etc/openvpn/easy-rsa
OPENVPN_CLIENT_FOLDER=/etc/openvpn/client
GATEWAY_BASE_CONFIG=/etc/openvpn/gateway-configs/gatewaybase.conf
GATEWAY_OUTPUT_DIR=/home/sdpmanagement
DB_CONFIG=/etc/openvpn/scripts/config.sh

## These will most likely not need editing
OPENVPN_KEYS=$OPENVPN_RSA_DIR/keys
OPENVPN_GATEWAY_BASE=$OPENVPN_CLIENT_FOLDER/sdp-gateway-base

# Either read the CN from $1 or prompt for it
if [ -z "$1" ]
	then echo -n "Enter new gateway common name (CN): "
	read -e CN
else
	CN=$1
fi

# Ensure CN isn't blank
if [ -z "$CN" ]
	then echo "You must provide a CN."
	exit
fi

function createCert {
	# Enter the easy-rsa directory and establish the default variables
	cd $OPENVPN_RSA_DIR
	source ./vars > /dev/null
	
	# Copied from build-key script (to ensure it works!)
	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --batch $CN
}

function createOvpn {
	#sudo cp $OPENVPN_GATEWAY_BASE $OPENVPN_CLIENT_FOLDER/$CN
	cat ${GATEWAY_BASE_CONFIG} \
	    <(echo -e '<ca>') \
	    ${OPENVPN_KEYS}/ca.crt \
	    <(echo -e '</ca>\n<cert>') \
	    ${OPENVPN_KEYS}/$CN.crt \
	    <(echo -e '</cert>\n<key>') \
	    ${OPENVPN_KEYS}/$CN.key \
	    <(echo -e '</key>\n<tls-auth>') \
	    ${OPENVPN_KEYS}/ta.key \
	    <(echo -e '</tls-auth>') \
	    > ${GATEWAY_OUTPUT_DIR}/$CN.ovpn
	
	# Celebrate!
	echo "Config created at ${GATEWAY_OUTPUT_DIR}/$CN.ovpn"
}

function revokeCert {
    echo "Revoking previous Cert"
    rm $GATEWAY_OUTPUT_DIR/$USERNAME.ovpn

    # Enter the easy-rsa directory and establish the default variables
    cd $OPENVPN_RSA_DIR
    source ./vars > /dev/null

    # Copied from revoke-full script (to ensure it works!)
    CRL="crl.pem"
    RT="revoke-test.pem"

    if [ "$KEY_DIR" ]; then
        cd "$KEY_DIR"
        rm -f "$RT"
    
        # set defaults
        export KEY_CN=""
        export KEY_OU=""
        export KEY_NAME=""
    
        # required due to hack in openssl.cnf that supports Subject Alternative Names
        export KEY_ALTNAMES=""
    
        # revoke key and generate a new CRL
        $OPENSSL ca -revoke "$CN.crt" -config "$KEY_CONFIG"
    
        # generate a new CRL -- try to be compatible with
        # intermediate PKIs
        $OPENSSL ca -gencrl -out "$CRL" -config "$KEY_CONFIG"
        if [ -e export-ca.crt ]; then
            cat export-ca.crt "$CRL" >"$RT"
        else
            cat ca.crt "$CRL" >"$RT"
        fi
    
        # verify the revocation
        $OPENSSL verify -CAfile "$RT" -crl_check "$CN.crt"
    else
        echo 'Please source the vars script first (i.e. "source ./vars")'
        echo 'Make sure you have edited it to reflect your configuration.'
    fi
    rm ${OPENVPN_KEYS}/$CN.crt
    rm ${OPENVPN_KEYS}/$CN.key
    rm ${OPENVPN_KEYS}/$CN.csr
    sudo rm $OPENVPN_CLIENT_FOLDER/$CN
    sudo rm $GATEWAY_OUTPUT_DIR/$CN.ovpn
    echo "Previous Certificate has been revoked"
    echo ""
}

# Check the CN doesn't already exist
if [ -f $OPENVPN_KEYS/$CN.crt ]
        then echo "Certificate with the CN $CN alread exists!"
                PS3='Choose an Option to Continue: '
                options=("Rebuild Configuration" "Revoke cert and rebuild Configuration" "Disable Gateway" "Cancel")
                select opt in "${options[@]}"
                do
                    case $opt in
                        "Rebuild Configuration")
                            echo "Rebuilding Configuration now"
		            createOvpn
		            break
                            ;;
                        "Revoke cert and rebuild Configuration")
                            echo "Revoking Cert and Rebuilding New Configuration"
		            revokeCert
		            createCert
		            createOvpn
		            break
                            ;;
                        "Disable Gateway")
                            echo "Disabling Gateway"
                            revokeCert
                            break
                            ;;
                        "Cancel")
                            exit
                            ;;
                        *) echo invalid option;;
                    esac
                done
        exit
else
        createCert
        createOvpn
fi
