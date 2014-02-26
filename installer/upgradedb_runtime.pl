#!/usr/bin/perl
#
#
# SYNTAX:
# 	upgradedb_runtime.pl
#
# DESCRIPTION:
# 	Connects to runtime DB and upgrades it to the latest level
#
#	Warning!!!! This file must be kept up to date with db_runtime
#
#	Warning #2 !!! Only use DBI commands - no Class::DBI allowed
#
#	Warning #3 Currently this works by running custom changes first
#		then the NDO supplied schema changes. It maybe that in future
#		we need to do one followed by the other. May only become
#		apparent when updating through multiple versions
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

use strict;
use Getopt::Std;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Runtime;
use Utils::DBVersion;
use Opsview::Config;

# Do not use Class::DBI methods to amend data

my $dbh                 = Runtime->db_Main;
my $db_changed          = 0;
my $nagios_schema_table = "nagios_schema_version";

my $stop_point = shift @ARGV || "";

# Set no stdout buffering, needed due to top level tee
$| = 1;

print "Upgrading Nagios part of Runtime database", $/;

{
    local $dbh->{RaiseError}; # Turn off to ignore error
    local $dbh->{PrintError};
    my $value = $dbh->selectrow_array(
        "SELECT major_release,version FROM $nagios_schema_table"
    );
    unless ($value) {
        $dbh->do(
            "CREATE TABLE $nagios_schema_table (major_release varchar(16), version varchar(16)) ENGINE=InnoDB"
        );
        $dbh->do( "INSERT $nagios_schema_table VALUES ('2.10','0')" );
    }
}

# Because of a silly bug in the nagios_schema_table check above, remove irrelevant entries
my $highest_version = $dbh->selectrow_array(
    "SELECT MAX(version) FROM $nagios_schema_table WHERE major_release='2.10'"
);
$dbh->do( "DELETE FROM $nagios_schema_table WHERE major_release='2.10'" );
$dbh->do( "INSERT $nagios_schema_table VALUES ('2.10', $highest_version)" );

my $nagios_db = Utils::DBVersion->new(
    {
        dbh          => $dbh,
        schema_table => $nagios_schema_table,
        stop_point   => $stop_point,
        name         => "runtime-nagios"
    }
);

if ( $nagios_db->is_lower("2.10.1") ) {

    # equates to mysql-upgrade-1.4b3.sql
    $dbh->do(
        "ALTER TABLE `nagios_notifications` ADD `notification_number` SMALLINT( 6 ) DEFAULT '0' NOT NULL AFTER `notification_reason`"
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.0.1") ) {

    # equates to mysql-upgrade-1.4b4.sql up to 1.4b7.sql
    # But we will move all the table engine changes here first and then do the structure changes later
    # This part could fail if not enough disk space, so make this re-runnable

    $nagios_db->print(
        "Converting tables to Innodb - this could take a long time\n"
    );

    # Truncate this table, as could be large and data is not useful
    $dbh->do( qq{TRUNCATE nagios_conninfo} );

    $dbh->do( qq{ALTER TABLE `nagios_acknowledgements` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_commands` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_commenthistory` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_comments` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_configfiles` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_configfilevariables` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_conninfo` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_contact_addresses` ENGINE=InnoDB} );
    $dbh->do(
        qq{ALTER TABLE `nagios_contact_notificationcommands` ENGINE=InnoDB}
    );
    $dbh->do( qq{ALTER TABLE `nagios_contactgroup_members` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_contactgroups` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_contactnotificationmethods` ENGINE=InnoDB}
    );
    $dbh->do( qq{ALTER TABLE `nagios_contactnotifications` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_contacts` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_contactstatus` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_customvariables` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_customvariablestatus` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_dbversion` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_downtimehistory` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_eventhandlers` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_externalcommands` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_flappinghistory` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_host_contacts` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_host_parenthosts` ENGINE=InnoDB} );

    # Delete data older than 1 day, to reduce time spent converting
    my $one_day_cutoff =
      $dbh->selectrow_array( "SELECT (NOW() - INTERVAL 1 DAY) FROM DUAL" );
    $dbh->do( qq{DELETE FROM `nagios_hostchecks` WHERE start_time <= ?},
        {}, $one_day_cutoff );
    $dbh->do( qq{ALTER TABLE `nagios_hostchecks` ENGINE=InnoDB} );

    $dbh->do( qq{ALTER TABLE `nagios_hostdependencies` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hostescalation_contacts` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hostescalations` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hostgroup_members` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hostgroups` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hosts` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_hoststatus` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_instances` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_logentries` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_notifications` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_objects` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_processevents` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_programstatus` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_runtimevariables` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_scheduleddowntime` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_service_contacts` ENGINE=InnoDB} );

    # Delete data older than 1 day, to reduce time spent converting
    # Service check results are saved in ODW
    $dbh->do( qq{DELETE FROM `nagios_servicechecks` WHERE start_time <= ?},
        {}, $one_day_cutoff );
    $dbh->do( qq{ALTER TABLE `nagios_servicechecks` ENGINE=InnoDB} );

    $dbh->do( qq{ALTER TABLE `nagios_servicedependencies` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_serviceescalation_contacts` ENGINE=InnoDB}
    );
    $dbh->do( qq{ALTER TABLE `nagios_serviceescalations` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_servicegroup_members` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_servicegroups` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_services` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_servicestatus` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_statehistory` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_systemcommands` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_timedeventqueue` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_timedevents` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_timeperiod_timeranges` ENGINE=InnoDB} );
    $dbh->do( qq{ALTER TABLE `nagios_timeperiods` ENGINE=InnoDB} );

    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.0.2") ) {

    # More out of order changes, but only adding indexes
    # This part could fail if not enough disk space, so make this re-runnable
    # Some indexes have been ignored

    $nagios_db->print( "Recreating indexes - this could take a long time\n" );

    drop_index_quietly( $dbh, "nagios_configfilevariables", "instance_id" );

    # We reorganise this to be a better index
    $dbh->do(
        qq{ALTER TABLE `nagios_configfilevariables` ADD UNIQUE INDEX `instance_id` ( `configfile_id`, `varname`, `instance_id` ) }
    );

    drop_index_quietly( $dbh, "nagios_statehistory", "instance_id" );

    # Ignore this - not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_statehistory` ADD INDEX ( `instance_id` , `object_id` ) } );

    drop_index_quietly( $dbh, "nagios_servicestatus", "instance_id" );

    # Ignore this - not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `instance_id` , `service_object_id` ) } );

    drop_index_quietly( $dbh, "nagios_processevents", "instance_id" );
    drop_index_quietly( $dbh, "nagios_processevents", "event_time" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_processevents` ADD INDEX ( `event_time` , `event_time_usec` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_processevents` ADD INDEX ( `instance_id` , `event_type` ) } );

    # This one is not useful as the index on host_object_id is much more disbursed
    #drop_index_quietly( $dbh, "nagios_hoststatus", "instance_id" );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `instance_id` , `host_object_id` ) } );

    drop_index_quietly( $dbh, "nagios_flappinghistory", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_flappinghistory` ADD INDEX ( `instance_id` , `object_id` ) } );

    drop_index_quietly( $dbh, "nagios_externalcommands", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_externalcommands` ADD INDEX ( `instance_id` ) } );

    drop_index_quietly( $dbh, "nagios_customvariablestatus", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_customvariablestatus` ADD INDEX ( `instance_id` ) } );

    drop_index_quietly( $dbh, "nagios_contactstatus", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_contactstatus` ADD INDEX ( `instance_id` ) } );

    drop_index_quietly( $dbh, "nagios_conninfo", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_conninfo` ADD INDEX ( `instance_id` ) } );

    drop_index_quietly( $dbh, "nagios_acknowledgements", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_acknowledgements` ADD INDEX ( `instance_id` , `object_id` ) } );

    drop_index_quietly( $dbh, "nagios_objects", "instance_id" );

    # Ignoring as not in ndoutils' create script
    #$dbh->do( qq{ALTER TABLE `nagios_objects` ADD INDEX ( `instance_id` ) } );

    $nagios_db->print(
        "Converting data fields to TEXT - this could take a long time\n"
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_commenthistory` CHANGE `comment_data` `comment_data` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_comments` CHANGE `comment_data` `comment_data` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_downtimehistory` CHANGE `comment_data` `comment_data` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_externalcommands` CHANGE `command_args` `command_args` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_hostchecks` CHANGE `output` `output` TEXT NOT NULL, CHANGE `perfdata` `perfdata` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_hoststatus` CHANGE `output` `output` TEXT NOT NULL, CHANGE `perfdata` `perfdata` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_logentries` CHANGE `logentry_data` `logentry_data` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_scheduleddowntime` CHANGE `comment_data` `comment_data` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_servicechecks` CHANGE `output` `output` TEXT NOT NULL, CHANGE `perfdata` `perfdata` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_servicestatus` CHANGE `output` `output` TEXT NOT NULL, CHANGE `perfdata` `perfdata` TEXT NOT NULL }
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_statehistory` CHANGE `output` `output` TEXT NOT NULL }
    );

    # We ignore all these indexes as I don't think they help
    # A possible speed up is a covering index, but at the moment, can find the row very quickly
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `current_state` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `state_type` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `last_check` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `notifications_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `problem_has_been_acknowledged` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `passive_checks_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `active_checks_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `event_handler_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `flap_detection_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `is_flapping` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_hoststatus` ADD INDEX ( `scheduled_downtime_depth` ) } );

    # Ditto for servicestatus
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `current_state` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `last_check` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `notifications_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `problem_has_been_acknowledged` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `passive_checks_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `active_checks_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `event_handler_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `flap_detection_enabled` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `is_flapping` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_servicestatus` ADD INDEX ( `scheduled_downtime_depth` ) } );

    # We already create an index here of state_time, so ignore this one too
    #$dbh->do( qq{ALTER TABLE `nagios_statehistory` ADD INDEX ( `state_time` , `state_time_usec` ) } );

    drop_index_quietly( $dbh, "nagios_timedeventqueue", "instance_id" );
    drop_index_quietly( $dbh, "nagios_timedeventqueue", "event_type" );
    drop_index_quietly( $dbh, "nagios_timedeventqueue", "scheduled_time" );

    # We ignore these indexes for the moment. Look like they are not in the original create script in ndoutils
    #$dbh->do( qq{ALTER TABLE `nagios_timedeventqueue` ADD INDEX ( `event_type` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_timedeventqueue` ADD INDEX ( `scheduled_time` ) } );

    drop_index_quietly( $dbh, "nagios_logentries", "instance_id" );
    drop_index_quietly( $dbh, "nagios_logentries", "logentry_time" );
    drop_index_quietly( $dbh, "nagios_logentries", "entry_time" );

    # Ignoring as not in create script
    #$dbh->do( qq{ALTER TABLE `nagios_logentries` ADD INDEX ( `instance_id` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_logentries` ADD INDEX ( `logentry_time` ) } );
    #$dbh->do( qq{ALTER TABLE `nagios_logentries` ADD INDEX ( `entry_time` ) } );

    # Can't see the point of the one below
    #$dbh->do( qq{ALTER TABLE `nagios_logentries` ADD INDEX ( `entry_time_usec` ) } );

    # We already create this
    #$dbh->do( qq{ALTER TABLE `nagios_externalcommands` ADD INDEX ( `entry_time` ) } );

    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.0.3") ) {

    # equates to mysql-upgrade-1.4b4.sql up to 1.4b7.sql
    # Do structural changes here
    $dbh->do(
        qq{
CREATE TABLE IF NOT EXISTS `nagios_host_contactgroups` (
  `host_contactgroup_id` int(11) NOT NULL auto_increment,
  `instance_id` smallint(6) NOT NULL default '0',
  `host_id` int(11) NOT NULL default '0',
  `contactgroup_object_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`host_contactgroup_id`),
  UNIQUE KEY `instance_id` (`host_id`,`contactgroup_object_id`)
) ENGINE=InnoDB COMMENT='Host contact groups'
}
    );
    $dbh->do(
        qq{
CREATE TABLE IF NOT EXISTS `nagios_hostescalation_contactgroups` (
  `hostescalation_contactgroup_id` int(11) NOT NULL auto_increment,
  `instance_id` smallint(6) NOT NULL default '0',
  `hostescalation_id` int(11) NOT NULL default '0',
  `contactgroup_object_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`hostescalation_contactgroup_id`),
  UNIQUE KEY `instance_id` (`hostescalation_id`,`contactgroup_object_id`)
) ENGINE=InnoDB COMMENT='Host escalation contact groups'
}
    );
    $dbh->do(
        qq{
CREATE TABLE IF NOT EXISTS `nagios_service_contactgroups` (
  `service_contactgroup_id` int(11) NOT NULL auto_increment,
  `instance_id` smallint(6) NOT NULL default '0',
  `service_id` int(11) NOT NULL default '0',
  `contactgroup_object_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`service_contactgroup_id`),
  UNIQUE KEY `instance_id` (`service_id`,`contactgroup_object_id`)
) ENGINE=InnoDB COMMENT='Service contact groups'
}
    );
    $dbh->do(
        qq{
CREATE TABLE IF NOT EXISTS `nagios_serviceescalation_contactgroups` (
  `serviceescalation_contactgroup_id` int(11) NOT NULL auto_increment,
  `instance_id` smallint(6) NOT NULL default '0',
  `serviceescalation_id` int(11) NOT NULL default '0',
  `contactgroup_object_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`serviceescalation_contactgroup_id`),
  UNIQUE KEY `instance_id` (`serviceescalation_id`,`contactgroup_object_id`)
) ENGINE=InnoDB COMMENT='Service escalation contact groups';
}
    );

    $nagios_db->print(
        "Adding new column to nagios_statehistory - this could take some time\n"
    );
    $dbh->do(
        qq{ALTER TABLE `nagios_statehistory` ADD `last_state` SMALLINT DEFAULT '-1' NOT NULL AFTER `max_check_attempts` , ADD `last_hard_state` SMALLINT DEFAULT '-1' NOT NULL AFTER `last_state`}
    );

    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.0.4") ) {

    # We work out the direction of the time shifts so we can apply changes in an order that avoids clashing the unique keys
    # This direction could be a problem if a timezone difference is +30 mins in daylights saving time and then -30 mins, but I don't
    # think there's any timezones like this
    my $offset = $dbh->selectrow_array(
        "select UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(CONVERT_TZ(NOW(), 'SYSTEM', '+00:00')) from dual"
    );

    # So offset is the usual time difference between UTC and timezone. Since we are converting from timezone to UTC,
    # we update rows in the opposite direction to the offset
    my $order_direction = 'ASC';
    if ( $offset < 0 ) {
        $order_direction = 'DESC';
    }

    sub ptable {
        my $text = shift;
        my $time = scalar localtime;
        $nagios_db->print( "$time $text\n" );
    }
    $nagios_db->print(
        "Changing all time values to UTC timezone. This could take a long time\n"
    );
    ptable( "Acknowledgements" );
    $dbh->do(
        "UPDATE nagios_acknowledgements SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00')"
    );
    ptable( "Comments history" );
    $dbh->do(
        "UPDATE nagios_commenthistory SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00'), comment_time=CONVERT_TZ(comment_time,'SYSTEM','+00:00'), expiration_time=CONVERT_TZ(expiration_time,'SYSTEM','+00:00'), deletion_time=CONVERT_TZ(deletion_time,'SYSTEM','+00:00') ORDER BY comment_time $order_direction"
    );
    ptable( "Comments" );
    $dbh->do(
        "UPDATE nagios_comments SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00'), comment_time=CONVERT_TZ(comment_time,'SYSTEM','+00:00'), expiration_time=CONVERT_TZ(expiration_time,'SYSTEM','+00:00') ORDER BY comment_time $order_direction"
    );
    ptable( "Conninfo" );

    # Just truncate as this information is not used
    $dbh->do( "TRUNCATE nagios_conninfo" );
    ptable( "Contactnotificationmethods" );
    $dbh->do(
        "UPDATE nagios_contactnotificationmethods SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "Contactnotifications" );
    $dbh->do(
        "UPDATE nagios_contactnotifications SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "Contact status" );
    $dbh->do(
        "UPDATE nagios_contactstatus SET status_update_time=CONVERT_TZ(status_update_time,'SYSTEM','+00:00'), last_host_notification=CONVERT_TZ(last_host_notification,'SYSTEM','+00:00'), last_service_notification=CONVERT_TZ(last_service_notification,'SYSTEM','+00:00')"
    );
    ptable( "Custom variable status" );
    $dbh->do(
        "UPDATE nagios_customvariablestatus SET status_update_time=CONVERT_TZ(status_update_time,'SYSTEM','+00:00')"
    );
    ptable( "Downtime history" );
    $dbh->do(
        "UPDATE nagios_downtimehistory SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00'), scheduled_start_time=CONVERT_TZ(scheduled_start_time,'SYSTEM','+00:00'), scheduled_end_time=CONVERT_TZ(scheduled_end_time,'SYSTEM','+00:00'), actual_start_time=CONVERT_TZ(actual_start_time,'SYSTEM','+00:00'), actual_end_time=CONVERT_TZ(actual_end_time,'SYSTEM','+00:00') ORDER BY entry_time $order_direction"
    );
    ptable( "Event handlers" );
    $dbh->do(
        "UPDATE nagios_eventhandlers SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "External commands" );
    $dbh->do(
        "UPDATE nagios_externalcommands SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00') ORDER BY entry_time $order_direction"
    );
    ptable( "Flapping history" );
    $dbh->do(
        "UPDATE nagios_flappinghistory SET event_time=CONVERT_TZ(event_time,'SYSTEM','+00:00'), comment_time=CONVERT_TZ(comment_time,'SYSTEM','+00:00') "
    );
    ptable( "Host checks" );
    $dbh->do(
        "UPDATE nagios_hostchecks SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "Host status" );
    $dbh->do(
        "UPDATE nagios_hoststatus SET status_update_time=CONVERT_TZ(status_update_time,'SYSTEM','+00:00'), last_check=CONVERT_TZ(last_check,'SYSTEM','+00:00'), next_check=CONVERT_TZ(next_check,'SYSTEM','+00:00'), last_state_change=CONVERT_TZ(last_state_change,'SYSTEM','+00:00'), last_hard_state_change=CONVERT_TZ(last_hard_state_change,'SYSTEM','+00:00'), last_time_up=CONVERT_TZ(last_time_up,'SYSTEM','+00:00'), last_time_down=CONVERT_TZ(last_time_down,'SYSTEM','+00:00'), last_time_unreachable=CONVERT_TZ(last_time_unreachable,'SYSTEM','+00:00'), last_notification=CONVERT_TZ(last_notification,'SYSTEM','+00:00'), next_notification=CONVERT_TZ(next_notification,'SYSTEM','+00:00')"
    );
    ptable( "Notifications" );
    $dbh->do(
        "UPDATE nagios_notifications SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "Process events" );
    $dbh->do(
        "UPDATE nagios_processevents SET event_time=CONVERT_TZ(event_time,'SYSTEM','+00:00')"
    );
    ptable( "Program status" );
    $dbh->do(
        "UPDATE nagios_programstatus SET status_update_time=CONVERT_TZ(status_update_time,'SYSTEM','+00:00'), program_start_time=CONVERT_TZ(program_start_time,'SYSTEM','+00:00'), program_end_time=CONVERT_TZ(program_end_time,'SYSTEM','+00:00'), last_command_check=CONVERT_TZ(last_command_check,'SYSTEM','+00:00'), last_log_rotation=CONVERT_TZ(last_log_rotation,'SYSTEM','+00:00')"
    );
    ptable( "Downtime" );
    $dbh->do(
        "UPDATE nagios_scheduleddowntime SET entry_time=CONVERT_TZ(entry_time,'SYSTEM','+00:00'), scheduled_start_time=CONVERT_TZ(scheduled_start_time,'SYSTEM','+00:00'), scheduled_end_time=CONVERT_TZ(scheduled_end_time,'SYSTEM','+00:00'), actual_start_time=CONVERT_TZ(actual_start_time,'SYSTEM','+00:00') ORDER BY entry_time $order_direction"
    );
    ptable( "Service results" );
    $dbh->do(
        "UPDATE nagios_servicechecks SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );
    ptable( "Service status" );
    $dbh->do(
        "UPDATE nagios_servicestatus SET 
status_update_time=CONVERT_TZ(status_update_time,'SYSTEM','+00:00'), 
last_check=CONVERT_TZ(last_check,'SYSTEM','+00:00'), 
next_check=CONVERT_TZ(next_check,'SYSTEM','+00:00'), 
last_state_change=CONVERT_TZ(last_state_change,'SYSTEM','+00:00'), 
last_hard_state_change=CONVERT_TZ(last_hard_state_change,'SYSTEM','+00:00'), 
last_time_ok=CONVERT_TZ(last_time_ok,'SYSTEM','+00:00'), 
last_time_warning=CONVERT_TZ(last_time_warning,'SYSTEM','+00:00'),
last_time_unknown=CONVERT_TZ(last_time_unknown,'SYSTEM','+00:00'),
last_time_critical=CONVERT_TZ(last_time_critical,'SYSTEM','+00:00'),
last_notification=CONVERT_TZ(last_notification,'SYSTEM','+00:00'),
next_notification=CONVERT_TZ(next_notification,'SYSTEM','+00:00')
"
    );
    ptable( "State history" );
    $dbh->do(
        "UPDATE nagios_statehistory SET state_time=CONVERT_TZ(state_time,'SYSTEM','+00:00') ORDER BY state_time $order_direction"
    );
    ptable( "System commands" );
    $dbh->do(
        "UPDATE nagios_systemcommands SET start_time=CONVERT_TZ(start_time,'SYSTEM','+00:00'), end_time=CONVERT_TZ(end_time,'SYSTEM','+00:00') ORDER BY start_time $order_direction"
    );

    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.0.5") ) {
    $nagios_db->print( "Adding indexes for faster NDO reload time\n" );
    $dbh->do(
        "ALTER TABLE nagios_contactgroups ADD INDEX nagios_contactgroups_contactgroup_object_id_contactgroup_id (contactgroup_object_id, contactgroup_id)"
    );
    $dbh->do(
        "ALTER TABLE nagios_services ADD INDEX nagios_services_config_type_service_id_service_object_id (config_type, service_id, service_object_id)"
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower('3.3.1') ) {
    $nagios_db->print( 'Re-arranging configuration indexes', $/ );
    $dbh->do( 'ALTER TABLE nagios_services DROP INDEX instance_id' );
    $dbh->do(
        'ALTER TABLE nagios_services ADD UNIQUE INDEX instance_id (service_object_id, config_type, instance_id)'
    );
    $dbh->do( 'ALTER TABLE nagios_hosts DROP INDEX instance_id' );
    $dbh->do(
        'ALTER TABLE nagios_hosts ADD UNIQUE INDEX instance_id (host_object_id, config_type, instance_id)'
    );
    $dbh->do( 'ALTER TABLE nagios_commands DROP INDEX instance_id' );
    $dbh->do(
        'ALTER TABLE nagios_commands ADD UNIQUE INDEX instance_id (object_id, config_type, instance_id)'
    );
    $dbh->do( 'ALTER TABLE nagios_comments DROP INDEX instance_id' );
    $dbh->do(
        'ALTER TABLE nagios_comments ADD UNIQUE INDEX instance_id (internal_comment_id, comment_time, instance_id)'
    );

    $dbh->do( 'ALTER TABLE nagios_commenthistory DROP INDEX instance_id' );
    $dbh->do(
        'ALTER TABLE nagios_commenthistory ADD UNIQUE INDEX instance_id (internal_comment_id, comment_time, instance_id)'
    );
    $dbh->do( 'ALTER TABLE nagios_servicedependencies DROP INDEX instance_id'
    );
    $dbh->do(
        'ALTER TABLE nagios_servicedependencies ADD UNIQUE INDEX instance_id (service_object_id, config_type, dependent_service_object_id, dependency_type, inherits_parent, fail_on_ok, fail_on_warning, fail_on_unknown, fail_on_critical, instance_id)'
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower('3.3.2') ) {
    $nagios_db->print( 'Adding status indexes', $/ );
    $dbh->do(
        'ALTER TABLE nagios_hoststatus ADD INDEX latest_update_time_idx (instance_id, status_update_time)'
    );
    $dbh->do(
        'ALTER TABLE nagios_servicestatus ADD INDEX latest_update_time_idx (instance_id, status_update_time)'
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.3.3") ) {
    $nagios_db->print( "Converting ids to bigint - this could take some time\n"
    );

    $nagios_db->print( "Converting nagios_servicechecks...\n" );
    my $one_day_cutoff =
      $dbh->selectrow_array( "SELECT (NOW() - INTERVAL 1 DAY) FROM DUAL" );
    $dbh->do( qq{DELETE FROM `nagios_servicechecks` WHERE start_time <= ?},
        {}, $one_day_cutoff );
    $dbh->do(
        "ALTER TABLE nagios_servicechecks MODIFY COLUMN servicecheck_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT"
    );

    $nagios_db->print( "Converting nagios_statehistory...\n" );
    $dbh->do(
        "ALTER TABLE nagios_statehistory MODIFY COLUMN statehistory_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT"
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.3.4") ) {

    # We add this constraint because sometimes NDO2DB creates a 2nd instance id in error
    $nagios_db->print( "Adding constraint to nagios_instances\n" );

    # We need to get the live_instance_id because some systems have instance_id set to > 1 and we cause problems
    # by deleting these instances
    my $live_instance_id = $dbh->selectrow_array(
        "SELECT instance_id FROM nagios_instances WHERE instance_name='default'"
    );
    $dbh->do(
        "DELETE FROM nagios_instances WHERE instance_id != $live_instance_id AND instance_name='default'"
    );
    $dbh->do(
        "ALTER TABLE nagios_instances ADD UNIQUE INDEX instance_name (instance_name)"
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.9.1") ) {
    $nagios_db->print(
        "Rearranging index for much faster ndoutils_configdumpend processing"
    );
    $dbh->do(
        "ALTER TABLE nagios_service_contactgroups DROP INDEX instance_id, ADD UNIQUE INDEX instance_id (contactgroup_object_id,service_id)"
    );
    $nagios_db->updated;
}

if ( $nagios_db->is_lower("3.9.2") ) {
    $nagios_db->print( "Adding new index for faster event views" );
    $dbh->do(
        "ALTER TABLE nagios_statehistory ADD INDEX nagios_statehistory_state_type_object_id (state_type, object_id)"
    );
    $nagios_db->updated;
}

print "Upgrading Opsview part of Runtime database", $/;

# Have removed all the 2.7 and 2.8 steps as this was causing a problem when restoring
# from the nightly database backups for runtime
# Upgrades to 3.3 onwards should be through 2.14 anyway

my $db = Utils::DBVersion->new(
    {
        dbh  => $dbh,
        name => "runtime-opsview"
    }
);

if ( $db->is_lower("2.10.1") ) {
    $dbh->do( "ALTER TABLE opsview_hosts ADD COLUMN ip varchar(255) NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("2.11.1") ) {
    $dbh->do( "
	CREATE TABLE opsview_monitoringclusters (
		id int PRIMARY KEY,
		name varchar(64) NOT NULL,
		hostname varchar(64),
		ip varchar(255)
	) ENGINE=MyISAM
	" );

    $dbh->do( "
	CREATE TABLE opsview_monitoringclusternodes (
		id int PRIMARY KEY,
		name varchar(64) NOT NULL,
		ip varchar(255) NOT NULL
	) ENGINE=MyISAM
	" );

    $dbh->do( "ALTER TABLE opsview_hosts ADD COLUMN monitored_by int" );
    $dbh->do( "ALTER TABLE opsview_hosts ADD COLUMN primary_node int" );
    $dbh->do( "ALTER TABLE opsview_hosts ADD COLUMN secondary_node int" );

    $db->updated;
}

if ( $db->is_lower("2.11.2") ) {
    $dbh->do(
        "ALTER TABLE opsview_host_services MODIFY COLUMN icon_filename varchar(128)"
    );
    $dbh->do(
        "ALTER TABLE opsview_hosts ADD COLUMN icon_filename varchar(128) AFTER ip"
    );
    $db->updated;
}

if ( $db->is_lower("2.12.1") ) {
    $dbh->do(
        "ALTER TABLE nagios_servicechecks ADD INDEX nagios_servicechecks_service_object_id_start_time (service_object_id, start_time)"
    );
    $dbh->do(
        "ALTER TABLE nagios_hostchecks ADD INDEX nagios_hostchecks_host_object_id_start_time (host_object_id, start_time)"
    );
    $dbh->do(
        "ALTER TABLE nagios_statehistory ADD INDEX nagios_statehistory_object_id_start_time (object_id, state_time)"
    );
    $db->updated;
}

if ( $db->is_lower("2.12.2") ) {
    $dbh->do(
        "ALTER TABLE nagios_conninfo ADD INDEX nagios_conninfo_connect_time (connect_time)"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.1") ) {
    $db->print(
        "Adding indexes to notification tables for faster querying for import_runtime - this could take some time\n"
    );
    $dbh->do(
        "ALTER TABLE nagios_contactnotificationmethods ADD INDEX nagios_contactnotificationsmethods_contactnotification_object (contactnotification_id, command_object_id)"
    );
    $dbh->do(
        "ALTER TABLE nagios_contactnotifications ADD INDEX nagios_contactnotifications_contact_notification (contact_object_id, notification_id, contactnotification_id)"
    );
    $dbh->do(
        "ALTER TABLE nagios_notifications ADD INDEX nagios_notifications_start_time (start_time, end_time, notification_id)"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.2") ) {
    $db->print(
        "Re-arranging indexes for notifications - this could take some time\n"
    );
    $dbh->do(
        "ALTER TABLE nagios_contactnotificationmethods DROP INDEX instance_id"
    );
    $dbh->do(
        "ALTER TABLE nagios_contactnotificationmethods ADD UNIQUE INDEX instance_id (start_time, contactnotification_id, instance_id, start_time_usec)"
    );
    $dbh->do( "ALTER TABLE nagios_contacts DROP INDEX instance_id" );
    $dbh->do(
        "ALTER TABLE nagios_contacts ADD UNIQUE INDEX instance_id (contact_object_id, instance_id, config_type)"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.3") ) {
    $db->print( "Re-arranging indexes for downtimes\n" );
    $dbh->do( "ALTER TABLE nagios_scheduleddowntime DROP INDEX instance_id" );
    $dbh->do(
        "ALTER TABLE nagios_scheduleddowntime ADD UNIQUE INDEX instance_id (object_id, instance_id, entry_time, internal_downtime_id)"
    );
    $dbh->do(
        "ALTER TABLE nagios_scheduleddowntime ADD INDEX nagios_scheduleddowntime_object_id_was_started (object_id, was_started)"
    );
    $db->updated;
}

if ( $db->is_lower('3.0.1') ) {
    $db->print( 'Renaming hostgroups to opsview_hostgroups', $/ );
    $dbh->do( 'RENAME TABLE hostgroups TO opsview_hostgroups' );
    $db->updated;
}

if ( $db->is_lower('3.3.1') ) {
    $db->print( 'Adding viewports index', $/ );
    $dbh->do( 'ALTER TABLE opsview_viewports ADD INDEX (service_object_id)' );
    $db->updated;
}

if ( $db->is_lower("3.3.2") ) {
    $db->print( "Adding in extra helper tables", $/ );
    $dbh->do( "
CREATE TABLE opsview_contact_hosts (
      contactid int,
      host_object_id int,
      INDEX (contactid),
      INDEX (host_object_id)
) ENGINE=MyISAM
    " );
    $dbh->do( "
CREATE TABLE opsview_contact_objects (
	contactid int,
	object_id int,
	INDEX (contactid),
	INDEX (object_id)
) ENGINE=MyISAM;
    " );
    $dbh->do(
        "ALTER TABLE opsview_viewports ADD COLUMN keyword VARCHAR(128) AFTER viewportid"
    );
    $db->updated;
}

if ( $db->is_lower('3.3.3') ) {
    $db->print( 'Adding materialised path to runtime.hostgroups', $/ );
    $dbh->do(
        'ALTER TABLE opsview_hostgroups ADD COLUMN matpath TEXT NOT NULL AFTER rgt'
    );
    $db->updated;
}

if ( $db->is_lower('3.3.4') ) {
    $db->print( 'Adding new helper table: opsview_host_objects', $/ );
    $dbh->do(
        'ALTER TABLE opsview_host_services MODIFY COLUMN servicename varchar(128)'
    );
    $dbh->do(
        qq{
CREATE TABLE opsview_host_objects (
	host_object_id int,
	hostname varchar(64),
	object_id int,
	name2 varchar(128),
	INDEX object_lookup_idx (object_id, host_object_id, name2, hostname),
	INDEX host_object_id_idx (host_object_id)
) ENGINE=MyISAM;
    }
    );
    $dbh->do(
        qq{ALTER TABLE opsview_hosts ADD COLUMN hostgroup_id INT AFTER icon_filename}
    );
    $dbh->do(
        qq{ALTER TABLE opsview_hosts ADD INDEX hostgroup_idx (id, hostgroup_id)}
    );
    $db->updated;
}

if ( $db->is_lower('3.5.1') ) {
    $db->print( 'Adding new helper table: opsview_performance_metrics', $/ );
    $dbh->do(
        qq{
CREATE TABLE opsview_performance_metrics (
	service_object_id INT DEFAULT 0,
	hostname varchar(64),
	servicename varchar(128),
	metricname varchar(64),
	uom varchar(64),
	INDEX (service_object_id),
	INDEX hostname (hostname),
	INDEX servicename (servicename),
	INDEX metricname (metricname)
) ENGINE=MyISAM;
    }
    );
    $db->updated;
}

if ( $db->is_lower('3.5.2') ) {
    $db->print( "Adding markdown filter column\n" );
    $dbh->do(
        'ALTER TABLE opsview_host_services MODIFY COLUMN perfdata_available TINYINT DEFAULT 0'
    );
    $dbh->do(
        'ALTER TABLE opsview_host_services ADD COLUMN markdown_filter TINYINT DEFAULT 0 AFTER perfdata_available'
    );
    $db->updated;
}

if ( $db->is_lower('3.5.3') ) {
    $db->print( "Adding primary key to opsview_host_services\n" );
    $dbh->do( 'ALTER TABLE opsview_host_services DROP INDEX service_object_id'
    );
    $dbh->do(
        'ALTER TABLE opsview_host_services ADD PRIMARY KEY service_object_id (service_object_id)'
    );
    $db->updated;
}

if ( $db->is_lower('3.5.4') ) {
    $db->print( "Adding alias column to opsview_hosts\n" );
    $dbh->do(
        'ALTER TABLE opsview_hosts ADD COLUMN alias VARCHAR(255) AFTER ip'
    );
    $db->updated;
}

if ( $db->is_lower('3.5.5') ) {
    $db->print( "Adding primary key to opsview_performance_metrics\n" );
    $dbh->do(
        'ALTER TABLE opsview_performance_metrics ADD COLUMN id int PRIMARY KEY AUTO_INCREMENT AFTER service_object_id'
    );
    $dbh->do(
        'ALTER TABLE opsview_performance_metrics MODIFY COLUMN metricname VARCHAR(128)'
    );
    $db->updated;
}

if ( $db->is_lower('3.5.6') ) {
    $db->print( "Re-adding primary key to opsview_performance_metrics\n" );
    $dbh->do( 'ALTER TABLE opsview_performance_metrics DROP COLUMN id' );
    $dbh->do(
        'ALTER TABLE opsview_performance_metrics ADD COLUMN id int PRIMARY KEY AUTO_INCREMENT AFTER service_object_id'
    );
    $db->updated;
}

if ( $db->is_lower('3.6.1') ) {
    $db->print( "New index for opsview_host_services\n" );
    $dbh->do(
        'ALTER TABLE opsview_host_services ADD INDEX hostname_servicename_service_object_id (hostname,servicename,service_object_id)'
    );
    $db->updated;
}

if ( $db->is_lower('3.7.1') ) {
    $db->print( "Converting remaining MyISAM tables to InnoDB\n" );
    my $sth = $dbh->prepare( q{ SHOW TABLE STATUS WHERE ENGINE = 'MYISAM' } );
    $sth->execute();
    while ( my $row = $sth->fetchrow_hashref() ) {
        $db->print( ' - ', $row->{name}, $/ );
        $dbh->do( "ALTER TABLE " . $row->{name} . " ENGINE=InnoDB" );
    }
    $db->updated;
}

if ( $db->is_lower('3.7.2') ) {
    $db->print(
        "Changing columns for nagios_servicechecks table - this may take some time"
    );
    $dbh->do(
        "ALTER TABLE nagios_servicechecks DROP INDEX instance_id, ADD INDEX start_time (start_time)"
    );
    $db->updated;
}

if ( $db->is_lower('3.7.3') ) {
    $db->print( "Adding has_interfaces column to opsview_hosts" );
    $dbh->do(
        "ALTER TABLE opsview_hosts ADD COLUMN has_interfaces TINYINT NOT NULL DEFAULT 0"
    );
    $db->updated;
}

if ( $db->is_lower('3.9.1') ) {
    $db->print( "Adding opsview_contacts table" );
    $dbh->do( "
CREATE TABLE opsview_contacts (
id INT,
contact_object_id INT,
name varchar(128) NOT NULL,
PRIMARY KEY (id),
INDEX (contact_object_id, id)
) ENGINE=InnoDB
" );
    $db->updated;
}

if ( $db->is_lower('3.11.1') ) {
    $db->print( "Adding markdown_filter column" );
    $dbh->do(
        "ALTER TABLE opsview_host_objects ADD COLUMN markdown_filter BOOLEAN DEFAULT 0 NOT NULL AFTER name2"
    );
    $db->updated;
}

if ( $db->is_lower('3.11.2') ) {
    $db->print( "Adding num_services to opsview_hosts" );
    $dbh->do(
        "ALTER TABLE opsview_hosts ADD COLUMN num_services INT DEFAULT 0 NOT NULL AFTER has_interfaces"
    );
    $db->updated;
}

if ( $db->is_lower('3.11.3') ) {
    $db->print( "Replacing has_interfaces with num_interfaces to opsview_hosts"
    );
    $dbh->do(
        "ALTER TABLE opsview_hosts CHANGE COLUMN has_interfaces num_interfaces INT DEFAULT 0 NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower('3.11.4') ) {
    $db->print(
        "Changing columns for nagios_hostchecks table - this may take some time"
    );
    $dbh->do(
        "ALTER TABLE nagios_hostchecks DROP INDEX instance_id, ADD INDEX start_time (start_time)"
    );
    $db->updated;
}

if ( $db->is_lower("3.11.5") ) {
    $db->print( "Adding primary key to opsview_host_objects" );
    $dbh->do( "ALTER TABLE opsview_host_objects ADD PRIMARY KEY (object_id)" );
    $db->updated;
}

if ( $db->is_lower("3.11.6") ) {
    $db->print( "Adding service check and service group information" );
    $dbh->do(
        qq{
CREATE TABLE opsview_servicechecks (
        id int PRIMARY KEY, # Same as Opsview servicecheckid
        name varchar(64) DEFAULT '' NOT NULL,
        description varchar(128) DEFAULT '' NOT NULL,
        multiple boolean DEFAULT 0 NOT NULL,
        active boolean DEFAULT 0 NOT NULL,
        markdown_filter boolean DEFAULT 0 NOT NULL,
        servicegroup_id int DEFAULT 0 NOT NULL
    ) ENGINE=InnoDB;
}
    );
    $dbh->do(
        qq{
    CREATE TABLE opsview_servicegroups (
        id int PRIMARY KEY, # Same as Opsview servicegroupid
        name varchar(128) DEFAULT '' NOT NULL
    ) ENGINE=InnoDB;
}
    );
    $dbh->do(
        "ALTER TABLE opsview_host_services 
        MODIFY COLUMN markdown_filter BOOLEAN DEFAuLT 0 NOT NULL,
        ADD COLUMN servicecheck_id INT DEFAULT 0 NOT NULL AFTER markdown_filter, 
        ADD COLUMN servicegroup_id INT DEFAULT 0 NOT NULL AFTER servicecheck_id"
    );
    $dbh->do(
        "ALTER TABLE opsview_host_objects 
        ADD COLUMN servicecheck_id INT DEFAULT 0 NOT NULL AFTER markdown_filter, 
        ADD COLUMN servicegroup_id INT DEFAULT 0 NOT NULL AFTER servicecheck_id"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.1") ) {
    $db->print( "Adding matpathid" );
    $dbh->do(
        "ALTER TABLE opsview_hostgroups ADD COLUMN matpathid TEXT NOT NULL DEFAULT ''"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.2") ) {
    $db->print( "Converting opsview_viewports to include rows for hosts" );
    $dbh->do(
        "ALTER TABLE opsview_viewports 
        DROP INDEX service_object_id,
        MODIFY COLUMN viewportid INT NOT NULL DEFAULT 0,
        MODIFY COLUMN keyword VARCHAR(128) NOT NULL DEFAULT '',
        MODIFY COLUMN hostname VARCHAR(255) NOT NULL DEFAULT '',
        MODIFY COLUMN servicename VARCHAR(128) DEFAULT NULL,
        MODIFY COLUMN host_object_id INT NOT NULL DEFAULT 0,
        CHANGE COLUMN service_object_id object_id INT NOT NULL DEFAULT 0,
        ADD INDEX object_id (object_id)"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.3") ) {
    $db->print( "Adding perfdata_available to opsview_host_objects" );
    $dbh->do(
        "ALTER TABLE opsview_host_objects ADD COLUMN perfdata_available TINYINT DEFAULT 0 NOT NULL AFTER name2"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.4") ) {
    $db->print( "Fixing column definitions in opsview_host_objects table" );
    $dbh->do(
        "ALTER TABLE opsview_host_objects MODIFY COLUMN host_object_id INT NOT NULL DEFAULT 0, MODIFY COLUMN object_id INT NOT NULL DEFAULT 0"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.5") ) {
    $db->print( "Fixing strange mysql error with indexes" );

    $dbh->do(
        "ALTER TABLE opsview_contact_services MODIFY COLUMN contactid INT NOT NULL, MODIFY COLUMN service_object_id INT NOT NULL, DROP INDEX contactid, ADD INDEX contactid_service_object_id (contactid, service_object_id)"
    );

    $dbh->do(
        "ALTER TABLE opsview_contact_objects MODIFY COLUMN contactid INT NOT NULL, MODIFY COLUMN object_id INT NOT NULL, DROP INDEX contactid, ADD INDEX contactid_object_id (contactid, object_id)"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.6") ) {
    $db->print( "Fixing column definition in opsview_hosts table" );
    $dbh->do(
        "ALTER TABLE opsview_hosts MODIFY COLUMN opsview_host_id INT NOT NULL DEFAULT 0, MODIFY COLUMN name VARCHAR(64) NOT NULL DEFAULT ''"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.7") ) {
    $db->print( "Added cascaded_from column to runtime" );
    $dbh->do(
        "ALTER TABLE opsview_servicechecks ADD COLUMN cascaded_from INT DEFAULT 0 NOT NULL AFTER markdown_filter"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.8") ) {

    # See Runtime::Searches->list_services
    $db->print( "Adding extra indexes for faster queries" );
    $dbh->do(
        "ALTER TABLE opsview_viewports MODIFY COLUMN hostname VARCHAR(64) NOT NULL DEFAULT '', ADD INDEX keyword_host_object_id_service_object_id (keyword, host_object_id, object_id)"
    );

    $dbh->do(
        "ALTER TABLE opsview_hosts MODIFY COLUMN alias VARCHAR(255) NOT NULL DEFAULT '', MODIFY COLUMN icon_filename VARCHAR(128) NOT NULL DEFAULT '', MODIFY COLUMN hostgroup_id INT(11) DEFAULT 0 NOT NULL, MODIFY COLUMN monitored_by INT(11) NOT NULL DEFAULT 0, ADD INDEX id_num_interfaces_num_services_alias_icon_filename (id,num_interfaces,num_services,alias,icon_filename)"
    );

    $dbh->do(
        "ALTER TABLE opsview_host_services MODIFY COLUMN host_object_id INT(11) DEFAULT 0 NOT NULL, MODIFY COLUMN hostname VARCHAR(64) NOT NULL DEFAULT '', MODIFY COLUMN servicename VARCHAR(128) NOT NULL DEFAULT '', MODIFY COLUMN perfdata_available BOOLEAN DEFAULT 0 NOT NULL, ADD INDEX covering_index (host_object_id, service_object_id, hostname, servicename, perfdata_available, markdown_filter)"
    );

    $dbh->do(
        "ALTER TABLE opsview_host_objects MODIFY COLUMN hostname VARCHAR(64) NOT NULL DEFAULT '', MODIFY COLUMN perfdata_available BOOLEAN DEFAULT 0 NOT NULL, ADD INDEX covering_index (host_object_id, object_id, hostname, name2, perfdata_available, markdown_filter)"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.9") ) {
    $db->print( "Adding extra indexes for faster event queries" );
    $dbh->do(
        "ALTER TABLE opsview_host_objects ADD INDEX events_view_index (object_id,hostname,name2,markdown_filter)"
    );
    $dbh->do(
        "ALTER TABLE nagios_statehistory ADD INDEX state_time_state_type_object_id (state_time, state_type, object_id)"
    );
    $db->updated;
}

# NOTE: This is a no-op. It looks like some changes in 3.13.10 in commit 8271
# did not get merged in correctly, so some systems have 3.13.10 marked, while others
# haven't. We make this a no-op, so that 3.13.10 is marked correctly and continue
if ( $db->is_lower("3.13.10") ) {
    $db->print( "No-op" );
    $db->updated;
}

if ( $db->is_lower("3.13.11") ) {
    $db->print( "Amending schema_version to handle new style schema changes" );
    $dbh->do( "
        ALTER TABLE schema_version ADD COLUMN reason VARCHAR(255), 
            ADD COLUMN created_at DATETIME, 
            ADD COLUMN duration INT, 
            ADD PRIMARY KEY (major_release)
    " );
    $db->updated;
}

if ( $db->is_lower("3.15.1") ) {
    $db->print(
        "Re-synchronising new and upgraded schemas for missing and redundant indexes"
    );
    drop_index_quietly( $dbh, "nagios_servicestatus", "instance_id" );
    drop_index_quietly( $dbh, "nagios_timedeventqueue", "instance_id",
        "event_type", "scheduled_time" );
    drop_index_quietly( $dbh, "nagios_statehistory",     "instance_id" );
    drop_index_quietly( $dbh, "nagios_service_contacts", "contact_object_id" );
    drop_index_quietly( $dbh, "nagios_processevents", "instance_id",
        "event_time" );
    drop_index_quietly( $dbh, "nagios_objects", "instance_id" );
    drop_index_quietly( $dbh, "nagios_logentries", "instance_id",
        "logentry_time", "entry_time" );
    drop_index_quietly( $dbh, "nagios_flappinghistory",  "instance_id" );
    drop_index_quietly( $dbh, "nagios_externalcommands", "instance_id" );
    drop_index_quietly( $dbh, "nagios_contactstatus",    "instance_id" );
    drop_index_quietly( $dbh, "nagios_conninfo",         "instance_id" );
    drop_index_quietly( $dbh, "nagios_acknowledgements", "instance_id" );

    # Do this in two steps as some DBs have one but not the other
    # We also truncate data in this table - should get regenerated on reload
    # Plus I don't think we use this anyway
    $dbh->do( "TRUNCATE nagios_customvariablestatus" );
    drop_index_quietly( $dbh, "nagios_customvariablestatus", "instance_id" );
    drop_index_quietly( $dbh, "nagios_customvariablestatus", "object_id_2" );
    $dbh->do(
        "ALTER TABLE nagios_customvariablestatus ADD UNIQUE INDEX object_id_2 (object_id, varname)"
    );

    $dbh->do(
        "ALTER TABLE opsview_hostgroups MODIFY COLUMN name VARCHAR(128) NOT NULL DEFAULT ''"
    );

    $dbh->do(
        'ALTER TABLE opsview_performance_metrics MODIFY COLUMN hostname VARCHAR(64) NOT NULL DEFAULT "", MODIFY COLUMN servicename VARCHAR(128) NOT NULL DEFAULT "", MODIFY COLUMN metricname VARCHAR(128) NOT NULL DEFAULT "", MODIFY COLUMN uom VARCHAR(64) DEFAULT NULL'
    );
    $dbh->do(
        'ALTER TABLE opsview_monitoringclusters MODIFY COLUMN id INT NOT NULL DEFAULT 0, MODIFY COLUMN name VARCHAR(64) NOT NULL DEFAULT ""'
    );
    $dbh->do(
        'ALTER TABLE opsview_monitoringclusternodes MODIFY COLUMN id INT NOT NULL DEFAULT 0, MODIFY COLUMN name VARCHAR(64) NOT NULL DEFAULT "", MODIFY COLUMN ip VARCHAR(255) NOT NULL DEFAULT ""'
    );
    $dbh->do(
        "ALTER TABLE opsview_hosts MODIFY COLUMN id INT NOT NULL DEFAULT 0, MODIFY COLUMN ip VARCHAR(255) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE opsview_hostgroups MODIFY COLUMN name VARCHAR(128) NOT NULL DEFAULT ''"
    );

    $dbh->do(
        "ALTER TABLE snmptrapruledebug MODIFY COLUMN trap INT NOT NULL DEFAULT 0, MODIFY COLUMN servicecheck INT NOT NULL DEFAULT 0"
    );

    $db->updated;
}

if ( $db->is_lower("3.15.2") ) {
    $db->print(
        "Adding in additional columns to calculate downtimes and acknowledgements across state changes"
    );
    $dbh->do(
        q{ALTER TABLE nagios_statehistory 
        ADD COLUMN scheduled_downtime_depth SMALLINT NOT NULL DEFAULT 0 AFTER last_hard_state,
        ADD COLUMN downtimehistory_id INT DEFAULT NULL AFTER scheduled_downtime_depth,
        ADD COLUMN problem_has_been_acknowledged BOOLEAN NOT NULL DEFAULT 0 AFTER downtimehistory_id,
        ADD COLUMN eventtype SMALLINT DEFAULT 0 NOT NULL AFTER problem_has_been_acknowledged,
        ADD COLUMN host_state SMALLINT NOT NULL DEFAULT 0 AFTER eventtype,
        ADD COLUMN host_state_type SMALLINT NOT NULL DEFAULT 0 AFTER host_state
    }
    );
    $db->updated;
}

if ( $db->is_lower("3.15.3") ) {
    $db->print( "No action taken" );
    $db->updated;
}

if ( $db->is_lower("3.15.4") ) {
    $db->print(
        "State information about downtimes recorded in statehistory table"
    );
    $dbh->do(
        q{ALTER TABLE nagios_downtimehistory
        ADD COLUMN was_logged BOOLEAN NOT NULL DEFAULT 0 AFTER was_cancelled,
        ADD INDEX nagios_downtimehistory_internal_downtime_id (internal_downtime_id)
    }
    );
    $db->updated;
}

if ( $db->is_lower("3.15.5") ) {
    $db->print( "Adding network topology information" );
    $dbh->do(
        qq{
            CREATE TABLE opsview_topology_map (
                id int unsigned NOT NULL auto_increment,
                hostgroup_id INT(10) DEFAULT NULL,
                monitored_by INT(10) DEFAULT NULL,
                object_id INT(10) NOT NULL,
                host_id INT(10) NOT NULL,
                opsview_host_id INT(10) NOT NULL,
                name varchar(64) NOT NULL,
                parent_id INT(10) DEFAULT NULL,
                parent_object_id INT(10) DEFAULT NULL,
                parent_name varchar(64) DEFAULT NULL,
                child_id INT(10) DEFAULT NULL,
                child_object_id INT(10) DEFAULT NULL,
                child_name varchar(64) DEFAULT NULL,
                PRIMARY KEY (id),
                INDEX (hostgroup_id),
                INDEX (monitored_by),
                INDEX (opsview_host_id),
                INDEX (name),
                INDEX (parent_id),
                INDEX (parent_name),
                INDEX (child_id),
                INDEX (child_name)
            ) ENGINE=InnoDB;
        }
    );
    $db->updated;
}

if ( $db->is_lower('3.15.6') ) {
    $db->print( "Adding num_children to opsview_hosts" );
    $dbh->do(
        "ALTER TABLE opsview_hosts ADD COLUMN num_children INT DEFAULT 0 NOT NULL AFTER num_services"
    );
    $dbh->do( "ALTER TABLE opsview_hosts ADD INDEX num_children (num_children)"
    );

    $db->updated;
}

if ( $db->is_lower('3.15.7') ) {
    $db->print( "Removing unused table opsview_monitoringclusters" );
    $dbh->do( "DROP TABLE opsview_monitoringclusters" );
    $db->updated;
}
if ( $db->is_lower('3.15.8') ) {
    $db->print( "Adding monitoring servers to runtime db" );
    $dbh->do(
        qq{
CREATE TABLE opsview_monitoringservers (
        id int NOT NULL DEFAULT 0,
        name varchar(64) NOT NULL DEFAULT '',
        activated BOOLEAN DEFAULT 1 NOT NULL,
        passive BOOLEAN DEFAULT 0 NOT NULL,
        nodes TEXT NOT NULL,
        PRIMARY KEY (id)
) ENGINE=InnoDB COMMENT="Runtime list of monitoring servers"
    }
    );
    $db->updated;
}

if ( $db->is_lower('3.15.9') ) {
    $db->print( "Removing unused column from topology map" );
    $dbh->do( "ALTER TABLE opsview_topology_map DROP COLUMN hostgroup_id" );
    $db->updated;
}

unless (
    $db->is_installed( "20120925hstpths", "Adding hosts matpaths", "all" ) )
{
    $dbh->do(
        qq{
            CREATE TABLE opsview_hosts_matpaths (
                id int unsigned NOT NULL auto_increment,
                object_id INT(10) NOT NULL,
                matpath TEXT NOT NULL,
                PRIMARY KEY (id),
                INDEX (object_id)
            ) ENGINE=InnoDB;
        }
    );
    $db->updated;
}

unless (
    $db->is_installed(
        "20121004hstdepth", "Adding hosts network depth", "all"
    )
  )
{
    $dbh->do(
        qq{ ALTER TABLE opsview_hosts_matpaths ADD COLUMN depth INT UNSIGNED NOT NULL DEFAULT 0}
    );
    $db->updated;
}

unless (
    $db->is_installed(
        "20121022bigints",
        "Converting IDs to BIGINT (this will truncate tables first)", "all"
    )
  )
{
    my %tables = (
        nagios_hostchecks  => 'hostcheck_id',
        snmptrapexceptions => 'id',
    );

    while ( my ( $table, $column ) = each %tables ) {
        my $sth =
          $dbh->column_info( undef, Opsview::Config->runtime_db, $table,
            $column );
        my $info = $sth->fetchrow_hashref || { TYPE_NAME => '' };
        unless ( $info->{TYPE_NAME} eq 'BIGINT' ) {
            $db->print( "Converting $table...\n" );
            $dbh->do( "TRUNCATE TABLE $table" );
            $dbh->do(
                "ALTER TABLE $table MODIFY COLUMN $column BIGINT UNSIGNED NOT NULL AUTO_INCREMENT"
            );
        }
    }
    $db->updated;
}

if ( $db_changed || $db->changed || $nagios_db->changed ) {
    print "Finished updating database", $/;
}
else {
    print "Database already up to date", $/;
}

sub drop_index_quietly {
    my ( $dbh, $table, @indexes ) = @_;
    local $dbh->{RaiseError}; # Turn off to ignore error
                              #local $dbh->{PrintError};
    my $drop_sql = join( ", ", map {"DROP INDEX `$_`"} @indexes );
    $dbh->do( "ALTER TABLE `$table` $drop_sql" );
}
