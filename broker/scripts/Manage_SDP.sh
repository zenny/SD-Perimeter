#!/bin/bash

# Set where we're working from
## These will be installation specific
DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

function optionsMenu {
  opt=$(
    whiptail --title "SDP MANAGEMENT OPTIONS" --menu "\nChoose an item to manage:" 25 78 16 \
    "Users" "Add, Delete and Modify Users." \
    "Groups" "Add, Delete and Modify Groups." \
    "Gateways" "Add, Delete and Modify Gateways." \
    "Resources" "Add, Delete and Modify Resources." 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    case $opt in
      "Users")
        bash $SCRIPTS_DIR/manage_clients.sh
        ;;
      "Groups")
        bash $SCRIPTS_DIR/manage_usergroups.sh
        ;;
      "Gateways")
        bash $SCRIPTS_DIR/manage_gateways.sh
        ;;
      "Resources")
        bash $SCRIPTS_DIR/manage_resources.sh
        ;;
    esac
    optionsMenu
  fi
}

optionsMenu
