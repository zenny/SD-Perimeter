#!/bin/bash

read -p "What name would you like to use for your resource? " RESOURCE_NAME

read -r -p "Will this be a Web Resource or TCP Resource ['web/tcp'] " RESOURCE_TYPE
case "$RESOURCE_TYPE" in
    [wW][eE][bB]|[wW]) 
        RESOURCE_TYPE=web
        ;;
    [tT][cC][pP]|[tT])
        RESOURCE_TYP=tcp
        ;;
    *)
        echo "You did not enter a value. Exiting."
        exit
        ;;
esac

read -p "What is the DOMAIN or IP of your resource? " RESOURCE_DOMAIN

function resourcePorts {
  RESOURCE_PORT=()
  read -p "Enter a new port for this resource? " newPort
  RESOURCE_PORT+=("$newPort")
  read -r -p "Would you you like to add another port? [Y/n] " response
  case "$response" in
    [yY][eE][sS]|[yY]) 
        resourcePorts
        ;;
    *)
        echo ""
        ;;
  esac

}
resourcePorts

echo ""
echo "Resource Name = $RESOURCE_NAME"
echo "Resource Type = $RESOURCE_TYPE"
echo "${RESOURCE_PORT[@]}"
