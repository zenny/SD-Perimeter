#! /bin/bash

# Set where we're working from
## These will be installation specific
DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

function showGroups {
  echo
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "select ugroup_name 'Group', ugroup_description Description from ugroup where ugroup_enabled = 'yes' order by ugroup_name"
  optionsMenu
}

function showGroupMembership {
  echo
  read -p "Enter group name to show it's members: " groupName 
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "select u.user_mail '\"$groupName\" Group Members' from user u, ugroup g, user_group ug where u.user_id = ug.user_id and g.ugroup_id = ug.ugroup_id and ugroup_name = '$groupName'"
  optionsMenu
}

function showUserGroups {
  echo
  read -p "Enter the username to show group memberships: " userName
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "select g.ugroup_name 'Group Memberships for \"$userName\"' from user u, ugroup g, user_group ug where u.user_id = ug.user_id and g.ugroup_id = ug.ugroup_id and u.user_mail = '$userName'"
  optionsMenu
}
function addGroup {
  echo
  read -p "Enter the name of your new group: " groupName
  read -p "Enter the group description (optional): " groupDescription
  groupDescription=${groupDescription:-$groupName}
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into ugroup (ugroup_name,ugroup_description,
        ugroup_enabled) values ('$groupName','$groupDescription','yes')"
  mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "insert into radgroupreply (groupname,attribute,op,value) 
        values ('$groupName','Fall-Through','=','Yes')"
  echo "Group \"$groupName\" added"
  optionsMenu
}

function deleteGroup {
  echo
  read -p "Enter the name of the group to delete: " groupName
  mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "delete from ugroup where ugroup_name = '$groupName'"
  mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "delete from radgroupreply where groupname = '$groupName'"
  mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "delete from radusergroup where groupname = '$groupName'"
  echo "Group \"$groupName\" has been deleted"
  optionsMenu
}

function usersToAddFunc {
  read -p "Enter a username to add to the \"$groupName\" group: " newUser
  if [ -z "$newUser" ]; then
    echo
    echo "You must choose at least one user!"
    usersToAddFunc
  fi
  usersToAddArr+=("$newUser")
  unset newUser
  read -r -p "Would you you like to add another user to the \"$groupName\" group? [Y/n] " addUser
  case "$addUser" in
    [yY][eE][sS]|[yY])
        usersToAddFunc
        ;;
    *)
        echo ""
        ;;
  esac
}

function addGroupMember {
  echo
  read -p "Enter the name of the group to add members to: " groupName
  usersToAddArr=()
  usersToAddFunc
  for user in "${usersToAddArr[@]}"
  do
    userExists=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) 
        from user where user_mail = '$user'"`
    if [ $userExists != "0" ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "insert into user_group (user_id, ugroup_id)
        values ((select user_id from user where user_mail = '$user'),
        (select ugroup_id from ugroup where ugroup_name = '$groupName'))"
      mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "insert into radusergroup (username, groupname, priority)
        values ('$user','$groupName',1)"
      echo "User \"$user\" succesfully added to \"$groupName\" group."
    else
      echo "User \"$user\" does not exist, skipping."
    fi
  done
  optionsMenu
}

function usersToDelFunc {
  read -p "Enter a username to remove from the \"$groupName\" group: " newUser
  if [ -z "$newUser" ]; then
    echo
    echo "You must choose at least one user!"
    usersToDelFunc
  fi
  usersToDelArr+=("$newUser")
  unset newUser
  read -r -p "Would you you like to remove another user from the \"$groupName\" group? [Y/n] " delUser
  case "$delUser" in
    [yY][eE][sS]|[yY])
        usersToDelFunc
        ;;
    *)
        echo ""
        ;;
  esac
}

function deleteGroupMember {
  echo
  read -p "Enter the name of the group to remove members from: " groupName
  usersToDelArr=()
  usersToDelFunc
  for user in "${usersToDelArr[@]}"
  do
    userExists=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) 
        from user where user_mail = '$user'"`
    if [ $userExists != "0" ]; then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "delete from user_group where user_id = 
        (select user_id from user where user_mail = '$user')
        and ugroup_id = (select ugroup_id from ugroup where ugroup_name = '$groupName')"
      mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "delete from radusergroup where username = '$user'
        and groupname = '$groupName'"
      echo "User \"$user\" succesfully deleted from \"$groupName\" group."
    else
      echo "User \"$user\" does not exist, skipping."
    fi
  done
  optionsMenu
}

function optionsMenu {
  echo
  echo "GROUP MANAGEMENT OPTIONS"
  # Prompt for an option
  PS3='Choose an Option to Continue: '
  options=("Show Groups" "Show Group Members" "Show User Memberships" "Create a Group"
          "Delete a Group" "Add Group Members" "Remove Group Members" "Exit")
    select opt in "${options[@]}"
    do
      case $opt in
        "Show Groups")
	   showGroups
           break
           ;;
         "Show Group Members")
	   showGroupMembership
           break
           ;;
         "Show User Memberships")
           showUserGroups
           break
           ;;
         "Create a Group")
           addGroup
           break
           ;;
         "Delete a Group")
           deleteGroup
           break
           ;;
         "Add Group Members")
           addGroupMember
           break
           ;;
         "Remove Group Members")
           deleteGroupMember
           break
           ;;
         "Exit")
           break
           ;;
         *) echo invalid option;;
       esac
    done
}

optionsMenu
