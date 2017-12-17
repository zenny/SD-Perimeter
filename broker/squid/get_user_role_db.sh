#!/bin/bash

## Update this file to edit db settings
. /etc/openvpn/scripts/config.sh

function getResult {
  AUTHUSER=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "select user_id from squid_user_helper where log_remote_ip='$srchost'"`

  RESULTS=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "select count(*) from squid_rules_helper r, squid_group_helper u where r.resource_name='$resource' and u.user='$AUTHUSER' and u.ugroup = r.ugroup_name"`

  if [ "$RESULTS" -gt 0 ]; then
    echo "${id} OK user=$AUTHUSER"
  else
    echo "${id} ERR user=$AUTHUSER"
  fi
}

while read id srchost resource;
  do
    getResult &
  done
exit 1
