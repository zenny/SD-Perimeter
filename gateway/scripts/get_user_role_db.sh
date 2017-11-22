#!/bin/bash

## Update this file to edit db settings
. /etc/openvpn/scripts/config.sh

function getResult {
  AUTHUSER=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "select user_id from squid_user_helper where log_remote_ip='$srchost'"`
  RESULTS=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "select count(*) from squid_group_helper where user_id='$AUTHUSER' and ugroup_id='$group'"`
  if [ "$RESULTS" -eq 1 ]; then
    echo "${id} OK user=$AUTHUSER"
  else
    echo "${id} ERR user=$AUTHUSER"
  fi
}

while read id srchost group;
  do
    getResult &
  done
exit 1
