#!/usr/bin/python3

import MySQLdb

HOST = "127.0.0.1"
PORT = 3306
USER = "sdpuser"
PASS = "sdpdbpass"
DB = "sdpdb"

while True:
    id, srchost, resource = input(">").split()
    try:
        db = MySQLdb.connect(host=(HOST),
            port=(PORT),
            user=(USER),
            passwd=(PASS),
            db=(DB))
        cursor = db.cursor()

        cursor.execute("""select user_id from squid_user_helper where log_remote_ip='%s'""" % (srchost) )
        username = cursor.fetchone()
        username = username[0]

        cursor.execute("""select count(*) from squid_rules_helper r, squid_group_helper u where r.resource_name='%s' and u.user='%s' and u.ugroup = r.ugroup_name""" % (resource, username) )
        permitted = cursor.fetchone()
        permitted = permitted[0]

        if permitted > 0:
            print(id + " OK user=" + username)
        else:
            print(id + " ERR user=" + username)
        db.close()
    except TypeError:
        print(id + " ERR user=")
        db.close()
