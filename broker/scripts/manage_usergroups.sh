#! /bin/bash

# Set where we're working from
## These will be installation specific
DB_CONFIG=/opt/sdp/scripts/config.sh
. $DB_CONFIG

function showGroups {
  title="Show Existing Groups"
  whiptail --textbox --title "$title" --scrolltext /dev/stdin 25 78 <<<"$(
        echo 'Current Groups:\n\n'
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e '
            SELECT ugroup_name "Group",
              ugroup_description Description
            FROM ugroup
            WHERE ugroup_enabled = "yes"
            ORDER BY ugroup_name
        ')"
  optionsMenu
}

function getActiveGroups {
  activeGroups=$(mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe '
      SELECT ugroup_name "Group" 
      FROM ugroup
      WHERE ugroup_enabled = "yes"
      ORDER BY ugroup_name
  ')
  activeGroupsArr=()
  for group in $activeGroups
  do
    activeGroupsArr+=("$group" "")
  done
}

function showGroupMembership {
  title="Show Group Members"
  getActiveGroups
  groupName=$(
    whiptail --title "$title" --menu "\nChoose a group to show it's members." \
    25 78 16 "${activeGroupsArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    userNames=$(
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
            SELECT u.user_mail '\"$groupName\" Group Members'
            FROM user u
              INNER JOIN user_group AS ug ON u.user_id = ug.user_id
              INNER JOIN ugroup AS g ON g.ugroup_id = ug.ugroup_id 
            WHERE ugroup_name = '$groupName'"
    )
    userNameArr=()
    for name in $userNames
    do
      userNameArr+=("$name")
    done
    whiptail --textbox --title "$title" --scrolltext /dev/stdin \
      25 78 <<<$(echo "Group Members:\n\n" "${userNameArr[@]}")
  fi

  optionsMenu
}

function showUserGroups {
  title="List an Existing User's Group Memberships"
  userName=$(
    whiptail --inputbox "\nEnter a username to show group memberships:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    groupNames=$(
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
            SELECT g.ugroup_name 'Group Memberships for \"$userName\"'
            FROM user u
              INNER JOIN user_group AS ug ON u.user_id = ug.user_id
              INNER JOIN ugroup AS g ON g.ugroup_id = ug.ugroup_id
            WHERE u.user_mail = '$userName'
            ORDER BY g.ugroup_name"
    )
    groupNameArr=()
    for group in $groupNames
    do
      groupNameArr+=("$group")
    done
    whiptail --textbox --title "$title" --scrolltext /dev/stdin \
      25 78 <<<$(echo "User's Groups:\n\n" "${groupNameArr[@]}")
  fi

  optionsMenu
}

function addGroup {
  title="Add a New Group"
  groupName=$(
    whiptail --inputbox "\nEnter the name of your new group:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    groupDescription=$(
      whiptail --inputbox "\nEnter the group description (optional):" 8 78 \
      --title "$title" 3>&1 1>&2 2>&3
    )
    exitstatus=$?

    if [ $exitstatus = 0 ]; then
      groupDescription=${groupDescription:-$groupName}
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "
            INSERT INTO ugroup (
              ugroup_name,ugroup_description,ugroup_enabled
            )
            VALUES (
              '$groupName','$groupDescription','yes'
            )"
      mysql -h$HOST -P$PORT -u$USER -p$PASS radius -se "
            INSERT INTO radgroupreply (
              groupname,attribute,op,value
            ) 
            VALUES (
              '$groupName','Fall-Through','=','Yes'
            )"
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
        8 78 <<<$(echo "Group \"$groupName\" added.")
    fi
  fi
  optionsMenu
}

function deleteGroup {
  title="Remove an Existing Group"
  getActiveGroups
  groupName=$(
    whiptail --title "$title" --menu "\nChoose the group to delete." \
    25 78 16 "${activeGroupsArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if (whiptail --yesno "You are about to delete the group \"$groupName\". Continue?" \
          --title "$title" 8 78) then
      mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "
            DELETE FROM ugroup 
            WHERE ugroup_name = '$groupName'"
      mysql -h$HOST -P$PORT -u$USER -p$PASS radius -se "
            DELETE FROM radgroupreply
            WHERE groupname = '$groupName'"
      mysql -h$HOST -P$PORT -u$USER -p$PASS radius -se "
            DELETE FROM radusergroup
            WHERE groupname = '$groupName'"
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
        8 78 <<<$(echo "Group \"$groupName\" deleted.")
    fi
  fi
  optionsMenu
}

function usersToAddFunc {
  newUser=$(
    whiptail --inputbox "\nEnter a username to add to the \"$groupName\" group:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if [ -z "$newUser" ]; then
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "You must choose at least one user!")
      usersToAddFunc
    fi
    usersToAddArr+=("$newUser")
    unset newUser

    if (whiptail --yesno "Would you like to add another user to the \"$groupName\" group?" \
          --title "$title" 8 78) then
      usersToAddFunc
    fi
  fi
}

function addGroupMember {
  title="Add Users to Existing Group"
  getActiveGroups
  groupName=$(
    whiptail --title "$title" --menu "\nChoose the group to add members to." \
    25 78 16 "${activeGroupsArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    usersToAddArr=()
    usersToAddFunc
    for user in "${usersToAddArr[@]}"
    do
      userExists=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "
            SELECT count(*) 
            FROM user
            WHERE user_mail = '$user'"`
      if [ $userExists != "0" ]; then
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -se "
            INSERT INTO user_group (
              user_id,
              ugroup_id)
            VALUES (
              (SELECT user_id FROM user WHERE user_mail = '$user'),
              (SELECT ugroup_id FROM ugroup WHERE ugroup_name = '$groupName')
            )"
        mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "
            INSERT INTO radusergroup (
              username, groupname, priority
            )
            VALUES (
              '$user','$groupName',1
            )"
        whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "User \"$user\" successfully add to \"$groupName\" group.")
      else
        whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "User \"$user\" does not exist, skipping.")
      fi
    done
  fi
  optionsMenu
}

function usersToDelFunc {
  newUser=$(
  whiptail --inputbox "\nEnter a username to remove from the \"$groupName\" group:" 8 78 \
    --title "$title" 3>&1 1>&2 2>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    if [ -z "$newUser" ]; then
      whiptail --textbox --title "$title" --scrolltext /dev/stdin \
        8 78 <<<$(echo "You must choose at least one user!")
      usersToDelFunc
    fi
    usersToDelArr+=("$newUser")
    unset newUser
    if (whiptail --yesno "Would you like to remove another user from the \"$groupName\" group?" \
          --title "$title" 8 78) then
      usersToDelFunc
    fi
  fi
}

function deleteGroupMember {
  title="Remove Users from Existing Group"
  getActiveGroups
  groupName=$(
    whiptail --title "$title" --menu "\nChoose the group to delete members from." \
    25 78 16 "${activeGroupsArr[@]}" 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    usersToDelArr=()
    usersToDelFunc
    for user in "${usersToDelArr[@]}"
    do
      userExists=`mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -sNe "select count(*) 
        from user where user_mail = '$user'"`
      if [ $userExists != "0" ]; then
        mysql -h$HOST -P$PORT -u$USER -p$PASS $DB -e "
            DELETE FROM user_group 
            WHERE user_id = (
                SELECT user_id FROM user WHERE user_mail = '$user'
            )
            AND ugroup_id = (
                SELECT ugroup_id FROM ugroup WHERE ugroup_name = '$groupName'
            )"
        mysql -h$HOST -P$PORT -u$USER -p$PASS radius -e "
            DELETE FROM radusergroup 
            WHERE username = '$user'
            AND groupname = '$groupName'"
        whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "User \"$user\" successfully deleted from \"$groupName\" group.")
      else
        whiptail --textbox --title "$title" --scrolltext /dev/stdin \
          8 78 <<<$(echo "User \"$user\" does not exist, skipping.")
      fi
    done
  fi
  optionsMenu
}

function optionsMenu {
  opt=$(
    whiptail --title "GROUP MANAGEMENT OPTIONS" --menu "\nChoose an item to continue:" \
    25 78 16 \
    "Show Groups" "Show a list of existing groups." \
    "Show Group Members" "Show a list of users in an existing group." \
    "Show User Memberships" "List an existing users group membersips." \
    "Create a Group" "Add a new group." \
    "Delete a Group" "Remove an existing group." \
    "Add Group Members" "Add users to an existing group." \
    "Remove Group Members" "Remove users from an existing group." 3>&2 2>&1 1>&3
  )
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    case $opt in
      "Show Groups")
        showGroups
        ;;
      "Show Group Members")
        showGroupMembership
        ;;
      "Show User Memberships")
        showUserGroups
        ;;
      "Create a Group")
        addGroup
        ;;
      "Delete a Group")
        deleteGroup
        ;;
      "Add Group Members")
        addGroupMember
        ;;
      "Remove Group Members")
        deleteGroupMember
        ;;
    esac
  fi
}

optionsMenu
