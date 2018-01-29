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
DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

function showUsers {
  title="List Users"
  whiptail --textbox --title "$title" --scrolltext /dev/stdin 25 78 <<<"$(
        echo 'Configured Users:\n\n'
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e '
            SELECT CONCAT(
                  user_mail,";",
                  user_enable
            ) "<USER NAME>;<ENABLED>"
            FROM user
            ORDER BY user_mail
        ' | column -t -s ';')"
  optionsMenu
}

function createCert {
	# Enter the easy-rsa directory and establish the default variables
	cd $OPENVPN_RSA_DIR
	source ./vars > /dev/null
	
	# Copied from build-key script (to ensure it works!)
	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --batch $CN
}

function createOvpn {
	#sudo cp $OPENVPN_CLIENT_BASE $OPENVPN_CLIENT_FOLDER/$CN
	cat ${BASE_CONFIG} \
	    <(echo -e '<ca>') \
	    ${OPENVPN_KEYS}/ca.crt \
	    <(echo -e '</ca>\n<cert>') \
	    ${OPENVPN_KEYS}/$CN.crt \
	    <(echo -e '</cert>\n<key>') \
	    ${OPENVPN_KEYS}/$CN.key \
	    <(echo -e '</key>\n<tls-auth>') \
	    ${OPENVPN_KEYS}/ta.key \
	    <(echo -e '</tls-auth>') \
	    > ${OUTPUT_DIR}/$USERNAME.ovpn
	
	# Celebrate!
	echo "Config created at ${OUTPUT_DIR}/$USERNAME.ovpn"
}

function emailCert {
    cd $OUTPUT_DIR
    echo "Emailing configuration to $CN"
    echo -e "Hello, ${CN}!\n\nYour Foxhole SDP configuration is attached." > mail.txt
    echo "" >> mail.txt
    echo "This mail is automatically generated. Please do not respond to it." >> mail.txt
    echo "" >> mail.txt
    echo "--" >> mail.txt
    echo "ifoxxy.net Administration." >> mail.txt
    cat mail.txt | mutt -s "Foxhole SDP Configuration for $CN" -a ${OUTPUT_DIR}/$USERNAME.ovpn -- $CN
    rm mail.txt
}

function revokeCert {
    echo "Revoking previous Cert"
    rm $OUTPUT_DIR/$USERNAME.ovpn
    rm $OUTPUT_DIR/${USERNAME}_windows_sdp.zip

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
    echo "Previous Certificate has been revoked"
    echo ""
}

function createWinBundle {
    mkdir $OUTPUT_DIR/tmp
    cp $OUTPUT_DIR/$USERNAME.ovpn $OUTPUT_DIR/tmp/
    cp $BASE_WIN_FILES/fwknop.exe $OUTPUT_DIR/tmp/
    cp $BASE_WIN_FILES/libfko.dll $OUTPUT_DIR/tmp/
    cp $BASE_WIN_FILES/msvcr120.dll $OUTPUT_DIR/tmp/
    cp $BASE_WIN_FILES/sdp-client_down.bat $OUTPUT_DIR/tmp/${USERNAME}_down.bat
    cp $BASE_WIN_FILES/sdp-client_pre.bat $OUTPUT_DIR/tmp/${USERNAME}_pre.bat
    cp $BASE_WIN_FILES/sdp-client_up.bat $OUTPUT_DIR/tmp/${USERNAME}_up.bat
    cd $OUTPUT_DIR/tmp
    zip $OUTPUT_DIR/${USERNAME}_windows_sdp.zip *
    cd $OUTPUT_DIR
    rm -rf $OUTPUT_DIR/tmp
    echo "Windows Configuration Bundle Created"
    echo ""
}

function disableDbEntries {
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "update user set user_enable='no' where user_mail='$CN'"
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "delete from user_group where user_id = (select user_id from user where user_mail = '$CN')"
    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "delete from radusergroup where username = '$CN'"
    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "insert into radusergroup (username,groupname,priority) VALUES ('$CN','disabled',1)"
}

function enableDbEntries {
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "update user set user_enable='yes' where user_mail='$CN'"
    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "delete from radusergroup where username='$CN' and groupname='disabled'"
}

function createDbEntries {
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into user (user_mail,user_start_date,user_end_date) values ('$CN', now(), now() + INTERVAL 50 year)"
    mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "INSERT INTO user_group (user_id,ugroup_id) VALUES ( (select user_id from user where user_mail = '$CN'), (select ugroup_id from ugroup where ugroup_name='all_users'))"
    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "INSERT INTO radcheck (username,attribute,op,value) VALUES ('$CN','Cleartext-Password',':=','password')"
    mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "insert into radusergroup (username,groupname,priority) VALUES ('$CN','all_users',1)"
    enableDbEntries
}

function getUserName {
  # Extract username portion from CN
  USERNAME=`echo $CN | sed -e 's/\@.*//'`
}

function getCommonName {
  CN=$(
    whiptail --inputbox "\nEnter user's email address:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  getUserName
  exitstatus=$?
}

function createUser {
  title="Create New User"
  getCommonName
  if [ $exitstatus = 0 ]; then
    createCert
    createOvpn
    createWinBundle
    createDbEntries
    emailCert
  fi
  optionsMenu
}

function resendConfigs {
  title="Resend Configurations"
  getCommonName
  if [ $exitstatus = 0 ]; then
    createOvpn
    createWinBundle
    enableDbEntries
    emailCert
  fi
  optionsMenu
}

function revokeResendConfigs {
  title="Securely Resend Configurations"
  getCommonName
  if [ $exitstatus = 0 ]; then
    revokeCert
    createCert
    createOvpn
    createWinBundle
    enableDbEntries
    emailCert
  fi
  optionsMenu
}

function disableUser {
  title="Disable User"
  getCommonName
  if [ $exitstatus = 0 ]; then
    revokeCert
    disableDbEntries
  fi
  optionsMenu
}

function optionsMenu {
  opt=$(
    whiptail --title "USER MANAGEMENT OPTIONS" --menu "\nChoose an item to continue:" \
    25 78 16 \
    "List Users" "Show a list of all current users." \
    "Create/Reactivate User" "Create a new user or activate a disabled user." \
    "Resend Configuration" "Resend the latest configuration to a user." \
    "Secure Resend" "Revoke certificate and send user a new configuration." \
    "Disable User" "Disable an existing user account." 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    case $opt in
      "List Users")
        showUsers
        ;;
      "Create/Reactivate User")
        createUser
        ;;
      "Resend Configuration")
        resendConfigs
        ;;
      "Secure Resend")
        revokeResendConfigs
        ;;
      "Disable User")
        disableUser
        ;;
    esac
  fi
}

if [ -z "$1" ]; then
  optionsMenu
else
  CN=$1
  getUserName
  if [ -e $OPENVPN_KEYS/$CN.crt ]; then
    optionsMenu
  else
    createCert
    createOvpn
    createWinBundle
    createDbEntries
    emailCert
  fi
fi
