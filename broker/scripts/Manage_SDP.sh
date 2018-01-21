#!/bin/bash

# Set where we're working from
## These will be installation specific
DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

function optionsMenu {
  echo
  echo "**************************"
  echo "* SDP MANAGEMENT OPTIONS *"
  echo "**************************"
  # Prompt for an option
  PS3='Choose an Option to Continue: '
  options=("Manage Users" "Manage Groups" "Manage Gateways" "Manage Resources"
          "Rebuild Squid Configuration" "Exit")
    select opt in "${options[@]}"
    do
      case $opt in
        "Manage Users")
           bash $SCRIPTS_DIR/manage_clients.sh
           break
           ;;
         "Manage Groups")
           bash $SCRIPTS_DIR/manage_usergroups.sh
           break
           ;;
         "Manage Gateways")
           bash $SCRIPTS_DIR/manage_gateways.sh
           break
           ;;
         "Manage Resources")
           bash $SCRIPTS_DIR/list_resources.sh
           bash $SCRIPTS_DIR/manage_Resources.sh
           break
           ;;
         "Rebuild Squid Configuration")
           bash $SCRIPTS_DIR/rebuild_squid_config.sh
           break
           ;;
         "Exit")
           exit
           ;;
         *) echo invalid option;;
       esac
    done
  optionsMenu
}

optionsMenu
