#!/bin/bash

. /opt/sdp/scripts/config.sh

##Ensure any open sessions are marked closed
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE log SET log_end_time=now() WHERE log_end_time='0000-00-00 00:00:00'"
mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "UPDATE user SET user_online='no' WHERE user_mail='$common_name' AND user_mail not in (select user_id from log where log_end_time='0000-00-00 00:00:00')"
