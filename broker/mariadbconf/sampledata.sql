INSERT INTO `user` (`user_mail`, `user_start_date`, `user_end_date`) VALUES ("test@test.com", now(), now() + INTERVAL 50 year );
INSERT INTO `ugroup` (`ugroup_name`,`ugroup_description`) VALUES ('MYGROUP','This is a test group');
INSERT INTO `user_group` (`user_id`,`ugroup_id`) VALUES ( (select `user_id` from `user` where `user_mail` = "test@test.com"), (select `ugroup_id` from `ugroup` where `ugroup_name`="MYGROUP"));

INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('good','good');
INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('restricted','restricted');
INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('vip','vip');

INSERT INTO sdp_port (port_name,port_number) VALUES ('https','443');
INSERT INTO sdp_port (port_name,port_number) VALUES ('rdp','3389');
INSERT INTO sdp_port (port_name,port_number) VALUES ('ssh','22');
