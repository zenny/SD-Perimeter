CREATE DATABASE openvpn;
USE openvpn;

CREATE TABLE IF NOT EXISTS `user` (
    `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `user_pass` varchar(32) COLLATE utf8_unicode_ci NOT NULL DEFAULT '1234',
    `user_mail` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `user_phone` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
    `user_start_date` date NOT NULL,
    `user_end_date` date NOT NULL,
    `user_online` enum('yes','no') NOT NULL DEFAULT 'no',
    `user_enable` enum('yes','no') NOT NULL DEFAULT 'yes',
PRIMARY KEY (`user_id`),
KEY `user_pass` (`user_pass`),
CONSTRAINT UNIQUE (`user_mail`)
);

CREATE TABLE IF NOT EXISTS `ugroup` (
    `ugroup_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `ugroup_name` varchar(64) COLLATE utf8_unicode_ci NOT NULL,
    `ugroup_description` varchar(128) COLLATE utf8_unicode_ci NOT NULL,
    `ugroup_enabled` enum('yes','no') NOT NULL DEFAULT 'yes',
PRIMARY KEY (`ugroup_id`),
KEY `ugroup_name` (`ugroup_name`),
CONSTRAINT UNIQUE (`ugroup_name`)
);

CREATE TABLE IF NOT EXISTS `user_group` (
    `user_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `user_id` int(10) unsigned NOT NULL,
    `ugroup_id` int(10) unsigned NOT NULL,
PRIMARY KEY (`user_group_id`),
CONSTRAINT `fk_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `user` (`user_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT `fk_ugroup_id` FOREIGN KEY (`ugroup_id`)
    REFERENCES `ugroup` (`ugroup_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS `log` (
    `log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `user_id` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
    `log_trusted_ip` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_trusted_port` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_remote_ip` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_remote_port` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_start_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `log_end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    `log_received` float NOT NULL DEFAULT '0',
    `log_send` float NOT NULL DEFAULT '0',
PRIMARY KEY (`log_id`),
KEY `user_id` (`user_id`)
);

CREATE VIEW IF NOT EXISTS `squid_user_helper` AS 
    select `l`.`user_id` AS `user_id`,
        `l`.`log_remote_ip` AS `log_remote_ip`,
        substring_index(`l`.`user_id`,'@',-1) AS `domain`
    from `log` `l`, `user` `u` 
    where `l`.`log_end_time` = '0000-00-00 00:00:00'
    and `u`.`user_enable`='yes'
    and `u`.`user_mail`=`l`.`user_id`;

CREATE VIEW IF NOT EXISTS `squid_group_helper` AS 
    select `u`.`user_mail` as `user_id`, 
        `g`.`ugroup_name` as `ugroup_id`
    from `user` `u`, `ugroup` `g`, `user_group` `ug`
    where `u`.`user_id` = `ug`.`user_id` 
    and `g`.`ugroup_id` = `ug`.`ugroup_id`;

INSERT INTO `user` (`user_mail`, `user_start_date`, `user_end_date`) VALUES ("test@test.com", now(), now() + INTERVAL 50 year );
INSERT INTO `ugroup` (`ugroup_name`,`ugroup_description`) VALUES ('MYGROUP','This is a test group');
INSERT INTO `user_group` (`user_id`,`ugroup_id`) VALUES ( (select `user_id` from `user` where `user_mail` = "test@test.com"), (select `ugroup_id` from `ugroup` where `ugroup_name`="MYGROUP"));
INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('good','good');
INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('restricted','restricted');
INSERT INTO ugroup (ugroup_name,ugroup_description) VALUES ('vip','vip');

