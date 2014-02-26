SET FOREIGN_KEY_CHECKS=0;
TRUNCATE servicegroups;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


LOCK TABLES `hosts` WRITE;
/*!40000 ALTER TABLE `hosts` DISABLE KEYS */;
INSERT INTO `hosts` (`id`, `name`, `ip`, `alias`, `notification_interval`, `hostgroup`, `check_period`, `check_interval`, `retry_check_interval`, `check_attempts`, `icon`, `enable_snmp`, `snmp_version`, `snmp_port`, `snmp_community`, `snmpv3_username`, `snmpv3_authprotocol`, `snmpv3_authpassword`, `snmpv3_privprotocol`, `snmpv3_privpassword`, `use_nmis`, `nmis_node_type`, `notification_options`, `notification_period`, `check_command`, `http_admin_url`, `http_admin_port`, `monitored_by`, `uncommitted`, `other_addresses`, `snmptrap_tracing`, `flap_detection_enabled`, `use_rancid`, `rancid_vendor`, `rancid_username`, `rancid_password`, `rancid_connection_type`, `rancid_autoenable`, `use_mrtg`, `tidy_ifdescr_level`, `snmp_max_msg_size`, `snmp_extended_throughput_data`, `event_handler`) VALUES (1,'opsview','localhost','Opsview Master Server',60,2,1,'5','1','2','LOGO - Opsview',0,'2c',161,'public','',NULL,'',NULL,'',0,'router','u,d,r',1,15,NULL,NULL,1,0,'',0,1,0,NULL,NULL,NULL,'ssh',0,0,0,0,0,'');
/*!40000 ALTER TABLE `hosts` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hostgroups` WRITE;
/*!40000 ALTER TABLE `hostgroups` DISABLE KEYS */;
INSERT INTO `hostgroups` (`id`, `parentid`, `name`, `lft`, `rgt`, `matpath`, `matpathid`, `uncommitted`) VALUES (1,NULL,'Opsview',1,4,'Opsview,','1,',0);
INSERT INTO `hostgroups` (`id`, `parentid`, `name`, `lft`, `rgt`, `matpath`, `matpathid`, `uncommitted`) VALUES (2,1,'Monitoring Servers',2,3,'Opsview,Monitoring Servers,','1,2,',0);
/*!40000 ALTER TABLE `hostgroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `timeperiods` WRITE;
/*!40000 ALTER TABLE `timeperiods` DISABLE KEYS */;
INSERT INTO `timeperiods` (`id`, `name`, `alias`, `sunday`, `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `uncommitted`) VALUES (1,'24x7','24 Hours A Day, 7 Days A Week','00:00-24:00','00:00-24:00','00:00-24:00','00:00-24:00','00:00-24:00','00:00-24:00','00:00-24:00',0);
INSERT INTO `timeperiods` (`id`, `name`, `alias`, `sunday`, `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `uncommitted`) VALUES (2,'workhours','Normal Working Hours','','09:00-17:00','09:00-17:00','09:00-17:00','09:00-17:00','09:00-17:00','',0);
INSERT INTO `timeperiods` (`id`, `name`, `alias`, `sunday`, `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `uncommitted`) VALUES (3,'nonworkhours','Non-work Hours','00:00-24:00','00:00-09:00,17:00-24:00','00:00-09:00,17:00-24:00','00:00-09:00,17:00-24:00','00:00-09:00,17:00-24:00','00:00-09:00,17:00-24:00','00:00-24:00',0);
INSERT INTO `timeperiods` (`id`, `name`, `alias`, `sunday`, `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `uncommitted`) VALUES (4,'none','None','','','','','','','',0);
/*!40000 ALTER TABLE `timeperiods` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hostcheckcommands` WRITE;
/*!40000 ALTER TABLE `hostcheckcommands` DISABLE KEYS */;
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (1,'slow ping','check_ping','-H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -p 1',14,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (2,'tcp port 80 (HTTP)','check_tcp','-H $HOSTADDRESS$ -p 80 -w 9 -c 9 -t 15',7,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (3,'tcp port 22 (SSH)','check_ssh','-H $HOSTADDRESS$ -t 15',4,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (4,'tcp port 23 (Telnet)','check_tcp','-H $HOSTADDRESS$ -p 23 -w 9 -c 9 -t 15',5,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (5,'tcp port 443 (HTTP/SSL)','check_tcp','-H $HOSTADDRESS$ -p 443 -w 9 -c 9 -t 15',9,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (7,'NRPE (on port 5666)','check_nrpe','-H $HOSTADDRESS$',11,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (8,'tcp port 135 (MS RPC)','check_tcp','-H $HOSTADDRESS$ -p 135 -w 9 -c 9 -t 15',8,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (10,'tcp port 5900 (VNC)','check_tcp','-H $HOSTADDRESS$ -p 5900 -w 9 -c 9 -t 15',10,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (11,'NRPE (on port 5666 - non-SSL)','check_nrpe','-n -H $HOSTADDRESS$',12,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (12,'tcp port 25 (SMTP)','check_tcp','-H $HOSTADDRESS$ -p 25 -w 9 -c 9 -t 15',6,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (13,'tcp port 21 (FTP)','check_tcp','-H $HOSTADDRESS$ -p 21 -w 9 -c 9 -t 15',3,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (14,'tcp port 161 (SNMP)','check_tcp','-H $HOSTADDRESS$ -p 161 -w 9 -c 9 -t 15',13,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (15,'ping','check_icmp','-H $HOSTADDRESS$ -t 3 -w 500.0,80% -c 1000.0,100%',2,0);
INSERT INTO `hostcheckcommands` (`id`, `name`, `plugin`, `args`, `priority`, `uncommitted`) VALUES (16,'tolerant ping','check_host','-H $HOSTADDRESS$ -n 5 -i 5s',15,0);
/*!40000 ALTER TABLE `hostcheckcommands` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `monitoringservers` WRITE;
/*!40000 ALTER TABLE `monitoringservers` DISABLE KEYS */;
INSERT INTO `monitoringservers` (`id`, `name`, `host`, `role`, `activated`, `passive`, `uncommitted`) VALUES (1,'Master Monitoring Server',1,'Master',1,0,0);
/*!40000 ALTER TABLE `monitoringservers` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationmethods` WRITE;
/*!40000 ALTER TABLE `notificationmethods` DISABLE KEYS */;
INSERT INTO `notificationmethods` (`id`, `active`, `name`, `namespace`, `master`, `command`, `priority`, `uncommitted`, `contact_variables`) VALUES (1,1,'AQL','com.opsview.notificationmethods.aql',0,'submit_sms_aql',2,0,'PAGER');
INSERT INTO `notificationmethods` (`id`, `active`, `name`, `namespace`, `master`, `command`, `priority`, `uncommitted`, `contact_variables`) VALUES (2,0,'SMS Notification Module','com.opsview.notificationmethods.smsgateway',1,'submit_sms_script',2,0,'PAGER');
INSERT INTO `notificationmethods` (`id`, `active`, `name`, `namespace`, `master`, `command`, `priority`, `uncommitted`, `contact_variables`) VALUES (3,1,'Email','com.opsview.notificationmethods.email',1,'notify_by_email',1,0,'EMAIL');
INSERT INTO `notificationmethods` (`id`, `active`, `name`, `namespace`, `master`, `command`, `priority`, `uncommitted`, `contact_variables`) VALUES (4,1,'RSS','com.opsview.notificationmethods.rss',1,'notify_by_rss',1,0,'RSS_MAXIMUM_ITEMS,RSS_MAXIMUM_AGE,RSS_COLLAPSED');
INSERT INTO `notificationmethods` (`id`, `active`, `name`, `namespace`, `master`, `command`, `priority`, `uncommitted`, `contact_variables`) VALUES (5,1,'Push Notifications For IOS Mobile','com.opsview.notificationmethods.iospush',1,'notify_by_ios_push',1,0,NULL);
/*!40000 ALTER TABLE `notificationmethods` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationprofiles` WRITE;
/*!40000 ALTER TABLE `notificationprofiles` DISABLE KEYS */;
INSERT INTO `notificationprofiles` (`id`, `name`, `contactid`, `host_notification_options`, `service_notification_options`, `notification_period`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `notification_level`, `priority`, `uncommitted`, `notification_level_stop`) VALUES (1,'Default',1,'u,d,r,f','w,c,r,f',1,1,1,1,1,1,0,0);
/*!40000 ALTER TABLE `notificationprofiles` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationprofile_hostgroups` WRITE;
/*!40000 ALTER TABLE `notificationprofile_hostgroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificationprofile_hostgroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationprofile_servicegroups` WRITE;
/*!40000 ALTER TABLE `notificationprofile_servicegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificationprofile_servicegroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationprofile_keywords` WRITE;
/*!40000 ALTER TABLE `notificationprofile_keywords` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificationprofile_keywords` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `notificationprofile_notificationmethods` WRITE;
/*!40000 ALTER TABLE `notificationprofile_notificationmethods` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificationprofile_notificationmethods` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicegroups` WRITE;
/*!40000 ALTER TABLE `servicegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicegroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `contacts` WRITE;
/*!40000 ALTER TABLE `contacts` DISABLE KEYS */;
INSERT INTO `contacts` (`id`, `fullname`, `name`, `realm`, `encrypted_password`, `language`, `description`, `role`, `show_welcome_page`, `uncommitted`) VALUES (1,'Administrator','admin','local','$apr1$SUR3Kcd8$CkJfpqvqy3r.6rzawNwCS.','','System Administrator',10,1,0);
/*!40000 ALTER TABLE `contacts` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `contact_variables` WRITE;
/*!40000 ALTER TABLE `contact_variables` DISABLE KEYS */;
INSERT INTO `contact_variables` (`contactid`, `name`, `value`) VALUES (1,'EMAIL','');
INSERT INTO `contact_variables` (`contactid`, `name`, `value`) VALUES (1,'PAGER','');
INSERT INTO `contact_variables` (`contactid`, `name`, `value`) VALUES (1,'RSS_COLLAPSED','1');
INSERT INTO `contact_variables` (`contactid`, `name`, `value`) VALUES (1,'RSS_MAXIMUM_AGE','1440');
INSERT INTO `contact_variables` (`contactid`, `name`, `value`) VALUES (1,'RSS_MAXIMUM_ITEMS','30');
/*!40000 ALTER TABLE `contact_variables` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hosttemplates` WRITE;
/*!40000 ALTER TABLE `hosttemplates` DISABLE KEYS */;
/*!40000 ALTER TABLE `hosttemplates` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hosthosttemplates` WRITE;
/*!40000 ALTER TABLE `hosthosttemplates` DISABLE KEYS */;
/*!40000 ALTER TABLE `hosthosttemplates` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicechecks` WRITE;
/*!40000 ALTER TABLE `servicechecks` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicechecks` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicecheckdependencies` WRITE;
/*!40000 ALTER TABLE `servicecheckdependencies` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicecheckdependencies` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hostservicechecks` WRITE;
/*!40000 ALTER TABLE `hostservicechecks` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostservicechecks` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hosttemplateservicechecks` WRITE;
/*!40000 ALTER TABLE `hosttemplateservicechecks` DISABLE KEYS */;
/*!40000 ALTER TABLE `hosttemplateservicechecks` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `snmptraps` WRITE;
/*!40000 ALTER TABLE `snmptraps` DISABLE KEYS */;
/*!40000 ALTER TABLE `snmptraps` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicecheckhostexceptions` WRITE;
/*!40000 ALTER TABLE `servicecheckhostexceptions` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicecheckhostexceptions` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicechecktimedoverridehostexceptions` WRITE;
/*!40000 ALTER TABLE `servicechecktimedoverridehostexceptions` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicechecktimedoverridehostexceptions` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicecheckhosttemplateexceptions` WRITE;
/*!40000 ALTER TABLE `servicecheckhosttemplateexceptions` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicecheckhosttemplateexceptions` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicechecktimedoverridehosttemplateexceptions` WRITE;
/*!40000 ALTER TABLE `servicechecktimedoverridehosttemplateexceptions` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicechecktimedoverridehosttemplateexceptions` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `snmptraprules` WRITE;
/*!40000 ALTER TABLE `snmptraprules` DISABLE KEYS */;
/*!40000 ALTER TABLE `snmptraprules` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `keywords` WRITE;
/*!40000 ALTER TABLE `keywords` DISABLE KEYS */;
/*!40000 ALTER TABLE `keywords` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `keywordhosts` WRITE;
/*!40000 ALTER TABLE `keywordhosts` DISABLE KEYS */;
/*!40000 ALTER TABLE `keywordhosts` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `keywordservicechecks` WRITE;
/*!40000 ALTER TABLE `keywordservicechecks` DISABLE KEYS */;
/*!40000 ALTER TABLE `keywordservicechecks` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `systempreferences` WRITE;
/*!40000 ALTER TABLE `systempreferences` DISABLE KEYS */;
INSERT INTO `systempreferences` (`id`, `default_statusmap_layout`, `default_statuswrl_layout`, `refresh_rate`, `log_notifications`, `log_service_retries`, `log_host_retries`, `log_event_handlers`, `log_initial_states`, `log_external_commands`, `log_passive_checks`, `daemon_dumps_core`, `audit_log_retention`, `hostgroup_info_url`, `host_info_url`, `service_info_url`, `enable_odw_import`, `enable_full_odw_import`, `odw_large_retention_months`, `odw_small_retention_months`, `opsview_server_name`, `soft_state_dependencies`, `show_timeline`, `smart_hosttemplate_removal`, `rancid_email_notification`, `viewport_summary_style`, `send_anon_data`, `uuid`, `netdisco_url`, `updates_includemajor`, `date_format`, `set_downtime_on_host_delete`) VALUES (1,4,2,30,1,1,1,1,0,1,0,0,365,'','','',0,0,2,12,'',1,1,0,NULL,'list',1,'','',1,'iso8601',1);
/*!40000 ALTER TABLE `systempreferences` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hostserviceeventhandlers` WRITE;
/*!40000 ALTER TABLE `hostserviceeventhandlers` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostserviceeventhandlers` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `hosttemplatemanagementurls` WRITE;
/*!40000 ALTER TABLE `hosttemplatemanagementurls` DISABLE KEYS */;
/*!40000 ALTER TABLE `hosttemplatemanagementurls` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `parents` WRITE;
/*!40000 ALTER TABLE `parents` DISABLE KEYS */;
/*!40000 ALTER TABLE `parents` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `servicechecksnmppolling` WRITE;
/*!40000 ALTER TABLE `servicechecksnmppolling` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicechecksnmppolling` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (1,'Public','Access available for public users',0,0,0,0,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (2,'Authenticated user','All authenticated users inherit this role',0,0,0,0,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (10,'Administrator','Administrator access',1,1,1,1,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (11,'View all, change some','Operator',2,0,0,0,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (12,'View some, change some','Restricted operator',4,0,0,0,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (13,'View all, change none','Read only user',3,0,0,0,0);
INSERT INTO `roles` (`id`, `name`, `description`, `priority`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `uncommitted`) VALUES (14,'View some, change none','Restricted read only user',5,0,0,0,0);
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `roles_access` WRITE;
/*!40000 ALTER TABLE `roles_access` DISABLE KEYS */;
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (1,10);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (2,11);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,1);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,3);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,6);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,7);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,8);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,9);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,10);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,11);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,12);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,13);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,14);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,15);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,16);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,18);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,19);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,20);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,21);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,23);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,27);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,28);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,29);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (10,30);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,1);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,4);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,6);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,14);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,17);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,22);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (11,30);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,2);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,4);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,6);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,14);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,17);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,22);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (12,30);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (13,1);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (13,6);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (13,14);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (13,30);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (14,2);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (14,6);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (14,14);
INSERT INTO `roles_access` (`roleid`, `accessid`) VALUES (14,30);
/*!40000 ALTER TABLE `roles_access` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `roles_monitoringservers` WRITE;
/*!40000 ALTER TABLE `roles_monitoringservers` DISABLE KEYS */;
/*!40000 ALTER TABLE `roles_monitoringservers` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `roles_hostgroups` WRITE;
/*!40000 ALTER TABLE `roles_hostgroups` DISABLE KEYS */;
INSERT INTO `roles_hostgroups` (`roleid`, `hostgroupid`) VALUES (10,1);
/*!40000 ALTER TABLE `roles_hostgroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `role_access_hostgroups` WRITE;
/*!40000 ALTER TABLE `role_access_hostgroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `role_access_hostgroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `role_access_servicegroups` WRITE;
/*!40000 ALTER TABLE `role_access_servicegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `role_access_servicegroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `role_access_keywords` WRITE;
/*!40000 ALTER TABLE `role_access_keywords` DISABLE KEYS */;
/*!40000 ALTER TABLE `role_access_keywords` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `attributes` WRITE;
/*!40000 ALTER TABLE `attributes` DISABLE KEYS */;
INSERT INTO `attributes` (`id`, `name`, `internally_generated`, `label1`, `label2`, `label3`, `label4`, `label5`, `label6`, `label7`, `label8`, `label9`, `uncommitted`, `value`, `arg1`, `arg2`, `arg3`, `arg4`, `arg5`, `arg6`, `arg7`, `arg8`, `arg9`) VALUES (1,'SLAVENODE',1,'','','','','','','','','',0,'','','','','','','','','','');
INSERT INTO `attributes` (`id`, `name`, `internally_generated`, `label1`, `label2`, `label3`, `label4`, `label5`, `label6`, `label7`, `label8`, `label9`, `uncommitted`, `value`, `arg1`, `arg2`, `arg3`, `arg4`, `arg5`, `arg6`, `arg7`, `arg8`, `arg9`) VALUES (3,'CLUSTERNODE',1,'','','','','','','','','',0,'','','','','','','','','','');
INSERT INTO `attributes` (`id`, `name`, `internally_generated`, `label1`, `label2`, `label3`, `label4`, `label5`, `label6`, `label7`, `label8`, `label9`, `uncommitted`, `value`, `arg1`, `arg2`, `arg3`, `arg4`, `arg5`, `arg6`, `arg7`, `arg8`, `arg9`) VALUES (5,'URL',0,'','','','','','','','','',0,'','','','','','','','','','');
INSERT INTO `attributes` (`id`, `name`, `internally_generated`, `label1`, `label2`, `label3`, `label4`, `label5`, `label6`, `label7`, `label8`, `label9`, `uncommitted`, `value`, `arg1`, `arg2`, `arg3`, `arg4`, `arg5`, `arg6`, `arg7`, `arg8`, `arg9`) VALUES (6,'PROCESSES',0,'','','','','','','','','',0,'','','','','','','','','','');
INSERT INTO `attributes` (`id`, `name`, `internally_generated`, `label1`, `label2`, `label3`, `label4`, `label5`, `label6`, `label7`, `label8`, `label9`, `uncommitted`, `value`, `arg1`, `arg2`, `arg3`, `arg4`, `arg5`, `arg6`, `arg7`, `arg8`, `arg9`) VALUES (7,'NRPE_PORT',0,'','','','','','','','','',0,'','','','','','','','','','');
/*!40000 ALTER TABLE `attributes` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `host_attributes` WRITE;
/*!40000 ALTER TABLE `host_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `host_attributes` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `modules` WRITE;
/*!40000 ALTER TABLE `modules` DISABLE KEYS */;
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (1,'Nagvis','/modules/nagvis','Nagios Core Visualisation','NAGVIS',1,1,'','com.opsview.modules.nagvis',1);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (2,'MRTG','/status/network_traffic','Multi Router Traffic Grapher','',1,2,'','com.opsview.modules.mrtg',1);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (3,'NMIS','/cgi-nmis/nmiscgi.pl','Network Management Information System','ADMINACCESS',0,3,'','com.opsview.modules.nmis',1);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (4,'Reports','http://www.opsview.com/products/enterprise-modules/reports','Opsview Reports Module','REPORTUSER',1,4,'','com.opsview.modules.reports',0);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (5,'Service Desk Connector','http://www.opsview.com/products/enterprise-modules/service-desk-connector','Opsview Service Desk Connector','ADMINACCESS',1,5,'','com.opsview.modules.servicedesk',0);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (6,'SMS Messaging','http://www.opsview.com/products/enterprise-modules/sms-messaging','Opsview SMS Messaging','ADMINACCESS',1,6,'','com.opsview.modules.smsmessaging',0);
INSERT INTO `modules` (`id`, `name`, `url`, `description`, `access`, `enabled`, `priority`, `version`, `namespace`, `installed`) VALUES (7,'Netaudit','http://www.opsview.com/products/enterprise-modules/netaudit-rancid','Opsview Netaudit','ADMINACCESS',1,7,'','com.opsview.modules.rancid',0);
/*!40000 ALTER TABLE `modules` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `sharednotificationprofiles` WRITE;
/*!40000 ALTER TABLE `sharednotificationprofiles` DISABLE KEYS */;
INSERT INTO `sharednotificationprofiles` (`id`, `name`, `host_notification_options`, `service_notification_options`, `notification_period`, `all_hostgroups`, `all_servicegroups`, `all_keywords`, `notification_level`, `role`, `uncommitted`, `notification_level_stop`) VALUES (1,'Receive all alerts during work hours','u,d,r,f','w,c,r,f',2,1,1,1,1,10,0,0);
/*!40000 ALTER TABLE `sharednotificationprofiles` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `sharednotificationprofile_hostgroups` WRITE;
/*!40000 ALTER TABLE `sharednotificationprofile_hostgroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `sharednotificationprofile_hostgroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `sharednotificationprofile_servicegroups` WRITE;
/*!40000 ALTER TABLE `sharednotificationprofile_servicegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `sharednotificationprofile_servicegroups` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `sharednotificationprofile_keywords` WRITE;
/*!40000 ALTER TABLE `sharednotificationprofile_keywords` DISABLE KEYS */;
/*!40000 ALTER TABLE `sharednotificationprofile_keywords` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `sharednotificationprofile_notificationmethods` WRITE;
/*!40000 ALTER TABLE `sharednotificationprofile_notificationmethods` DISABLE KEYS */;
/*!40000 ALTER TABLE `sharednotificationprofile_notificationmethods` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `contact_sharednotificationprofile` WRITE;
/*!40000 ALTER TABLE `contact_sharednotificationprofile` DISABLE KEYS */;
INSERT INTO `contact_sharednotificationprofile` (`contactid`, `sharednotificationprofileid`, `priority`) VALUES (1,1,1000);
/*!40000 ALTER TABLE `contact_sharednotificationprofile` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

SET FOREIGN_KEY_CHECKS=1;
