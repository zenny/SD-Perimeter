#!/usr/bin/python3

import MySQLdb
import sys

HOST = "127.0.0.1"
PORT = 3306
USER = "sdpuser"
PASS = "dvuiim69"
DB = "sdpdb"

while True:
    try:
        line = sys.stdin.readline().strip()
        arr = line.split()
        id = arr[0]
        srchost = arr[1]
        resource = arr[2]
    except IndexError:
        break

    db = MySQLdb.connect(host=(HOST),
        port=(PORT),
        user=(USER),
        passwd=(PASS),
        db=(DB))

    try:
        cursor = db.cursor()
        cursor.execute("""select user_id from squid_user_helper where log_remote_ip='%s'""" % (srchost) )
        username = cursor.fetchone()

        if resource == 'all_users':
            permitted = [1]
        else:
            cursor.execute("""select count(*) from squid_rules_helper r, squid_group_helper u where r.resource_name='%s' and u.user='%s' and u.ugroup = r.ugroup_name""" % (resource, username[0]) )
            permitted = cursor.fetchone()

        if permitted[0] > 0:
            #print(id + " OK user=" + username[0])
            sys.stdout.write(id + " OK user=" + username[0] + "\n")
        else:
            #print(id + " ERR user=" + username[0])
            sys.stdout.write(id + " ERR user=" + username[0] + "\n")
    except TypeError:
        #print(id + " ERR user=")
        sys.stdout.write(id + " ERR user=" + "\n")

    sys.stdout.flush()
    db.close()


