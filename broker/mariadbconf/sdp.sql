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
    `log_country_code` varchar(2) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_country_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_region` varchar(4) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_region_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_city` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_zip` varchar(8) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_timezone` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_lat` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_long` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_os` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
PRIMARY KEY (`log_id`),
KEY `user_id` (`user_id`)
);

CREATE OR REPLACE VIEW `squid_user_helper` AS 
    select `l`.`user_id` AS `user_id`,
        `l`.`log_remote_ip` AS `log_remote_ip`,
        substring_index(`l`.`user_id`,'@',-1) AS `domain`
    from `log` `l`, `user` `u` 
    where `l`.`log_end_time` = '0000-00-00 00:00:00'
    and `u`.`user_enable`='yes'
    and `u`.`user_mail`=`l`.`user_id`;

CREATE OR REPLACE VIEW `squid_group_helper` AS 
    select `u`.`user_mail` as `user_id`,
        `g`.`ugroup_name` as `ugroup_id`
    from `user` `u`, `ugroup` `g`, `user_group` `ug`
    where `u`.`user_id` = `ug`.`user_id` 
    and `g`.`ugroup_id` = `ug`.`ugroup_id`;

CREATE TABLE IF NOT EXISTS `gateway` (
    `gateway_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `gateway_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `gateway_ip` varchar(15) COLLATE utf8_unicode_ci DEFAULT NULL,
    `gateway_proxy_port` varchar(5) COLLATE utf8_unicode_ci DEFAULT NULL,
    `gateway_start_date` date NOT NULL,
    `gateway_end_date` date NOT NULL,
    `gateway_online` enum('yes','no') NOT NULL DEFAULT 'no',
    `gateway_enable` enum('yes','no') NOT NULL DEFAULT 'yes',
PRIMARY KEY (`gateway_id`),
CONSTRAINT UNIQUE (`gateway_name`),
CONSTRAINT UNIQUE (`gateway_ip`)
);

CREATE TABLE IF NOT EXISTS `gateway_log` (
    `log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `gateway_id` varchar(32) COLLATE utf8_unicode_ci NOT NULL,
    `log_trusted_ip` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_trusted_port` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_remote_ip` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_remote_port` varchar(16) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_start_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `log_end_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    `log_received` float NOT NULL DEFAULT '0',
    `log_send` float NOT NULL DEFAULT '0',
    `log_country_code` varchar(2) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_country_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_region` varchar(4) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_region_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_city` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_zip` varchar(8) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_timezone` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_lat` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
    `log_long` varchar(32) COLLATE utf8_unicode_ci DEFAULT NULL,
PRIMARY KEY (`log_id`),
KEY `gateway_id` (`gateway_id`)
);

CREATE TABLE IF NOT EXISTS `sdp_resource` (
    `resource_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `resource_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `resource_domain` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `resource_type` enum('web','tcp') NOT NULL DEFAULT 'web',
    `resource_enabled` enum('yes','no') NOT NULL DEFAULT 'yes',
    `resource_start_date` date NOT NULL,
    `resource_end_date` date NOT NULL,
PRIMARY KEY (`resource_id`)
);

CREATE TABLE IF NOT EXISTS `sdp_port` (
    `port_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `port_name` varchar(64) COLLATE utf8_unicode_ci DEFAULT NULL,
    `port_number` varchar(5) COLLATE utf8_unicode_ci DEFAULT NULL,
    `port_protocol` enum('tcp','udp') NOT NULL DEFAULT 'tcp',
PRIMARY KEY (`port_id`),
KEY `port_number` (`port_number`)
);

CREATE TABLE IF NOT EXISTS `sdp_resource_port` (
    `srp_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `resource_id` int(10) unsigned NOT NULL,
    `port_id` int(10) unsigned NOT NULL,
PRIMARY KEY (`srp_id`),
CONSTRAINT `fk_srp_resource_id` FOREIGN KEY (`resource_id`)
    REFERENCES `sdp_resource` (`resource_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT `fk_srp_port_id` FOREIGN KEY (`port_id`)
    REFERENCES `sdp_port` (`port_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS `sdp_gateway_resource` (
    `sgr_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `gateway_id` int(10) unsigned NOT NULL,
    `resource_id` int(10) unsigned NOT NULL,
PRIMARY KEY (`sgr_id`),
CONSTRAINT `fk_sgr_gateway_id` FOREIGN KEY (`gateway_id`)
    REFERENCES `gateway` (`gateway_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT `fk_sgr_resource_id` FOREIGN KEY (`resource_id`)
    REFERENCES `sdp_resource` (`resource_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS `sdp_resource_group` (
    `srg_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `resource_id` int(10) unsigned NOT NULL,
    `ugroup_id` int(10) unsigned NOT NULL,
PRIMARY KEY (`srg_id`),
CONSTRAINT `fk_srg_resource_id` FOREIGN KEY (`resource_id`)
    REFERENCES `sdp_resource` (`resource_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
CONSTRAINT `fk_srg_group_id` FOREIGN KEY (`ugroup_id`)
    REFERENCES `ugroup` (`ugroup_id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE OR REPLACE VIEW `resource_gateway_helper` AS
    select `r`.`resource_name`,
        `g`.`gateway_name`,
        `g`.`gateway_ip`
    from `sdp_resource` `r`,
        `gateway` `g`,
        `sdp_gateway_resource` `sgr`
    where `r`.`resource_id` = `sgr`.`resource_id`
    and `g`.`gateway_id` = `sgr`.`gateway_id`;

CREATE OR REPLACE VIEW `resource_rules_helper` AS
    select `r`.`resource_name`,
        `r`.`resource_domain`,
        `r`.`resource_type`,
        `p`.`port_name`,
        `p`.`port_number`,
        `g`.`ugroup_name`
    from `sdp_resource` `r`,
        `sdp_port` `p`,
        `ugroup` `g`,
        `sdp_resource_group` `srg`,
        `sdp_resource_port` `srp`
    where `r`.`resource_id` = `srg`.`resource_id`
    and `r`.`resource_id` = `srp`.`resource_id`
    and `p`.`port_id` = `srp`.`port_id`
    and `g`.`ugroup_id` = `srg`.`ugroup_id`;

CREATE OR REPLACE VIEW `squid_rules_helper` AS
    select `r`.`resource_name`,
        `r`.`resource_domain`,
        `r`.`resource_type`,
        GROUP_CONCAT(DISTINCT `p`.`port_number` SEPARATOR ' ') ports,
        GROUP_CONCAT(DISTINCT `gr`.`ugroup_name` SEPARATOR ' ') groups,
        `g`.`gateway_name`,
        `g`.`gateway_ip`
    from `sdp_resource` `r`,
        `sdp_port` `p`,
        `ugroup` `gr`,
        `sdp_resource_group` `srg`,
        `sdp_resource_port` `srp`,
        `gateway` `g`,
        `sdp_gateway_resource` `sgr`
    where `r`.`resource_id` = `srg`.`resource_id`
    and `r`.`resource_id` = `srp`.`resource_id`
    and `p`.`port_id` = `srp`.`port_id`
    and `gr`.`ugroup_id` = `srg`.`ugroup_id`
    and `r`.`resource_id` = `sgr`.`resource_id`
    and `g`.`gateway_id` = `sgr`.`gateway_id`;
