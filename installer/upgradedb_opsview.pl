#!/usr/bin/perl
#
#
# SYNTAX:
# 	upgradedb_opsview.pl [-t]
#
# DESCRIPTION:
# 	Connects to DB and upgrades it to the latest level
#	-t means running on a test system
#
#	Warning!!!! This file must be kept up to date with db_opsview
#
#	Warning #2 !!! Only use DBI commands - no Class::DBI allowed
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
use lib "/usr/local/nagios/lib", "/usr/local/nagios/etc";
use Opsview;
use File::Copy;

# Do not use Class::DBI methods to amend data
use Utils::DBVersion;

my $opts = {};
getopts( "t", $opts ) or die "Bad options";

my $dbh        = Opsview->db_Main;
my $db_changed = 0;

# Need this post update flag because some stuff done with Opsview::Hostgroup class
# and this can only run when all the db changes have been made
my $postupdate = {};

# Set no stdout buffering, needed due to top level tee
$| = 1;

if ( db_version_lower("2.0.1") ) {
    my $htpasswd  = "/usr/local/nagios/etc/htpasswd.users";
    my %passwords = ();

    # Need this test because a test system will not be able to read the htpasswd file
    if ( -r $htpasswd ) {
        open F, "$htpasswd" or die "Cannot read $htpasswd";
        while (<F>) {
            my ( $user, $password ) = split( ":", $_ );
            if ( $user eq "admin" ) {
                unless (
                    $dbh->selectrow_array(
                        "SELECT name FROM contacts WHERE name='admin'")
                  )
                {
                    $dbh->do(
                        "INSERT INTO contacts (name, comment, all_hostgroups, all_servicegroups) VALUES ('admin', 'Migrated admin user', 1, 1)"
                    );
                }
            }
            $passwords{$user} = $password;
        }
        close F;
    }

    print "Adding username and password into contacts", $/;
    $dbh->do( "ALTER TABLE contacts ADD COLUMN username varchar(128)" );
    $dbh->do( "ALTER TABLE contacts ADD COLUMN password varchar(128)" );

    my $sth = $dbh->prepare( "SELECT id, name FROM contacts" );
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $name = $row->{name};
        $name = lc $name;
        $name =~ s/ //g;
        $dbh->do( "UPDATE contacts SET username='$name' WHERE id=" . $row->{id}
        );

        if ( $passwords{$name} ) {
            $dbh->do(
                    "UPDATE contacts SET password='"
                  . $passwords{$name}
                  . "' WHERE username='"
                  . $name . "'"
            );
        }
    }

    # Normalizing hostcheckcommands
    $dbh->do( "ALTER TABLE hosts DROP FOREIGN KEY hosts_ibfk_4" );
    $dbh->do( "ALTER TABLE hostcheckcommands DROP PRIMARY KEY" );
    $dbh->do( "ALTER TABLE hostcheckcommands ADD id INT" );
    $dbh->do( "UPDATE hostcheckcommands SET id=1 WHERE name='ping'" );
    $dbh->do( "UPDATE hostcheckcommands SET id=2 WHERE name='tcp port 80'" );
    $dbh->do( "UPDATE hostcheckcommands SET id=3 WHERE name='tcp port 22'" );
    $dbh->do( "UPDATE hostcheckcommands SET id=9 WHERE name='-none-'" );

    $dbh->do( "ALTER TABLE hosts ADD COLUMN check_command_id INT" );
    $dbh->do( "
		UPDATE hosts, hostcheckcommands
		SET hosts.check_command_id=hostcheckcommands.id
		WHERE hosts.check_command=hostcheckcommands.name
		" );
    $dbh->do( "ALTER TABLE hosts DROP COLUMN check_command" );
    $dbh->do( "ALTER TABLE hosts CHANGE check_command_id check_command INT" );

    if (
        $dbh->selectrow_array(
            "SELECT COUNT(*) FROM hosts WHERE check_command IS NULL") > 0
      )
    {
        die "There's a host with check_command NULL";
    }

    # Normalizing notificationperiods
    $dbh->do( "ALTER TABLE contacts DROP FOREIGN KEY contacts_ibfk_1" );
    $dbh->do( "ALTER TABLE hosts DROP FOREIGN KEY hosts_ibfk_3" );
    $dbh->do( "ALTER TABLE servicechecks DROP FOREIGN KEY servicechecks_ibfk_3"
    );
    $dbh->do( "ALTER TABLE notificationperiods DROP PRIMARY KEY" );
    $dbh->do( "ALTER TABLE notificationperiods ADD id INT" );
    $dbh->do( "UPDATE notificationperiods SET id=1 WHERE name='24x7'" );
    $dbh->do( "UPDATE notificationperiods SET id=2 WHERE name='workhours'" );
    $dbh->do( "UPDATE notificationperiods SET id=3 WHERE name='nonworkhours'"
    );

    $dbh->do( "ALTER TABLE hosts ADD COLUMN notification_period_id INT" );
    $dbh->do( "
		UPDATE hosts, notificationperiods
		SET hosts.notification_period_id=notificationperiods.id
		WHERE hosts.notification_period=notificationperiods.name
		" );
    $dbh->do( "ALTER TABLE hosts DROP COLUMN notification_period" );
    $dbh->do(
        "ALTER TABLE hosts CHANGE notification_period_id notification_period INT"
    );

    $dbh->do( "ALTER TABLE contacts ADD COLUMN notification_period_id INT" );
    $dbh->do( "
		UPDATE contacts, notificationperiods
		SET contacts.notification_period_id=notificationperiods.id
		WHERE contacts.notification_period=notificationperiods.name
		" );
    $dbh->do( "ALTER TABLE contacts DROP COLUMN notification_period" );
    $dbh->do(
        "ALTER TABLE contacts CHANGE notification_period_id notification_period INT"
    );

    $dbh->do( "ALTER TABLE servicechecks ADD COLUMN notification_period_id INT"
    );
    $dbh->do( "
		UPDATE servicechecks, notificationperiods
		SET servicechecks.notification_period_id=notificationperiods.id
		WHERE servicechecks.notification_period=notificationperiods.name
		" );
    $dbh->do( "ALTER TABLE servicechecks DROP COLUMN notification_period" );
    $dbh->do(
        "ALTER TABLE servicechecks CHANGE notification_period_id notification_period INT"
    );

    set_db_version( "2.0.1" );
}

if ( db_version_lower("2.0.3") ) {
    my $sth = $dbh->prepare( "SELECT id, plugin, args FROM servicechecks" );
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $plugin = $row->{plugin};
        my $args;
        if ( $plugin =~ /^(check_procs)$/ ) {

            # Nothing
        }
        else {
            $args = '-H $HOSTADDRESS$ ';
        }
        $args .= '-C $SNMP_COMMUNITY$ ' if ( $plugin =~ /snmp/ );
        $args .= $row->{args};
        $args =~ s/'/"/g;
        $dbh->do(
            "UPDATE servicechecks SET args='$args' WHERE id=" . $row->{id}
        );
    }

    # activechecks were defaulting to 0, but this means that a subsequent upgrade
    # would put all the servicechecks as passive. Setting default to 1 instead
    $dbh->do( "ALTER TABLE servicechecks ADD COLUMN activecheck int DEFAULT 1"
    );
    set_db_version( "2.0-3" );
}

if ( db_version_lower("2.0.4") ) {
    $dbh->do( "
        CREATE TABLE monitoringservers (
                id int AUTO_INCREMENT,
                host int NOT NULL,
                PRIMARY KEY (id),
                UNIQUE(host)
        ) ENGINE=InnoDB;
	" );

    $_ = $dbh->selectrow_array( "SELECT MIN(id) FROM hosts" );
    my $hostname =
      $dbh->selectrow_array( "SELECT name FROM hosts WHERE id=$_" );

    $dbh->do( "
        INSERT INTO monitoringservers (id, host) VALUES
                (1, $_);
	" );

    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN monitored_by int DEFAULT 1 NOT NULL"
    );
    set_db_version( "2.0-4" );
}

if ( db_version_lower("2.0.5") ) {
    $dbh->do( "ALTER TABLE servicechecks CHANGE activecheck checktype INT" );
    $dbh->do( "UPDATE servicechecks SET checktype=2 WHERE checktype=0" );
    set_db_version( "2.0-5" );
}

if ( db_version_lower("2.0.6") ) {

    # Not required as this schema was never distributed
    #$dbh->do("ALTER TABLE servicecheckhostexceptions DROP COLUMN uncommitted");
    #$dbh->do("ALTER TABLE servicecheckhosttemplateexceptions DROP COLUMN uncommitted");
    {
        local $dbh->{RaiseError}; # Turn off error because column may not exist
        local $dbh->{PrintError};
        $dbh->do(
            "UPDATE hostgroups SET uncommitted=0 WHERE uncommitted IS NULL"
        );
        $dbh->do(
            "UPDATE servicegroups SET uncommitted=0 WHERE uncommitted IS NULL"
        );
    }
    set_db_version( "2.0-6" );
}

if ( db_version_lower("2.0.7") ) {
    $dbh->do(
        "ALTER TABLE monitoringservers ADD COLUMN activated int DEFAULT 1 NOT NULL"
    );
    {
        local $dbh->{RaiseError}; # Turn off error because column may not exist
        local $dbh->{PrintError};
        $dbh->do( "ALTER TABLE plugins DROP COLUMN performance" );
    }
    set_db_version( "2.0-7" );
}

if ( db_version_lower("2.0.8") ) {
    $dbh->do(
        "UPDATE hosts, monitoringservers SET hosts.monitored_by=monitoringservers.id WHERE monitoringservers.host=hosts.id"
    );
    set_db_version( "2.0-8" );
}

if ( db_version_lower("2.0.8.1") ) {
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN only_escalations int NOT NULL DEFAULT 0"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN escalation_level int NOT NULL DEFAULT 0"
    );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN escalation_level int NOT NULL DEFAULT 0"
    );
    set_db_version( "2.0-8.1" );
}

if ( db_version_lower("2.0.9") ) {
    $dbh->do( "ALTER TABLE hosts DROP COLUMN services" );
    set_db_version( "2.0-9" );
}

if ( db_version_lower("2.3.0") ) {
    {
        local $dbh
          ->{RaiseError}; # Turn off error because if upgrading from a long time ago, roles was not added at right time
        local $dbh->{PrintError};
        $dbh->do(
            'ALTER TABLE monitoringservers ADD COLUMN role ENUM ("Master", "Slave") DEFAULT "Master"'
        );
    }
    $dbh->do( "ALTER TABLE monitoringservers ADD COLUMN name varchar(128)" );
    $dbh->do( "ALTER TABLE monitoringservers MODIFY host int" );
    $dbh->do(
        "UPDATE monitoringservers,hosts SET monitoringservers.name=hosts.alias WHERE monitoringservers.host=hosts.id"
    );
    $dbh->do(
        "UPDATE monitoringservers SET name='Master' WHERE role='Master' and name=''"
    );
    $dbh->do( "UPDATE monitoringservers SET name='unamed' WHERE name=''" );
    $dbh->do(
        "CREATE TABLE monitoringclusternodes (
                id int AUTO_INCREMENT,
                monitoringcluster int NOT NULL,
                host int NOT NULL,
                activated int NOT NULL DEFAULT 1,
                uncommitted int NOT NULL DEFAULT 0,
                PRIMARY KEY (id),
                UNIQUE (monitoringcluster, host)
        	)
		"
    );
    $dbh->do(
        "INSERT INTO monitoringclusternodes (monitoringcluster, host)
		SELECT id, host
		FROM monitoringservers
		WHERE role='Slave'
		"
    );
    $dbh->do( "UPDATE monitoringservers SET host=NULL WHERE role = 'Slave'" );
    set_db_version( "2.3-0" );
}

if ( db_version_lower("2.5.1") ) {
    $dbh->do( "ALTER TABLE contacts DROP COLUMN only_escalations" );
    $dbh->do( "ALTER TABLE hosts DROP COLUMN escalation_level" );
    $dbh->do( "ALTER TABLE servicechecks DROP COLUMN escalation_level" );
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN notification_level int NOT NULL DEFAULT 1"
    );
    set_db_version( "2.5.1" );
}

if ( db_version_lower("2.5.2") ) {
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN renotify int NOT NULL DEFAULT 0"
    );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN stalking int NOT NULL DEFAULT 0"
    );
    set_db_version( "2.5.2" );
}

if ( db_version_lower("2.5.3") ) {
    $dbh->do( "ALTER TABLE servicechecks MODIFY COLUMN stalking varchar(16)" );
    $dbh->do( "UPDATE servicechecks SET stalking='w,c' WHERE stalking!='0'" );
    $dbh->do( "UPDATE servicechecks SET stalking=NULL WHERE stalking='0'" );
    set_db_version( "2.5.3" );
}

if ( db_version_lower("2.5.4") ) {
    $dbh->do( "ALTER TABLE hostgroups ADD COLUMN parentid int DEFAULT 1" );
    my $master =
      $dbh->selectrow_array( "SELECT id FROM hostgroups WHERE id=1" );
    if ($master) {
        $dbh->do( "SET FOREIGN_KEY_CHECKS=0" );
        my $new_id =
          $dbh->selectrow_array( "SELECT MAX(id)+1 FROM hostgroups" );
        $dbh->do( "UPDATE hostgroups SET id=$new_id WHERE id=1" );
        $dbh->do( "SET FOREIGN_KEY_CHECKS=1" );
        $dbh->do( "UPDATE hosts SET hostgroup=$new_id WHERE hostgroup=1" );
        $dbh->do(
            "UPDATE hostgroupnotify SET hostgroupid=$new_id WHERE hostgroupid=1"
        );
    }
    my $customer = Opsview::Config->customer;
    $dbh->do(
        "INSERT INTO hostgroups (id, name, parentid, uncommitted) VALUES (1, '$customer', NULL, 1)"
    );
    set_db_version( "2.5.4" );
}

if ( db_version_lower("2.5.5") ) {
    $dbh->do( "ALTER TABLE plugins ADD COLUMN onserver int DEFAULT 1" );
    set_db_version( "2.5.5" );
}

if ( db_version_lower("2.5.6") ) {

    # Prior versions held custom servicechecks/performancemonitors in other
    # table, although wasn't used in nagconfgen. With
    # advent of multi hosttemplates, need to delete those
    # custom ones as they will be used in nagconfgen
    $dbh->do(
        "DELETE FROM hostservicechecks USING hostservicechecks, hosts WHERE hosts.host_template!=1 AND hostservicechecks.hostid=hosts.id"
    );
    $dbh->do(
        "DELETE FROM hostperformancemonitors USING hostperformancemonitors, hosts WHERE hosts.host_template!=1 AND hostperformancemonitors.hostid=hosts.id"
    );
    $dbh->do( "
        CREATE TABLE hosthosttemplates (
                hostid int NOT NULL,
                hosttemplateid int NOT NULL,
                priority int NOT NULL,
                PRIMARY KEY (hostid, hosttemplateid),
                INDEX (hostid),
                CONSTRAINT hosthosttemplates_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id),
                INDEX (hosttemplateid),
                CONSTRAINT hosthosttemplates_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id)
        ) ENGINE=InnoDB;
	" );
    $dbh->do(
        "INSERT INTO hosthosttemplates SELECT id, host_template, 1 FROM hosts WHERE host_template!=1"
    );

    $dbh->do( "ALTER TABLE hosts DROP FOREIGN KEY hosts_host_template_fk" );
    $dbh->do( "ALTER TABLE hosts DROP COLUMN host_template" );
    $dbh->do( "DELETE FROM hosttemplates WHERE id=1" );

    set_db_version( "2.5.6" );
}

if ( db_version_lower("2.5.7") ) {
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN flap_detection_enabled int DEFAULT 1"
    );
    set_db_version( "2.5.7" );
}

if ( db_version_lower("2.7.1") ) {
    $dbh->do( "
	CREATE TABLE keywords (
		id int AUTO_INCREMENT,
		name varchar(128) NOT NULL,
		description varchar(255),
                enabled int DEFAULT 0,
                style varchar(128) DEFAULT NULL,
		PRIMARY KEY (id),
		UNIQUE (name)
	) ENGINE=InnoDB;
	" );

    $dbh->do( "
	CREATE TABLE keywordhosts (
		keywordid int NOT NULL,
		hostid int NOT NULL,
		PRIMARY KEY (keywordid, hostid),
		INDEX (keywordid),
		CONSTRAINT keywordhosts_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id),
		INDEX (hostid),
		CONSTRAINT keywordhosts_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id)
	) ENGINE=InnoDB;
	" );

    $dbh->do( "
	CREATE TABLE keywordhostgroups (
		keywordid int NOT NULL,
		hostgroupid int NOT NULL,
		PRIMARY KEY (keywordid, hostgroupid),
		INDEX (keywordid),
		CONSTRAINT keywordhostgroups_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id),
		INDEX (hostgroupid),
		CONSTRAINT keywordhostgroups_hostgroupsid_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id)
	) ENGINE=InnoDB;
	" );

    $dbh->do( "
        CREATE TABLE keywordhosttemplates (
                keywordid int NOT NULL,
                hosttemplateid int NOT NULL,
                PRIMARY KEY (keywordid, hosttemplateid),
                INDEX (keywordid),
                CONSTRAINT keywordhosttemplates_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id),
                INDEX (hosttemplateid),
                CONSTRAINT keywordhosttemplates_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id)
        ) ENGINE=InnoDB;
	" );

    $dbh->do( "
        CREATE TABLE keywordservicechecks (
                keywordid int NOT NULL,
                servicecheckid int NOT NULL,
                PRIMARY KEY (keywordid, servicecheckid),
                INDEX (keywordid),
                CONSTRAINT keywordservicechecks_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id),
                INDEX (servicecheckid),
                CONSTRAINT keywordservicechecks_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id)
        ) ENGINE=InnoDB;
	" );

    $dbh->do( "
        CREATE TABLE keywordservicegroups (
                keywordid int NOT NULL,
                servicegroupid int NOT NULL,
                PRIMARY KEY (keywordid, servicegroupid),
                INDEX (keywordid),
                CONSTRAINT keywordservicegroups_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id),
                INDEX (servicegroupid),
                CONSTRAINT keywordservicegroups_servicegroupid_fk FOREIGN KEY (servicegroupid) REFERENCES servicegroups(id)
        ) ENGINE=InnoDB;
	" );

    set_db_version( "2.7.1" );
}

if ( db_version_lower("2.7.2") ) {
    $dbh->do( "
        CREATE TABLE reloadtimes (
                id int AUTO_INCREMENT,
                start_config int,
                end_config int,
                start_transfer int,
                end_transfer int,
                duration int,
                PRIMARY KEY(id)
        ) ENGINE=InnoDB;
	" );

    $dbh->do( "
        CREATE TABLE servicecheckdependencies (
                servicecheckid int,
                dependencyid int,
                PRIMARY KEY (servicecheckid, dependencyid),
                INDEX (servicecheckid),
                CONSTRAINT servicecheckdependencies_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id),
                INDEX (dependencyid),
                CONSTRAINT servicecheckdependencies_dependencyid_fk FOREIGN KEY (dependencyid) REFERENCES servicechecks(id)
        ) ENGINE=InnoDB;
	" );

    set_db_version( "2.7.2" );
}
if ( db_version_lower("2.7.3") ) {
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN alias VARCHAR(128)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN sunday VARCHAR(48)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN monday VARCHAR(48)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN tuesday VARCHAR(48)"
    );
    $dbh->do(
        "ALTER TABLE notificationperiods ADD COLUMN wednesday VARCHAR(48)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN thursday VARCHAR(48)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN friday VARCHAR(48)"
    );
    $dbh->do( "ALTER TABLE notificationperiods ADD COLUMN saturday VARCHAR(48)"
    );

    $dbh->do( '
		UPDATE notificationperiods SET
			sunday="00:00-24:00",
			monday="00:00-24:00",
			tuesday="00:00-24:00",
			wednesday="00:00-24:00",
			thursday="00:00-24:00",
			friday="00:00-24:00",
			saturday="00:00-24:00"
		WHERE id=1
	' );

    $dbh->do( '
		UPDATE notificationperiods SET
			monday="09:00-17:00",
			tuesday="09:00-17:00",
			wednesday="09:00-17:00",
			thursday="09:00-17:00",
			friday="09:00-17:00"
		WHERE id=2
	' );

    $dbh->do( '
		UPDATE notificationperiods SET
			sunday="00:00-24:00",
			monday="00:00-09:00,17:00-24:00",
			tuesday="00:00-09:00,17:00-24:00",
			wednesday="00:00-09:00,17:00-24:00",
			thursday="00:00-09:00,17:00-24:00",
			friday="00:00-09:00,17:00-24:00",
			saturday="00:00-24:00"
		WHERE id=3
	' );

    set_db_version( "2.7.3" );
}

if ( db_version_lower("2.7.4") ) {
    $dbh->do( '
        CREATE TABLE hostsnmpinterfaces (
                hostid int NOT NULL,
                interfacename varchar(255) NOT NULL,
                active int DEFAULT 0,
                PRIMARY KEY (hostid, interfacename),
                INDEX (hostid),
                CONSTRAINT hostsnmpinterfaces_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id)
        ) ENGINE=InnoDB;
	' );

    set_db_version( "2.7.4" );
}

if ( db_version_lower("2.7.5") ) {
    $dbh->do( '
	CREATE TABLE embeddedservices (
                id int AUTO_INCREMENT,
                name varchar(128) NOT NULL,
		template_name varchar(128) NOT NULL,
                servicegroup int,
                notification_options varchar(16),
                notification_interval int,      # This can be NULL (to inherit from host)
                notification_period int,        # This can be NULL (to inherit from host)
                check_interval int,
                retry_check_interval int,
                check_attempts int,
                PRIMARY KEY (id),
		UNIQUE (template_name),
                INDEX (servicegroup),
                CONSTRAINT embeddedservices_servicegroup_fk FOREIGN KEY (servicegroup) REFERENCES servicegroups(id),
                INDEX (notification_period),
                CONSTRAINT embeddedservices_notification_period_fk FOREIGN KEY (notification_period) REFERENCES notificationperiods(id)
        ) ENGINE=InnoDB;
	' );

    $dbh->do(
        'INSERT INTO embeddedservices (id, name, template_name, servicegroup, notification_options, notification_interval, notification_period, check_interval, retry_check_interval, check_attempts) VALUES (1, "SNMP Interface polling", "snmp_interface", NULL, "n", NULL, NULL, 5, 1, 3)'
    );

    set_db_version( "2.7.5" );
}

if ( db_version_lower("2.7.6") ) {
    $dbh->do( 'ALTER TABLE hostsnmpinterfaces ADD COLUMN warning varchar(10)'
    );
    $dbh->do( 'ALTER TABLE hostsnmpinterfaces ADD COLUMN critical varchar(10)'
    );
    set_db_version( "2.7.6" );
}

if ( db_version_lower("2.7.7") ) {
    $dbh->do( 'UPDATE checktypes SET name="Active Plugin" WHERE id=1' );
    $dbh->do(
        'INSERT INTO checktypes (id, name, priority) VALUES (5, "SNMP Polling", 2)'
    );
    set_db_version( "2.7.7" );
}

if ( db_version_lower("2.7.8") ) {
    $dbh->do( '
        CREATE TABLE servicechecksnmppolling (
		id int,
		oid varchar(255),
		critical_comparison varchar(10),
		critical_value varchar(255),
		warning_comparison varchar(10),
		warning_value varchar(255),
		UNIQUE (id),
		CONSTRAINT servicechecksnmppolling_servicechecks_fk FOREIGN KEY (id) REFERENCES servicechecks(id)
	) ENGINE=InnoDB;
	' );
    set_db_version( "2.7.8" );
}

if ( db_version_lower("2.7.9") ) {
    $dbh->do( '
        CREATE TABLE snmpwalkcache (
		hostid int,
		last_updated int,
		text MEDIUMTEXT,
		PRIMARY KEY (hostid),
		CONSTRAINT snmpwalkcache_hosts_fk FOREIGN KEY (hostid) REFERENCES hosts(id)
	) ENGINE=InnoDB
	' );
    set_db_version( "2.7.9" );
}

if ( db_version_lower("2.7.10") ) {
    $dbh->do( '
        CREATE TABLE objectinfo (
		id INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
		content TEXT
	) ENGINE=InnoDB
	' );
    $dbh->do( "ALTER TABLE hosts ADD COLUMN objectinfo INT" );
    $dbh->do( "ALTER TABLE hosts ADD INDEX(objectinfo)" );
    $dbh->do(
        "ALTER TABLE hosts ADD CONSTRAINT objectinfo_by_fk FOREIGN KEY (objectinfo) REFERENCES objectinfo(id)"
    );
    set_db_version( "2.7.10" );
}

if ( db_version_lower("2.7.11") ) {
    $dbh->do(
        "ALTER TABLE contacts CHANGE rss live_feed INT NOT NULL DEFAULT 1"
    );
    set_db_version( "2.7.11" );
}

if ( db_version_lower("2.7.12") ) {
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces MODIFY COLUMN warning varchar(30)"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces MODIFY COLUMN critical varchar(30)"
    );

    # Remove uniqueness about name column
    $dbh->do( "ALTER TABLE contacts DROP INDEX name" );
    $dbh->do( "ALTER TABLE contacts ADD INDEX (name)" );
    set_db_version( "2.7.12" );
}

if ( db_version_lower("2.7.13") ) {

    # Cannot reliably work between 4.10, 4.11 and 5.x
    #$dbh->do("ALTER TABLE servicechecksnmppolling ADD PRIMARY KEY(id)");
    #$dbh->do("DROP INDEX id ON servicechecksnmppolling");
    set_db_version( "2.7.13" );
}

if ( db_version_lower("2.7.14") ) {
    $dbh->do( "DROP INDEX name ON contacts" );
    set_db_version( "2.7.14" );
}

if ( db_version_lower("2.7.15") ) {
    $dbh->do(
        "ALTER TABLE embeddedservices ADD COLUMN description varchar(255)"
    );
    $dbh->do( "ALTER TABLE embeddedservices DROP INDEX template_name" );
    $dbh->do( "ALTER TABLE embeddedservices DROP COLUMN template_name" );
    $dbh->do( "ALTER TABLE embeddedservices ADD UNIQUE INDEX (name)" );
    $dbh->do(
        'UPDATE embeddedservices SET name="Interface", description="SNMP Interface Polling" WHERE id=1'
    );
    set_db_version( "2.7.15" );
}

if ( db_version_lower("2.7.16") ) {
    $dbh->do( "INSERT INTO icons (name, filename) VALUES ('LOGO - Xen', 'xen')"
    );
    $dbh->do( "UPDATE hosts SET icon='LOGO - Xen' WHERE icon='LOGO - Zen'" );
    $dbh->do( "DELETE FROM icons WHERE name='LOGO - Zen'" );
    set_db_version( "2.7.16" );
}

if ( db_version_lower("2.7.17") ) {
    $dbh->do( "ALTER TABLE hosts MODIFY COLUMN name varchar(64)" );
    $dbh->do( "ALTER TABLE servicechecks MODIFY COLUMN name varchar(64)" );
    $dbh->do( "ALTER TABLE monitoringservers MODIFY COLUMN name varchar(64)" );
    set_db_version( "2.7.17" );
}

if ( db_version_lower("2.7.18") ) {
    $dbh->do( "ALTER TABLE servicechecks ADD COLUMN volatile INT DEFAULT 0" );
    set_db_version( "2.7.18" );
}

if ( db_version_lower("2.7.19") ) {

    # Update embeddedservices to ensure servicegroup isnt null.  If it is,
    # register against Operations group (create as necessary)
    {
        my $emb = $dbh->selectrow_array(
            "SELECT servicegroup FROM embeddedservices WHERE id=1"
        );
        unless ($emb) {
            my $sg = $dbh->selectrow_array(
                "SELECT id FROM servicegroups WHERE name = 'Operations'"
            );
            unless ($sg) {
                $dbh->do(
                    "INSERT INTO servicegroups (name,uncommitted) VALUES('Operations',1)"
                );
                $sg = $dbh->{'mysql_insertid'};
            }
            $dbh->do( "UPDATE embeddedservices SET servicegroup=$sg WHERE id=1"
            );
        }
    }

    # modify host check commands to deprecate check_host_alive_snmp in host check
    # drop down, change those that use it to check_host_alive_ping, and install
    # new check_host_alive_vnc script
    {
        $dbh->do( "UPDATE hosts SET check_command=1 WHERE check_command = 6" );
        $dbh->do(
            "INSERT INTO hostcheckcommands (id, name, command) VALUES(10, 'tcp port 5900 (VNC)','check_host_alive_vnc')"
        );
    }
    set_db_version( "2.7.19" );
}

if ( db_version_lower("2.8.0") ) {
    $dbh->do( "RENAME TABLE notificationperiods TO timeperiods" );
    $dbh->do(
        "ALTER TABLE timeperiods ADD COLUMN uncommitted INT DEFAULT 0 NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE contacts DROP FOREIGN KEY contacts_notification_period_fk"
    );
    $dbh->do(
        "ALTER TABLE contacts ADD CONSTRAINT contacts_notification_period_fk FOREIGN KEY (notification_period) REFERENCES timeperiods(id)"
    );

    $dbh->do( "ALTER TABLE hosts DROP FOREIGN KEY hosts_notification_period_fk"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD CONSTRAINT hosts_notification_period_fk FOREIGN KEY (notification_period) REFERENCES timeperiods(id)"
    );

    $dbh->do(
        "ALTER TABLE servicechecks DROP FOREIGN KEY servicechecks_notification_period_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecks ADD CONSTRAINT servicechecks_notification_period_fk FOREIGN KEY (notification_period) REFERENCES timeperiods(id)"
    );

    $dbh->do(
        "ALTER TABLE embeddedservices DROP FOREIGN KEY embeddedservices_notification_period_fk"
    );
    $dbh->do(
        "ALTER TABLE embeddedservices ADD CONSTRAINT embeddedservices_notification_period_fk FOREIGN KEY (notification_period) REFERENCES timeperiods(id)"
    );

    set_db_version( "2.8.0" );
}

if ( db_version_lower("2.8.1") ) {
    $dbh->do( "
	CREATE TABLE servicechecktimedoverridehostexceptions (
		id int AUTO_INCREMENT,
		servicecheck int NOT NULL,
		host int NOT NULL,
		timeperiod INT NOT NULL,
		args varchar(255) NOT NULL,
		PRIMARY KEY (id),
		UNIQUE (servicecheck, host),
		INDEX (servicecheck),
		CONSTRAINT servicechecktimedoverridehostexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id),
		INDEX (host),
		CONSTRAINT servicechecktimedoverridehostexceptions_host_fk FOREIGN KEY (host) REFERENCES hosts(id),
		INDEX (timeperiod),
		CONSTRAINT servicechecktimedoverridehostexceptions_timeperiod_fk FOREIGN KEY (timeperiod) REFERENCES timeperiods(id)
	) ENGINE=InnoDB;
	" );
    $dbh->do( "
	CREATE TABLE servicechecktimedoverridehosttemplateexceptions (
		id int AUTO_INCREMENT,
		servicecheck int NOT NULL,
		hosttemplate int NOT NULL,
		timeperiod INT NOT NULL,
		args varchar(255) NOT NULL,
		PRIMARY KEY (id),
		UNIQUE (servicecheck, hosttemplate),
		INDEX (servicecheck),
		CONSTRAINT servicechecktimedoverridehosttemplateexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id),
		INDEX (hosttemplate),
		CONSTRAINT servicechecktimedoverridehosttemplateexceptions_hosttemplate_fk FOREIGN KEY (hosttemplate) REFERENCES hosttemplates(id),
		INDEX(timeperiod),
		CONSTRAINT servicechecktimedoverridehosttemplateexceptions_timeperiod_fk FOREIGN KEY (timeperiod) REFERENCES timeperiods(id)
	) ENGINE=InnoDB;
	" );

    set_db_version( "2.8.1" );
}

if ( db_version_lower("2.8.2") ) {
    $dbh->do( "
	CREATE TABLE systempreferences (
		id int AUTO_INCREMENT,
		sms_system ENUM ('AQL', 'SMS4NMS' ),
		aql_username varchar(255),
		aql_password varchar(255),
		PRIMARY KEY (id)
	) ENGINE=InnoDB;
	" );

    # The default for an upgrade is to set SMS4NMS so that it is backward compatible with current users
    $dbh->do( "INSERT INTO systempreferences VALUES (1, 'SMS4NMS', '', '')" );
    set_db_version( "2.8.2" );
}

if ( db_version_lower("2.8.3") ) {
    $dbh->do(
        'UPDATE servicechecks SET args=REPLACE(args, "\'$SNMP_COMMUNITY$\'", "$SNMP_COMMUNITY$")'
    );
    set_db_version( "2.8.3" );
}

if ( db_version_lower("2.8.4") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN default_statusmap_layout INT'
    );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN default_statuswrl_layout INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN refresh_rate INT' );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN log_notifications INT'
    );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN log_service_retries INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN log_host_retries INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN log_event_handlers INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN log_initial_states INT'
    );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN log_external_commands INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN log_passive_checks INT'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD COLUMN daemon_dumps_core INT'
    );

    $dbh->do(
        "UPDATE systempreferences SET default_statusmap_layout=3,default_statuswrl_layout=2,refresh_rate=30,log_notifications=1,log_service_retries=1,log_host_retries=1,log_event_handlers=0,log_initial_states=1,log_external_commands=1,log_passive_checks=0,daemon_dumps_core=0"
    );
    set_db_version( "2.8.4" );
}

if ( db_version_lower("2.8.5") ) {
    $dbh->do(
        'ALTER TABLE contacts ADD COLUMN atom_max_items INT DEFAULT 30 NOT NULL'
    );
    $dbh->do(
        'ALTER TABLE contacts ADD COLUMN atom_max_age INT DEFAULT 1440 NOT NULL'
    );
    $dbh->do(
        'ALTER TABLE contacts ADD COLUMN atom_collapsed INT DEFAULT 1 NOT NULL'
    );

    set_db_version( "2.8.5" );
}

if ( db_version_lower("2.8.6") ) {
    $dbh->do( 'ALTER TABLE hostcheckcommands ADD COLUMN priority int DEFAULT 1'
    );

    # amend the data in the table
    $dbh->do(
        "UPDATE hostcheckcommands SET name='NRPE (on port 5666)' WHERE id = 7"
    );
    $dbh->do(
        "INSERT INTO hostcheckcommands (id, name, command) VALUES(11, 'NRPE (on port 5666 - non-SSL)','check_host_alive_nrpe_nossl')"
    );
    $dbh->do(
        "INSERT INTO hostcheckcommands (id, name, command) VALUES(12, 'tcp port 25 (SMTP)','check_host_alive_smtp')"
    );
    $dbh->do(
        "INSERT INTO hostcheckcommands (id, name, command) VALUES(13, 'tcp port 21 (FTP)','check_host_alive_ftp')"
    );

    $dbh->do( "UPDATE hostcheckcommands SET priority=1  WHERE id=9" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=2  WHERE id=1" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=3  WHERE id=13" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=4  WHERE id=3" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=5  WHERE id=4" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=6  WHERE id=12" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=7  WHERE id=2" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=8  WHERE id=8" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=9  WHERE id=5" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=10 WHERE id=10" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=11 WHERE id=7" );
    $dbh->do( "UPDATE hostcheckcommands SET priority=12 WHERE id=11" );

    set_db_version( "2.8.6" );
}

if ( db_version_lower("2.8.7") ) {
    $dbh->do(
        'ALTER TABLE hostsnmpinterfaces ADD COLUMN interfaceid TINYINT NOT NULL'
    );

    # Now correct all rows in the table
    my $sth = $dbh->prepare(
        "SELECT hostid,interfacename FROM hostsnmpinterfaces ORDER BY hostid,interfacename"
    );
    $sth->execute;
    my ( $hostid, $count );
    while ( my $row = $sth->fetchrow_hashref ) {
        if ( $hostid != $row->{hostid} ) {
            $count  = 0;
            $hostid = $row->{hostid};
        }
        $count++;
        $dbh->do(
            "UPDATE hostsnmpinterfaces SET interfaceid='$count' WHERE hostid='$hostid' AND interfacename=?",
            {}, $row->{interfacename}
        );
    }
    set_db_version( "2.8.7" );
}

if ( db_version_lower("2.8.8") ) {
    $dbh->do( 'ALTER TABLE hostsnmpinterfaces DROP COLUMN interfaceid' );
    $dbh->do(
        'ALTER TABLE hostsnmpinterfaces ADD COLUMN shortinterfacename varchar(52) NOT NULL'
    );
    my $sth = $dbh->prepare(
        "SELECT hostid,interfacename FROM hostsnmpinterfaces ORDER BY hostid,interfacename"
    );
    $sth->execute;
    my $hostid;
    my $count;
    my $length_limit = 52;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $shortname;
        if ( $row->{hostid} ne $hostid ) {
            $count  = 1;
            $hostid = $row->{hostid};
        }
        if ( length( $row->{interfacename} ) le $length_limit ) {
            $shortname = $row->{interfacename};
        }
        else {
            my $basename =
              substr( $row->{interfacename}, 0, $length_limit - 3 );
            $basename .= " ";
            $shortname = $basename .= $count;
            $count++;
        }
        $dbh->do(
            "UPDATE hostsnmpinterfaces SET shortinterfacename=? WHERE hostid='$row->{hostid}' AND interfacename=?",
            {}, $shortname, $row->{interfacename}
        );
    }
    set_db_version( "2.8.8" );
}

if ( db_version_lower("2.8.9") ) {
    local $dbh
      ->{RaiseError}; # Ignore error - some Opsview 2.8.2 systems will complain about this because already created
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN aql_proxy_server varchar(255)'
    );
    set_db_version( "2.8.9" );
}

if ( db_version_lower("2.8.10") ) {
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN other_addresses varchar(255) NOT NULL'
    );
    $dbh->do( 'ALTER TABLE hosts ADD COLUMN snmp_version ENUM ("2c", "3")' );
    $dbh->do( 'UPDATE hosts SET snmp_version = "2c"' );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmpv3_username varchar(128) NOT NULL'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmpv3_authprotocol ENUM ("md5", "sha")'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmpv3_authpassword varchar(128) NOT NULL'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmpv3_privprotocol ENUM ("des", "aes", "aes128")'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmpv3_privpassword varchar(128) NOT NULL'
    );
    set_db_version( "2.8.10" );
}

if ( db_version_lower("2.8.11") ) {
    $dbh->do( 'ALTER TABLE reloadtimes DROP COLUMN start_transfer' );
    $dbh->do( 'ALTER TABLE reloadtimes DROP COLUMN end_transfer' );
    set_db_version( "2.8.11" );
}

if ( db_version_lower("2.8.12") ) {
    $dbh->do( '
	CREATE TABLE reloadmessages (
		id int AUTO_INCREMENT,
		utime int NOT NULL,
		monitoringcluster int,
		severity ENUM ("warning", "critical") NOT NULL,
		message TEXT,
		PRIMARY KEY(id),
		INDEX (monitoringcluster),
		CONSTRAINT reloadmessages_monitoringcluster_fk FOREIGN KEY (monitoringcluster) REFERENCES monitoringservers(id)
        ) ENGINE=InnoDB;
	' );
    set_db_version( "2.8.12" );
}

if ( db_version_lower("2.8.13") ) {
    $dbh->do( 'ALTER TABLE hostsnmpinterfaces DROP PRIMARY KEY' );
    $dbh->do(
        'ALTER TABLE hostsnmpinterfaces ADD UNIQUE INDEX hostsnmpinterfaces_hostid_interfacename (hostid,interfacename)'
    );
    $dbh->do(
        'ALTER TABLE hostsnmpinterfaces ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST'
    );
    set_db_version( "2.8.13" );
}

if ( db_version_lower("2.8.14") ) {
    $dbh->do( 'ALTER TABLE hostgroups ADD COLUMN lft INT' );
    $dbh->do( 'ALTER TABLE hostgroups ADD COLUMN rgt INT' );
    set_db_version( "2.8.14" );
}

if ( db_version_lower("2.8.15") ) {
    $dbh->do( "ALTER TABLE hostgroups ADD COLUMN objectinfo INT" );
    $dbh->do( "ALTER TABLE hostgroups ADD INDEX (objectinfo)" );
    $dbh->do(
        "ALTER TABLE hostgroups ADD CONSTRAINT hostgroups_objectinfo_by_fk FOREIGN KEY (objectinfo) REFERENCES objectinfo(id)"
    );
    set_db_version( "2.8.15" );
}

if ( db_version_lower("2.8.16") ) {
    $dbh->do( "
		CREATE TABLE hostinfo (
			id INT NOT NULL PRIMARY KEY,
			information TEXT,
			CONSTRAINT hostinfo_hosts_fk FOREIGN KEY (id) REFERENCES hosts(id)
		) ENGINE=InnoDB
	" );
    $dbh->do( "
		CREATE TABLE hostgroupinfo (
			id INT NOT NULL PRIMARY KEY,
			information TEXT,
			CONSTRAINT hostgroupinfo_hostgroups_fk FOREIGN KEY (id) REFERENCES hostgroups(id)
		) ENGINE=InnoDB
	" );
    $dbh->do( "
		INSERT INTO hostinfo (id, information)
			SELECT h.id, o.content
			FROM hosts h
			JOIN objectinfo o ON o.id=h.objectinfo
	" );
    $dbh->do(
        'ALTER TABLE hostgroups DROP FOREIGN KEY hostgroups_objectinfo_by_fk'
    );
    $dbh->do( 'ALTER TABLE hostgroups DROP COLUMN objectinfo' );
    $dbh->do( 'ALTER TABLE hosts DROP FOREIGN KEY objectinfo_by_fk' );
    $dbh->do( 'ALTER TABLE hosts DROP COLUMN objectinfo' );
    $dbh->do( 'DROP TABLE objectinfo' );

    set_db_version( "2.8.16" );
}

if ( db_version_lower("2.8.17") ) {
    $dbh->do(
        'ALTER TABLE monitoringservers MODIFY COLUMN role ENUM ("Master", "Slave") DEFAULT "Slave"'
    );
    set_db_version( "2.8.17" );
}

if ( db_version_lower("2.8.18") ) {
    $dbh->do( '
		CREATE TABLE schema_version (
			major_release varchar(16),
			version varchar(16)
		) ENGINE=InnoDB
	' );
    set_db_version( "2.8.18" );
}

if ( db_version_lower("2.8.19") ) {
    $dbh->do(
        'UPDATE servicechecks SET args="-r" where plugin="check_opsview_slave"'
    );
    set_db_version( "2.8.19" );
}

my $db = Utils::DBVersion->new(
    {
        dbh  => $dbh,
        name => "opsview"
    }
);

if ( $db->is_lower("2.9.1") ) {
    $dbh->do( "ALTER TABLE hosts ADD COLUMN snmptrap_tracing INT DEFAULT 0" );
    $db->updated;
}

if ( $db->is_lower("2.9.2") ) {
    $dbh->do( "
	CREATE TABLE auditlogs (
		id int AUTO_INCREMENT,
		datetime datetime NOT NULL,
		username varchar(128) NOT NULL,
		reloadid int,
		text text NOT NULL,
		PRIMARY KEY (id)
	) ENGINE=InnoDB
	" );
    $db->updated;
}

if ( $db->is_lower("2.9.3") ) {
    $dbh->do(
        "ALTER TABLE systempreferences ADD COLUMN audit_log_retention INT"
    );
    $dbh->do( "UPDATE systempreferences SET audit_log_retention=365" );
    $db->updated;
}

if ( $db->is_lower("2.9.4") ) {
    $dbh->do( 'UPDATE checktypes SET name="SNMP trap" WHERE id=4' );
    $db->updated;
}

if ( $db->is_lower("2.10.1") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN host_info_url varchar(255)'
    );
    $dbh->do( "UPDATE systempreferences SET host_info_url=''" );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN hostgroup_info_url varchar(255)'
    );
    $dbh->do( "UPDATE systempreferences SET hostgroup_info_url=''" );
    $db->updated;
}

if ( $db->is_lower("2.10.2") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN soft_state_dependencies INT NOT NULL DEFAULT 0'
    );
    $dbh->do( "UPDATE systempreferences SET soft_state_dependencies=0" );
    $dbh->do(
        "UPDATE contacts SET notification_level=1 WHERE notification_level=0"
    );
    $db->updated;
}

if ( $db->is_lower("2.10.3") ) {
    $dbh->do(
        "UPDATE systempreferences SET soft_state_dependencies=0 WHERE soft_state_dependencies IS NULL"
    );
    $dbh->do(
        'ALTER TABLE hostcheckcommands ADD default_args VARCHAR(255) NULL AFTER command'
    );
    $dbh->do(
        'ALTER TABLE hostcheckcommands ADD plugin VARCHAR(128) NULL AFTER command'
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_ping',
	default_args = '-H \$HOSTADDRESS\$ -w 3000.0,80% -c 5000.0,100% -p 1'
	WHERE command = 'check_host_alive_ping';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 80 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_http';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 443 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_https';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_ssh',
	default_args = '-H \$HOSTADDRESS\$ -t 15'
	WHERE command = 'check_host_alive_ssh';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 23 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_telnet';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 5900 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_vnc';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_nrpe',
	default_args = '-H \$HOSTADDRESS\$'
	WHERE command = 'check_host_alive_nrpe';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_nrpe',
	default_args = '-n -H \$HOSTADDRESS\$'
	WHERE command = 'check_host_alive_nrpe_nossl';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 135 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_msrpc';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 25 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_smtp';
    "
    );
    $dbh->do(
        "UPDATE hostcheckcommands
	SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 21 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_ftp';
    "
    );

    # This appears to be on some systems
    if (
        $dbh->selectrow_array(
            "SELECT COUNT(*) FROM hostcheckcommands WHERE name='tcp port 161 (SNMP)'"
        ) == 0
      )
    {
        $dbh->do(
            "INSERT INTO hostcheckcommands (name,
                               command,
                               plugin,
                               default_args,
                               priority)
	VALUES ('tcp port 161 (SNMP)',
        'check_host_alive_snmp',
        'check_tcp',
        '-H \$HOSTADDRESS\$ -p 161 -w 9 -c 9 -t 15',
        13);
      "
        );
    }
    else {
        $dbh->do(
            "UPDATE hostcheckcommands
        SET plugin = 'check_tcp',
	default_args = '-H \$HOSTADDRESS\$ -p 161 -w 9 -c 9 -t 15'
	WHERE command = 'check_host_alive_snmp'
      "
        );
    }

    # If custom host check commands have been hacked in, we'll set a dummy command
    $dbh->do(
        "UPDATE hostcheckcommands SET plugin='check_dummy', default_args='2 \"Host check command could not be upgraded\"' WHERE plugin IS NULL"
    );

    $dbh->do(
        "ALTER TABLE hosts CHANGE check_command check_command INT(11) NULL"
    );
    $dbh->do(
        "UPDATE hosts SET check_command = NULL
	WHERE hosts.check_command IN (SELECT sc.id FROM hostcheckcommands sc WHERE sc.name = 'none')"
    );
    $dbh->do( "DELETE FROM hostcheckcommands WHERE name = 'none';" );
    $dbh->do( "ALTER TABLE hostcheckcommands DROP command" );
    $db->updated;
}

if ( $db->is_lower("2.10.4") ) {
    my $ping_priority = $dbh->selectrow_array(
        "SELECT priority FROM hostcheckcommands WHERE plugin='check_ping'"
    );
    my $highest_priority =
      $dbh->selectrow_array( "SELECT MAX(priority) + 1 FROM hostcheckcommands"
      );
    $dbh->do(
        "UPDATE hostcheckcommands SET priority=$highest_priority, name='slow ping' WHERE plugin='check_ping'"
    );
    $dbh->do(
        "INSERT INTO hostcheckcommands (name,
			plugin,
			default_args,
			priority)
		VALUES('ping', 'check_icmp','-H \$HOSTADDRESS\$ -t 3 -w 500.0,80% -c 1000.0,100%',$ping_priority)"
    );
    $db->updated;
}

if ( $db->is_lower("2.10.5") ) {
    $dbh->do(
        "ALTER TABLE hostcheckcommands CHANGE default_args default_args TEXT default NULL"
    );
    $dbh->do( "ALTER TABLE servicechecks CHANGE args args TEXT NOT NULL" );
    $dbh->do(
        "ALTER TABLE servicecheckhostexceptions CHANGE args args TEXT NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehostexceptions CHANGE args args TEXT NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE servicecheckhosttemplateexceptions CHANGE args args TEXT NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehosttemplateexceptions CHANGE args args TEXT NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("2.11.1") ) {
    $dbh->do(
        "CREATE TABLE hostserviceeventhandlers (
			hostid INT NOT NULL,
			servicecheckid INT NOT NULL,
			event_handler varchar(255) NOT NULL,
			PRIMARY KEY  (hostid, servicecheckid)
		) ENGINE=InnoDB
		COMMENT='Nagios event handlers for services on a per-host basis';
	"
    );
    $db->updated;
}

if ( $db->is_lower("2.11.2") ) {
    $dbh->do( 'ALTER TABLE hosts ADD COLUMN use_nmis int DEFAULT 0' );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN nmis_node_type ENUM ("router", "switch", "server") DEFAULT "router"'
    );
    $db->updated;
}

if ( $db->is_lower("2.11.3") ) {
    $dbh->do( "
	CREATE TABLE temporary_hostmonitoredbynode (
		hostid int NOT NULL,
		primary_node int,
		secondary_node int,
		PRIMARY KEY (hostid)
	) ENGINE=InnoDB COMMENT='Temporary table for lookup of host to node in a cluster'
	" );
    $db->updated;
}

if ( $db->is_lower("2.11.4") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN enable_odw_import INT DEFAULT 0'
    );
    my $enabled = 0;

    # Check crontabs to see if import_runtime is set
    open CRONTAB, "-|", "crontab", "-l";
    while (<CRONTAB>) {
        $enabled++ if /^[^#].*import_runtime/;
    }
    close CRONTAB;
    unless ($enabled) {
        open CRONTAB, "/etc/cron.d/opsview"; # Don't worry if file not found
        while (<CRONTAB>) {
            $enabled++ if /^[^#].*import_runtime/;
        }
        close CRONTAB;
    }
    if ($enabled) {
        $dbh->do( "UPDATE systempreferences SET enable_odw_import=1" );
    }
    $db->updated;
}

if ( $db->is_lower("2.11.5") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN opsview_server_name varchar(255) DEFAULT ""'
    );
    $db->updated;
}

if ( $db->is_lower("2.11.6") ) {
    $dbh->do(
        'CREATE TABLE notificationmethods (
		id int AUTO_INCREMENT,
		name varchar(64) NOT NULL,
		master tinyint(1) NOT NULL DEFAULT 0,
		command text,
		priority int NOT NULL DEFAULT 1,
		PRIMARY KEY(id),
		UNIQUE(name)
	) ENGINE=InnoDB'
    );
    $dbh->do(
        qq{INSERT INTO notificationmethods (id, name, master, command, priority) VALUES (1, "AQL", 0, "submit_sms_aql -u '%AQL_USERNAME%' -p '%AQL_PASSWORD%' -P '%AQL_PROXY_SERVER%'", 1)}
    );
    $dbh->do(
        qq{INSERT INTO notificationmethods (id, name, master, command, priority) VALUES (2, "SMS4NMS", 0, "submit_sms_script", 2)}
    );
    my $current_sms_system =
      $dbh->selectrow_array( "SELECT sms_system FROM systempreferences LIMIT 1"
      );
    $dbh->do(
        'ALTER TABLE `systempreferences` CHANGE `sms_system` `sms_system` INT(10) NOT NULL'
    );
    $dbh->do( 'ALTER TABLE systempreferences ADD INDEX (sms_system)' );
    $dbh->do(
        "ALTER TABLE systempreferences ADD CONSTRAINT systempreferences_notificationmethods_fk FOREIGN KEY (sms_system) REFERENCES notificationmethods(id)"
    );
    $dbh->do(
        "UPDATE systempreferences SET sms_system=(SELECT id FROM notificationmethods WHERE name='$current_sms_system')"
    );
    $db->updated;
}

if ( $db->is_lower("2.12.1") ) {
    $dbh->do(
        'CREATE TABLE rancid_vendors (
		id int AUTO_INCREMENT,
		name varchar(128) NOT NULL,
		rancid_name varchar(128) NOT NULL,
		PRIMARY KEY(id),
		UNIQUE(name)
	) ENGINE=InnoDB COMMENT="Vendor devices supported by rancid"'
    );

    $dbh->do(
        'ALTER TABLE hosts MODIFY COLUMN snmp_version ENUM ("2c", "3", "1") DEFAULT "2c"'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN use_rancid INT DEFAULT 0 AFTER snmptrap_tracing'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN rancid_vendor INT DEFAULT NULL AFTER use_rancid'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN rancid_username varchar(128) AFTER rancid_vendor'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN rancid_password varchar(255) AFTER rancid_username'
    );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN rancid_connection_type ENUM ("ssh", "telnet") DEFAULT "ssh" AFTER rancid_password'
    );
    $dbh->do( "ALTER TABLE hosts ADD INDEX (rancid_vendor)" );
    $dbh->do(
        "ALTER TABLE hosts ADD CONSTRAINT hosts_rancid_vendor_fk FOREIGN KEY (rancid_vendor) REFERENCES rancid_vendors(id)"
    );

    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN rancid_email_notification varchar(255) AFTER soft_state_dependencies'
    );

    $dbh->do(
        'CREATE TABLE application_plugins (
		name varchar(128),
		version varchar(16),
		created int,
		updated int,
		PRIMARY KEY(name)
	) ENGINE=InnoDB COMMENT="List of Opsview application plugins"'
    );
    $db->updated;
}

if ( $db->is_lower("2.12.2") ) {

    # Due to bug introduced in 1184 and fixed in 1187, but 2.12.5 was
    # released as 1185, have to treat this differently
    my $sth = $dbh->prepare( 'show columns from application_plugins' );
    $sth->execute;
    my $found = 0;
    while ( my @row = $sth->fetchrow ) {
        $found = 1 if $row[0] eq "menu";
    }
    if ( !$found ) {
        $dbh->do(
            'ALTER TABLE application_plugins ADD COLUMN menu varchar(128) AFTER name'
        );
        $dbh->do(
            'ALTER TABLE application_plugins ADD COLUMN link varchar(128) AFTER menu'
        );
    }
    $db->updated;
}

if ( $db->is_lower("2.12.3") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN odw_large_retention_months INT AFTER enable_odw_import'
    );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN odw_small_retention_months INT AFTER odw_large_retention_months'
    );
    $dbh->do(
        "UPDATE systempreferences SET odw_large_retention_months=0, odw_small_retention_months=0"
    );
    $db->updated;
}

if ( $db->is_lower("2.12.4") ) {
    $dbh->do(
        qq{
	CREATE TABLE hosttemplatemanagementurls (
		id int AUTO_INCREMENT,
		hosttemplateid int NOT NULL,
		name varchar(255) NOT NULL,
		url TEXT,
		priority int NOT NULL DEFAULT 1,
		PRIMARY KEY (id),
		INDEX (hosttemplateid),
		CONSTRAINT hosttemplatemanagementurls_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id)
	) ENGINE=InnoDB COMMENT='Management URLs based on this hosttemplate';
}
    );
    $db->updated;
}

if ( $db->is_lower("2.12.5") ) {
    $dbh->do(
        'ALTER TABLE servicechecks ADD COLUMN check_period INT AFTER agent'
    );
    $dbh->do( "ALTER TABLE servicechecks ADD INDEX (check_period)" );
    $dbh->do(
        "ALTER TABLE servicechecks ADD CONSTRAINT servicechecks_check_period_fk FOREIGN KEY (check_period) REFERENCES timeperiods(id)"
    );
    $dbh->do(
        "UPDATE servicechecks SET check_period=(SELECT id FROM timeperiods WHERE name='24x7')"
    );
    $db->updated;
}

if ( $db->is_lower("2.13.1") ) {
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN realm varchar(255) DEFAULT 'local' AFTER username"
    );
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN use_email int DEFAULT 0 AFTER password"
    );
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN use_mobile int DEFAULT 0 AFTER comment"
    );
    $dbh->do(
        "UPDATE contacts SET use_email=1 WHERE (email != '' AND email IS NOT NULL)"
    );
    $dbh->do(
        "UPDATE contacts SET use_mobile=1 WHERE (mobile != '' AND mobile IS NOT NULL)"
    );
    $db->updated;
}

if ( $db->is_lower("2.13.2") ) {
    $dbh->do(
        "ALTER TABLE hostgroupnotify DROP FOREIGN KEY hostgroupnotify_contactid_fk"
    );
    $dbh->do(
        "ALTER TABLE hostgroupnotify ADD CONSTRAINT hostgroupnotify_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE"
    );
    $dbh->do(
        "ALTER TABLE servicegroupnotify DROP FOREIGN KEY servicegroupnotify_contactid_fk"
    );
    $dbh->do(
        "ALTER TABLE servicegroupnotify ADD CONSTRAINT servicegroupnotify_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.1") ) {
    my $highest_priority =
      $dbh->selectrow_array( "SELECT MAX(priority) + 1 FROM hostcheckcommands"
      );
    $dbh->do(
        "INSERT INTO hostcheckcommands (
        name,
        plugin,
        default_args,
        priority)
    VALUES('tolerant ping', 'check_host','-H \$HOSTADDRESS\$ -n 5 -i 5s', $highest_priority )"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.2") ) {

    # Due to a mistake in the Opsview 2.14.1 release, db_opsview wasn't updated. So systems with
    # a schema version of 2.14.1 may already have this column. We test for it first before trying
    # to create it
    my $sth = $dbh->prepare( 'SHOW COLUMNS FROM systempreferences' );
    $sth->execute;
    my $found = 0;
    while ( my @row = $sth->fetchrow ) {
        $found = 1 if $row[0] eq "public_rrdgraphs";
    }
    if ( !$found ) {
        $dbh->do(
            'ALTER TABLE systempreferences ADD COLUMN public_rrdgraphs INT NOT NULL DEFAULT 0'
        );
    }
    $db->updated;
}

if ( $db->is_lower("2.14.3") ) {
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN viewport_summary_style varchar(255) DEFAULT "list"'
    );
    $db->updated;
}

if ( $db->is_lower("2.14.4") ) {
    $dbh->do(
        'ALTER TABLE hostsnmpinterfaces ADD COLUMN indexid int DEFAULT 0 AFTER critical'
    );
    $db->updated;
}

if ( $db->is_lower("2.14.5") ) {
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN sunday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN monday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN tuesday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN wednesday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN thursday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN friday VARCHAR(255)" );
    $dbh->do( "ALTER TABLE timeperiods MODIFY COLUMN saturday VARCHAR(255)" );
    $db->updated;
}

if ( $db->is_lower("2.14.6") ) {
    $dbh->do(
        "ALTER TABLE servicecheckdependencies DROP FOREIGN KEY servicecheckdependencies_dependencyid_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckdependencies ADD CONSTRAINT servicecheckdependencies_dependencyid_fk FOREIGN KEY (dependencyid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.7") ) {
    my $sth = $dbh->prepare( "SHOW TABLE STATUS" );
    $sth->execute;

    while ( my $table_info = $sth->fetchrow_hashref() ) {
        if ( $table_info->{engine} eq 'MyISAM' ) {
            $dbh->do( 'ALTER TABLE ' . $table_info->{name} . ' ENGINE=InnoDB'
            );
        }
    }
    $db->updated;
}

if ( $db->is_lower("2.14.8") ) {
    $dbh->do(
        "ALTER TABLE hostservicechecks ADD COLUMN remove_servicecheck tinyint DEFAULT 0 AFTER servicecheckid"
    );
    $db->updated;
}

if ( $db->is_lower("2.14.9") ) {
    print
      "Converting all <> in host and hostgroup information to escaped HTML characters\n";
    $dbh->do( "UPDATE hostinfo SET information=REPLACE(information,'<','&lt;')"
    );
    $dbh->do( "UPDATE hostinfo SET information=REPLACE(information,'>','&gt;')"
    );
    $dbh->do(
        "UPDATE hostgroupinfo SET information=REPLACE(information,'<','&lt;')"
    );
    $dbh->do(
        "UPDATE hostgroupinfo SET information=REPLACE(information,'>','&gt;')"
    );
    $db->updated;
}

if ( $db->is_lower("3.0.1") ) {
    require Opsview::Config;
    my $check_interval       = 5;
    my $retry_check_interval = 1;
    my $check_attempts       = 3;
    if ( Opsview::Config->nagios_interval_length_in_seconds ) {
        $check_interval       *= 60;
        $retry_check_interval *= 60;
    }
    my $interface_servicegroup = $dbh->selectrow_array(
        "SELECT servicegroup FROM embeddedservices WHERE id=1"
    );
    $dbh->do(
        "INSERT INTO embeddedservices SET
id=2,
name='Slave-node',
description='Slave node status',
servicegroup=$interface_servicegroup,
notification_options='w,c,r',
notification_interval=NULL,
notification_period=NULL,
check_interval=$check_interval,
retry_check_interval=$retry_check_interval,
check_attempts=3
"
    );
    $db->updated;
}

if ( $db->is_lower("3.0.2") ) {
    $db->print(
        "Updating all auditlog entries to UTC - this may take some time\n"
    );
    $dbh->do(
        "UPDATE auditlogs SET datetime=CONVERT_TZ(datetime, 'SYSTEM', '+00:00')"
    );
    $db->updated;
}

# Bit cheeky - this migration is run as if there is a db change, although no change has actually occurred
# at DB level. This ensures it is only run the once
if ( $db->is_lower("3.0.3") ) {
    $db->print(
        "Updating RRDs - running this in the background. Check /tmp/migrate_rrds.log for status\n"
    );
    $db->print(
        "When migration has finished, you will need to do an Opsview reload to get all the associated performance icons\n"
    );
    system(
        "nohup nice -n 20 /usr/local/nagios/installer/migrate_rrds -y >> /tmp/migrate_rrds.log 2>&1 &"
    );
    $db->updated;
}

if ( $db->is_lower("3.0.4") ) {
    require Opsview::Config;
    my $check_interval       = 2;
    my $retry_check_interval = 1;
    my $check_attempts       = 1;
    if ( Opsview::Config->nagios_interval_length_in_seconds ) {
        $check_interval       *= 60;
        $retry_check_interval *= 60;
    }
    my $interface_servicegroup = $dbh->selectrow_array(
        "SELECT servicegroup FROM embeddedservices WHERE id=1"
    );
    $dbh->do(
        "INSERT INTO embeddedservices SET
id=3,
name='Cluster-node',
description='Cluster node status',
servicegroup=$interface_servicegroup,
notification_options='w,c,r',
notification_interval=NULL,
notification_period=NULL,
check_interval=$check_interval,
retry_check_interval=$retry_check_interval,
check_attempts=$check_attempts
"
    );
    $db->updated;
}

if ( $db->is_lower("3.1.1") ) {
    $db->print( "New ACLs\n" );
    $dbh->do(
        qq{
	CREATE TABLE access (
		id int AUTO_INCREMENT,
		name varchar(128) NOT NULL,
		PRIMARY KEY (id),
		UNIQUE (name)
	) ENGINE=InnoDB
	}
    );
    $dbh->do( "ALTER TABLE roles DROP INDEX fixedname" );
    $dbh->do( "ALTER TABLE roles DROP fixedname" );
    $dbh->do( "ALTER TABLE roles ADD UNIQUE INDEX name (name)" );
    $dbh->do( "ALTER TABLE roles ADD description VARCHAR(255)" );
    $dbh->do( "ALTER TABLE roles ADD priority INT DEFAULT 1000" );
    $dbh->do( "ALTER TABLE roles ADD uncommitted INT DEFAULT 0 NOT NULL" );

    # Need to drop this constraint because of changes to the role table
    # Will recreate below
    $dbh->do( "ALTER TABLE contacts DROP FOREIGN KEY contacts_role_fk" );
    $dbh->do( "TRUNCATE roles" );

    $dbh->do(
        qq{
	CREATE TABLE roles_monitoringservers (
                roleid INT,
                monitoringserverid INT,
                PRIMARY KEY (roleid, monitoringserverid),
                INDEX (roleid),
                CONSTRAINT roles_monitoringservers_role_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
                INDEX (monitoringserverid),
                CONSTRAINT roles_monitoringservers_monitoringserver_fk FOREIGN KEY (monitoringserverid) REFERENCES monitoringservers(id)
        ) ENGINE=InnoDB;
	}
    );

    $dbh->do(
        qq{
	CREATE TABLE roles_access (
		roleid INT,
		accessid INT,
		PRIMARY KEY (roleid, accessid),
		INDEX (roleid),
		INDEX (accessid),
		CONSTRAINT roles_access_roles_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
		CONSTRAINT roles_access_access_fk FOREIGN KEY (accessid) REFERENCES access(id) ON DELETE CASCADE
	) ENGINE=InnoDB
	}
    );

    $dbh->do(
        qq{
	CREATE TABLE roles_hostgroups (
		roleid INT,
		hostgroupid INT,
		PRIMARY KEY (roleid, hostgroupid),
		INDEX (roleid),
		CONSTRAINT roles_hostgroups_role_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
		INDEX (hostgroupid),
		CONSTRAINT roles_hostgroups_hostgroup_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id) ON DELETE CASCADE
	) ENGINE=InnoDB
	}
    );

    $dbh->do( 'INSERT INTO access (id, name) VALUES (1, "VIEWALL")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (2, "VIEWSOME")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (3, "ACTIONALL")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (4, "ACTIONSOME")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (6, "NOTIFYSOME")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (7, "CONFIGUREHOSTS")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (8, "RELOADACCESS")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (9, "ADMINACCESS")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (10, "VIEWPORTACCESS")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (11, "RRDGRAPHS")' );

    $dbh->do(
        'INSERT INTO roles VALUES (1, "Public", "Access available for public users", 0, 0)'
    );
    $dbh->do( 'INSERT INTO roles_access VALUES (1, 10)' );

    $dbh->do(
        'INSERT INTO roles VALUES (2, "Authenticated user", "All authenticated users inherit this role", 0, 0)'
    );
    my $public_rrds =
      $dbh->selectrow_array( "SELECT public_rrdgraphs FROM systempreferences"
      );
    if ($public_rrds) {
        $dbh->do( "INSERT INTO roles_access VALUES (1,11)" );
    }
    else {
        $dbh->do( 'INSERT INTO roles_access VALUES (2,11)' );
    }

    # This is called Admin because the old role was this name. People using opsview_sync_ldap
    # will have an expectation that the role name has not changed
    $dbh->do(
        'INSERT INTO roles VALUES (10, "Admin", "Administrator access", 1, 0)'
    );
    $dbh->do(
        'INSERT INTO roles_access VALUES (10,1), (10,3), (10,6), (10,7), (10,9), (10,8)'
    );
    $dbh->do( 'INSERT INTO roles_hostgroups VALUES (10,1)' );

    $dbh->do(
        'INSERT INTO roles VALUES (11, "View all, change some", "Operator", 2, 0)'
    );
    $dbh->do( 'INSERT INTO roles_access VALUES (11,1), (11,6), (11,4)' );

    $dbh->do(
        'INSERT INTO roles VALUES (12, "View some, change some", "Restricted operator", 4, 0)'
    );
    $dbh->do( 'INSERT INTO roles_access VALUES (12,2), (12,6), (12,4)' );

    $dbh->do(
        'INSERT INTO roles VALUES (13, "View all, change none", "Read only user", 3, 0)'
    );
    $dbh->do( 'INSERT INTO roles_access VALUES (13,1), (13,6)' );

    $dbh->do(
        'INSERT INTO roles VALUES (14, "View some, change none", "Restricted read only user", 5, 0)'
    );
    $dbh->do( 'INSERT INTO roles_access VALUES (14,2), (14,6)' );

    $dbh->do( "UPDATE contacts SET role=role+9" );

    $dbh->do(
        "ALTER TABLE contacts ADD CONSTRAINT contacts_role_fk FOREIGN KEY (role) REFERENCES roles(id)"
    );

    $dbh->do( "ALTER TABLE hostgroups ADD COLUMN matpath TEXT NOT NULL" );
    $postupdate->{regenerate_hostgroups_lft_rgt}++;

    $dbh->do( "INSERT INTO metadata (name, value) VALUES ('uncommitted', 0)" );
    $db->updated;
}

if ( $db->is_lower("3.1.2") ) {
    $dbh->do( "ALTER TABLE systempreferences DROP COLUMN public_rrdgraphs" );
    $db->updated;
}

if ( $db->is_lower("3.1.3") ) {
    $db->print( "Checking for hostgroup constraint\n" );
    system( "/usr/local/nagios/installer/check_hostgroup_restrictions" );
    if ( $? != 0 ) {
        die(
            "Error with host group constraints - please fix and re-run upgrade"
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.1.4") ) {
    $db->print( "Adding extra host configuration values\n" );
    my $timeperiod_24x7_id =
      $dbh->selectrow_array( "SELECT id FROM timeperiods WHERE name='24x7'" );
    unless ($timeperiod_24x7_id) {

        # Use the lowest id number, which could be if a user has renamed id=1
        $timeperiod_24x7_id =
          $dbh->selectrow_array( "SELECT MIN(id) FROM timeperiods" );
    }
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN check_period INT DEFAULT NULL AFTER hostgroup"
    );
    $dbh->do( "UPDATE hosts SET check_period=?", {}, $timeperiod_24x7_id );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN check_interval VARCHAR(16) DEFAULT '0' AFTER check_period"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN retry_check_interval VARCHAR(16) DEFAULT '1' AFTER check_interval"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN check_attempts VARCHAR(16) DEFAULT '2' AFTER retry_check_interval"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD CONSTRAINT hosts_check_period_fk FOREIGN KEY (check_period) REFERENCES timeperiods(id)"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.1") ) {
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN show_welcome_page tinyint NOT NULL DEFAULT 1 AFTER notification_level"
    );
    $dbh->do( "UPDATE contacts SET show_welcome_page = 1" );
    $db->updated;
}

if ( $db->is_lower("3.3.2") ) {
    $dbh->do(
        "ALTER TABLE systempreferences ADD COLUMN send_anon_data tinyint NOT NULL DEFAULT 1 AFTER viewport_summary_style"
    );
    $dbh->do(
        "ALTER TABLE systempreferences ADD COLUMN uuid char(36) NOT NULL DEFAULT '' AFTER send_anon_data"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.3") ) {
    $dbh->do(
        qq{CREATE TABLE useragents (
                     id varchar(255) NOT NULL,
                     last_update datetime NOT NULL,
                     PRIMARY KEY  (id)) ENGINE=InnoDB }
    );
    $db->updated;
}

if ( $db->is_lower("3.3.4") ) {
    $dbh->do(
        "ALTER TABLE systempreferences ADD COLUMN updates_includemajor tinyint NOT NULL DEFAULT 1 AFTER uuid"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.5") ) {
    $db->print( "Adding language settings to contacts\n" );
    $dbh->do(
        "ALTER TABLE contacts ADD COLUMN language VARCHAR(10) NOT NULL DEFAULT '' AFTER password"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.6") ) {
    $db->print( "Adding rancid_autoenable to hosts\n" );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN rancid_autoenable int DEFAULT 0 AFTER rancid_connection_type"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.7") ) {
    $db->print( "Adding keywords to contacts table\n" );
    $dbh->do( "
	CREATE TABLE keywordcontacts (
		keywordid int NOT NULL,
		contactid int NOT NULL,
		PRIMARY KEY (keywordid, contactid),
		INDEX (keywordid),
		CONSTRAINT keywordcontacts_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE,
		INDEX (contactid),
		CONSTRAINT keywordcontacts_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
	) ENGINE=InnoDB;
	" );
    $db->updated;
}

if ( $db->is_lower("3.3.8") ) {
    $db->print( "Adding netdisco URL\n" );
    $dbh->do(
        "ALTER TABLE systempreferences ADD COLUMN netdisco_url varchar(255) NOT NULL DEFAULT '' AFTER uuid"
    );
    $db->updated;
}

if ( $db->is_lower("3.3.9") ) {
    $db->print( "Increasing useragent id column width\n" );

    # We force the table to be latin1 charset. Some DBs have defaulted to utf8 and varchar(760) is
    # too large. Setting table to latin1 causes the table to convert, then the following MODIFY COLUMN
    # will convert the column from utf8 to latin1. Anything currently on latin1 is not adversely affected
    $dbh->do( "ALTER TABLE useragents DEFAULT CHARSET='latin1'" );
    $dbh->do( "ALTER TABLE useragents MODIFY COLUMN id varchar(760) NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.5.1") ) {
    $db->print( "Increasing contact's mobile field\n" );
    $dbh->do( "ALTER TABLE contacts MODIFY COLUMN mobile varchar(128)" );
    $db->updated;
}

if ( $db->is_lower("3.5.2") ) {
    $db->print( "Adding freshness interval options to service checks\n" );
    $dbh->do(
        "ALTER TABLE servicechecks CHANGE COLUMN renotify check_freshness TINYINT NOT NULL DEFAULT 0"
    );
    $dbh->do(
        'ALTER TABLE servicechecks ADD COLUMN freshness_type ENUM ("renotify", "set_stale") DEFAULT "renotify" NOT NULL'
    );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN stale_threshold_seconds INT NOT NULL DEFAULT 3600"
    );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN stale_state TINYINT NOT NULL DEFAULT 0"
    );
    $dbh->do( "ALTER TABLE servicechecks ADD COLUMN stale_text TEXT NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.5.3") ) {
    $db->print( "Adding markdown filter\n" );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN markdown_filter TINYINT NOT NULL DEFAULT 0"
    );
    $db->updated;
}

if ( $db->is_lower("3.5.4") ) {
    $db->print( "Adding modules table\n" );
    $dbh->do(
        qq{
    CREATE TABLE modules (
        id INT AUTO_INCREMENT,
        name varchar(128) NOT NULL,
        url varchar(255) NOT NULL,
        description varchar(255) NOT NULL,
        access varchar(128) NOT NULL,
        enabled TINYINT DEFAULT 0,
        priority INT NOT NULL DEFAULT 1,
        version varchar(16) NOT NULL DEFAULT '',
        namespace varchar(255) NOT NULL DEFAULT '',
        PRIMARY KEY (id),
        UNIQUE (namespace)
    ) ENGINE=InnoDB COMMENT="Opsview modules"
}
    );
    $dbh->do(
        qq{INSERT INTO modules VALUES (1, "Nagvis", "/nagvis", "Nagios Visualisation", "", 1, 1, "", "com.opsera.opsview.modules.nagvis")}
    );
    $dbh->do(
        qq{INSERT INTO modules VALUES (2, "MRTG",   "/status/network_traffic", "Multi Router Traffic Grapher", "", 1, 2, "", "com.opsera.opsview.modules.mrtg")}
    );
    $dbh->do(
        qq{INSERT INTO modules VALUES (3, "NMIS",   "/cgi-nmis/nmiscgi.pl", "Network Management Information System", "ADMINACCESS", 1, 3, "", "com.opsera.opsview.modules.nmis")}
    );
    $db->updated;
}

if ( $db->is_lower("3.6.1") ) {
    $db->print(
        "Creating CONFIGUREVIEW and CONFIGURESAVE access and adding to all roles with ADMINACCESS\n"
    );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (12, "CONFIGUREVIEW")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (13, "CONFIGURESAVE")' );

    # Add CONFIGUREVIEW to ADMINACCESS roles
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 12 FROM roles_access WHERE accessid=9'
    );

    # Add CONFIGURESAVE to ADMINACCESS and CONFIGUREHOSTS
    $dbh->do(
        'INSERT INTO roles_access SELECT DISTINCT(roleid), 13 FROM roles_access WHERE accessid=9 OR accessid=7'
    );

    $db->updated;
}

if ( $db->is_lower("3.7.1") ) {
    $db->print( "Adding extra columns to notificationmethods\n" );
    $dbh->do(
        "ALTER TABLE notificationmethods ADD COLUMN active TINYINT(1) NOT NULL DEFAULT 1 AFTER id"
    );

    # Only set the one from systempreferences to be the active one
    $dbh->do( "UPDATE notificationmethods SET active=0" );
    my $sms_id =
      $dbh->selectrow_array( "SELECT sms_system FROM systempreferences" );
    $dbh->do( "UPDATE notificationmethods SET active=1 WHERE id=$sms_id" );

    # Update the submit_sms_aql command with the db vars
    my $old_aql_command =
      qq{submit_sms_aql -u '%AQL_USERNAME%' -p '%AQL_PASSWORD%' -P '%AQL_PROXY_SERVER%'};
    my $aql_username = $dbh->selectrow_array(
        'SELECT aql_username FROM systempreferences WHERE id=1'
    );
    my $aql_password = $dbh->selectrow_array(
        'SELECT aql_password FROM systempreferences WHERE id=1'
    );
    my $aql_proxy_server = $dbh->selectrow_array(
        'SELECT aql_proxy_server FROM systempreferences WHERE id=1'
    );
    my $new_aql_command = $old_aql_command;
    $new_aql_command =~ s/%AQL_USERNAME%/$aql_username/g;
    $new_aql_command =~ s/%AQL_PASSWORD%/$aql_password/g;
    $new_aql_command =~ s/%AQL_PROXY_SERVER%/$aql_proxy_server/g;
    $dbh->do( "UPDATE notificationmethods SET command=? WHERE command=?",
        {}, $new_aql_command, $old_aql_command );

    $dbh->do(
        "ALTER TABLE notificationmethods ADD COLUMN uncommitted TINYINT(1) DEFAULT 0 NOT NULL AFTER priority"
    );
    $dbh->do(
        "ALTER TABLE notificationmethods ADD COLUMN contact_variables TEXT AFTER uncommitted"
    );
    $dbh->do( "UPDATE notificationmethods SET contact_variables='PAGER'" );

    # Bump priority up for all current notificationmethods, so that Email is top of list
    $dbh->do( "UPDATE notificationmethods SET priority=priority+1" );

    $dbh->do(
        "INSERT INTO notificationmethods (active,name,master,command,priority,contact_variables) VALUES (1,'Email',0,'notify_by_email',1,'EMAIL')"
    );
    my $email_id = $dbh->selectrow_array(
        "SELECT id FROM notificationmethods WHERE name='Email'"
    );
    $dbh->do(
        "INSERT INTO notificationmethods (active,name,master,command,priority,contact_variables) VALUES (1,'RSS',1,'notify_by_rss',2000,'RSS_MAXIMUM_ITEMS,RSS_MAXIMUM_AGE,RSS_COLLAPSED')"
    );
    my $rss_id = $dbh->selectrow_array(
        "SELECT id FROM notificationmethods WHERE name='RSS'"
    );

    $dbh->do(
        qq{
    CREATE TABLE contact_variables (
        contactid int NOT NULL,
        name varchar(128) NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (contactid, name),
        INDEX (contactid),
        CONSTRAINT contact_variables_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
}
    );

    $dbh->do(
        qq{
    CREATE TABLE contact_notificationmethods (
        contactid int NOT NULL,
        notificationmethodid int NOT NULL,
        PRIMARY KEY (contactid, notificationmethodid),
        INDEX (contactid),
        CONSTRAINT contact_notificationmethods_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE,
        INDEX (notificationmethodid),
        CONSTRAINT contact_notificationmethods_notificationmethodid_fk FOREIGN KEY (notificationmethodid) REFERENCES notificationmethods(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
}
    );

    # Convert current information into this new table
    $dbh->do(
        "INSERT INTO contact_notificationmethods SELECT id, $email_id FROM contacts WHERE use_email=1"
    );
    $dbh->do(
        "INSERT INTO contact_notificationmethods SELECT id, $sms_id FROM contacts WHERE use_mobile=1"
    );
    $dbh->do(
        "INSERT INTO contact_notificationmethods SELECT id, $rss_id FROM contacts WHERE live_feed=1"
    );

    $dbh->do(
        "INSERT INTO contact_variables SELECT id, 'EMAIL', email FROM contacts WHERE use_email=1"
    );
    $dbh->do(
        "INSERT INTO contact_variables SELECT id, 'PAGER', mobile FROM contacts WHERE use_mobile=1"
    );
    $dbh->do(
        "INSERT INTO contact_variables SELECT id, 'RSS_MAXIMUM_ITEMS', atom_max_items FROM contacts WHERE live_feed=1"
    );
    $dbh->do(
        "INSERT INTO contact_variables SELECT id, 'RSS_MAXIMUM_AGE', atom_max_age FROM contacts WHERE live_feed=1"
    );
    $dbh->do(
        "INSERT INTO contact_variables SELECT id, 'RSS_COLLAPSED', atom_collapsed FROM contacts WHERE live_feed=1"
    );

    $db->updated;
}

if ( $db->is_lower("3.7.2") ) {
    $db->print( "Adding new notification profile tables\n" );

    $dbh->do( "DROP TABLE IF EXISTS notificationprofiles" );
    $dbh->do(
        qq{
    CREATE TABLE notificationprofiles (
        id int AUTO_INCREMENT,
        name varchar(128) NOT NULL,
        contactid int NOT NULL,
        host_notification_options varchar(16),
        service_notification_options varchar(16),
        notification_period int NOT NULL DEFAULT 1,
        all_hostgroups int DEFAULT 1 NOT NULL,
        all_servicegroups int DEFAULT 1 NOT NULL,
        notification_level int NOT NULL DEFAULT 1,
        priority INT DEFAULT 1000,
        uncommitted int DEFAULT 0 NOT NULL,
        PRIMARY KEY (id),
        INDEX (notification_period),
        CONSTRAINT notificationprofiles_notification_period_fk FOREIGN KEY (notification_period) REFERENCES timeperiods(id),
        INDEX (contactid),
        CONSTRAINT notificationprofiles_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Notification profiles';
}
    );

    # Create 1 notification profile for each existing contact based on existing data
    my $where_notifications_set =
      "((host_notification_options IS NOT NULL || host_notification_options = '') && (service_notification_options IS NOT NULL || service_notification_options = ''))";
    $dbh->do(
        "INSERT INTO notificationprofiles
SELECT id, 'Default', id,
  host_notification_options, service_notification_options, notification_period,
  all_hostgroups, all_servicegroups,
  notification_level, 1, 1
FROM contacts
WHERE $where_notifications_set "
    );

    # Create notificationprofiles joining tables
    $dbh->do( "DROP TABLE IF EXISTS notificationprofile_hostgroups" );
    $dbh->do(
        qq{
    CREATE TABLE notificationprofile_hostgroups (
        notificationprofileid int NOT NULL,
        hostgroupid           int NOT NULL,
        PRIMARY KEY (notificationprofileid, hostgroupid),
        INDEX (notificationprofileid),
        CONSTRAINT notificationprofile_hostgroups_notificationprofileid_fk FOREIGN KEY (notificationprofileid) REFERENCES notificationprofiles(id) ON DELETE CASCADE,
        INDEX (hostgroupid),
        CONSTRAINT notificationprofile_hostgroups_hostgroupid_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
}
    );
    $dbh->do(
        "INSERT INTO notificationprofile_hostgroups SELECT contactid, hostgroupid FROM hostgroupnotify, contacts WHERE contacts.id = contactid AND $where_notifications_set"
    );

    $dbh->do( "DROP TABLE IF EXISTS notificationprofile_servicegroups" );
    $dbh->do(
        qq{
    CREATE TABLE notificationprofile_servicegroups (
        notificationprofileid int NOT NULL,
        servicegroupid        int NOT NULL,
        PRIMARY KEY (notificationprofileid, servicegroupid),
        INDEX (notificationprofileid),
        CONSTRAINT notificationprofile_servicegroups_notificationprofileid_fk FOREIGN KEY (notificationprofileid) REFERENCES notificationprofiles(id) ON DELETE CASCADE,
        INDEX (servicegroupid),
        CONSTRAINT notificationprofile_servicegroups_servicegroupid_fk FOREIGN KEY (servicegroupid) REFERENCES servicegroups(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
}
    );
    $dbh->do(
        "INSERT INTO notificationprofile_servicegroups SELECT contactid, servicegroupid FROM servicegroupnotify, contacts WHERE contacts.id = contactid AND $where_notifications_set"
    );

    $dbh->do( "DROP TABLE IF EXISTS notificationprofile_keywords" );
    $dbh->do(
        qq{
    CREATE TABLE notificationprofile_keywords (
        notificationprofileid int NOT NULL,
        keywordid             int NOT NULL,
        PRIMARY KEY (notificationprofileid, keywordid),
        INDEX (notificationprofileid),
        CONSTRAINT notificationprofile_keywords_notificationprofileid_fk FOREIGN KEY (notificationprofileid) REFERENCES notificationprofiles(id) ON DELETE CASCADE,
        INDEX (keywordid),
        CONSTRAINT notificationprofile_keywords_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
}
    );
    $dbh->do(
        "INSERT INTO notificationprofile_keywords SELECT contactid, keywordid FROM keywordcontacts, contacts WHERE contacts.id = contactid AND $where_notifications_set"
    );

    $dbh->do( "DROP TABLE IF EXISTS contact_keywords" );
    $dbh->do(
        qq{
    CREATE TABLE contact_keywords (
        contactid int NOT NULL,
        keywordid int NOT NULL,
        PRIMARY KEY (contactid, keywordid),
        INDEX (keywordid),
        CONSTRAINT contact_keywords_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE,
        INDEX (contactid),
        CONSTRAINT contact_keywords_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Keywords contact has access to';
}
    );
    $dbh->do(
        "INSERT INTO contact_keywords SELECT contactid, keywordid FROM keywordcontacts"
    );

    $dbh->do( "DROP TABLE IF EXISTS contact_hostgroups" );
    $dbh->do(
        qq{
    CREATE TABLE contact_hostgroups (
        contactid   int NOT NULL,
        hostgroupid int NOT NULL,
        PRIMARY KEY (contactid, hostgroupid),
        INDEX (hostgroupid),
        CONSTRAINT contact_hostgroups_hostgroupid_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id) ON DELETE CASCADE,
        INDEX (contactid),
        CONSTRAINT contact_hostgroups_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Host groups contact has access to';
}
    );
    $dbh->do(
        "INSERT INTO contact_hostgroups SELECT contactid, hostgroupid FROM hostgroupnotify"
    );

    $dbh->do( "DROP TABLE IF EXISTS contact_servicegroups" );
    $dbh->do(
        qq{
    CREATE TABLE contact_servicegroups (
        contactid      int NOT NULL,
        servicegroupid int NOT NULL,
        PRIMARY KEY (contactid, servicegroupid),
        INDEX (servicegroupid),
        CONSTRAINT contact_servicegroups_servicegroupid_fk FOREIGN KEY (servicegroupid) REFERENCES servicegroups(id) ON DELETE CASCADE,
        INDEX (contactid),
        CONSTRAINT contact_servicegroups_contactid_fk FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Service groups contact has access to';
}
    );
    $dbh->do(
        "INSERT INTO contact_servicegroups SELECT contactid, servicegroupid FROM servicegroupnotify"
    );

    $dbh->do( "DROP TABLE IF EXISTS notificationprofile_notificationmethods" );
    $dbh->do(
        qq{
    CREATE TABLE notificationprofile_notificationmethods (
        notificationprofileid int NOT NULL,
        notificationmethodid  int NOT NULL,
        PRIMARY KEY (notificationprofileid, notificationmethodid),
        INDEX (notificationprofileid),
        CONSTRAINT notificationprofile_notificationmethods_notificationprofileid_fk FOREIGN KEY (notificationprofileid) REFERENCES notificationprofiles(id) ON DELETE CASCADE,
        INDEX (notificationmethodid),
        CONSTRAINT notificationprofile_notificationmethods_notificationmethodid_fk FOREIGN KEY (notificationmethodid) REFERENCES notificationmethods(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Notification profile with multiple notification methods';
}
    );
    $dbh->do(
        "INSERT INTO notificationprofile_notificationmethods SELECT contactid,notificationmethodid FROM contact_notificationmethods,contacts WHERE contacts.id=contactid AND $where_notifications_set"
    );

    # Drop old tables
    $dbh->do( "DROP TABLE hostgroupnotify" );
    $dbh->do( "DROP TABLE servicegroupnotify" );
    $dbh->do( "DROP TABLE keywordcontacts" );
    $dbh->do( "DROP TABLE contact_notificationmethods" );
    $db->updated;
}

if ( $db->is_lower("3.7.3") ) {
    $db->print( 'Adding flap detection field for hosts', $/ );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN flap_detection_enabled int DEFAULT 1 AFTER snmptrap_tracing'
    );
    $db->updated;
}

if ( $db->is_lower("3.7.4") ) {
    $db->print( 'Adding namespace to notificationmethods', $/ );
    $dbh->do(
        'ALTER TABLE notificationmethods ADD COLUMN namespace VARCHAR(255) NOT NULL AFTER name'
    );
    $dbh->do( 'UPDATE notificationmethods SET namespace=name' );
    $dbh->do(
        "UPDATE notificationmethods SET namespace='com.opsview.notificationmethods.email' WHERE name='Email'"
    );
    $dbh->do(
        "UPDATE notificationmethods SET namespace='com.opsview.notificationmethods.rss' WHERE name='RSS'"
    );
    $dbh->do(
        "UPDATE notificationmethods SET namespace='com.opsview.notificationmethods.aql', command='submit_sms_aql' WHERE name='AQL' AND command LIKE 'submit_sms_aql %'"
    );
    $dbh->do(
        "UPDATE notificationmethods SET namespace='com.opsview.notificationmethods.smsgateway' WHERE (name='SMS4NMS' OR name='SMS Notification Module') AND command='submit_sms_script'"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.5") ) {
    $db->print( 'Adding notificationmethod variables table', $/ );
    $dbh->do(
        "CREATE TABLE notificationmethod_variables (
       notificationmethodid int NOT NULL,
       name varchar(128) NOT NULL,
       value TEXT,
       PRIMARY KEY (notificationmethodid, name),
       INDEX (notificationmethodid),
       CONSTRAINT notificationmethod_variables_notificationmethodid_fk FOREIGN KEY (notificationmethodid) REFERENCES notificationmethods(id) ON DELETE CASCADE
   ) ENGINE=InnoDB;
"
    );

    # Add the AQL variables into notificationmethods variables
    my $aql_id = $dbh->selectrow_array(
        "SELECT id FROM notificationmethods WHERE namespace='com.opsview.notificationmethods.aql'"
    );
    if ($aql_id) {
        my $aql_username = $dbh->selectrow_array(
            'SELECT aql_username FROM systempreferences WHERE id=1'
        );
        my $aql_password = $dbh->selectrow_array(
            'SELECT aql_password FROM systempreferences WHERE id=1'
        );
        my $aql_proxy_server = $dbh->selectrow_array(
            'SELECT aql_proxy_server FROM systempreferences WHERE id=1'
        );
        $dbh->do(
            "INSERT INTO notificationmethod_variables VALUES (?, 'AQL_USERNAME', ?)",
            {}, $aql_id, $aql_username
        );
        $dbh->do(
            "INSERT INTO notificationmethod_variables VALUES (?, 'AQL_PASSWORD', ?)",
            {}, $aql_id, $aql_password
        );
        $dbh->do(
            "INSERT INTO notificationmethod_variables VALUES (?, 'AQL_PROXY_SERVER', ?)",
            {}, $aql_id, $aql_proxy_server
        );
    }

    $db->updated;
}

if ( $db->is_lower("3.7.6") ) {
    $db->print( 'Removing redundant system preferences', $/ );
    $dbh->do(
        "ALTER TABLE systempreferences DROP FOREIGN KEY systempreferences_notificationmethods_fk"
    );
    $dbh->do( "ALTER TABLE systempreferences DROP INDEX sms_system" );
    $dbh->do(
        "ALTER TABLE systempreferences DROP COLUMN sms_system, DROP COLUMN aql_username, DROP COLUMN aql_password, DROP COLUMN aql_proxy_server"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.7") ) {
    $db->print( 'Adding constraint to notificationprofiles', $/ );
    $dbh->do(
        "ALTER TABLE notificationprofiles ADD UNIQUE notificationprofiles_name_contactid (name, contactid)"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.8") ) {
    $db->print( 'Adding new columns for keywords', $/ );
    $dbh->do(
        "ALTER TABLE keywords ADD COLUMN all_hosts SMALLINT DEFAULT 0 NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE keywords ADD COLUMN all_servicechecks SMALLINT DEFAULT 0 NOT NULL"
    );
    $dbh->do(
        "ALTER TABLE keywords ADD COLUMN uncommitted SMALLINT DEFAULT 0 NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.9") ) {
    $db->print( 'Adding eventhandlers to servicechecks', $/ );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN event_handler VARCHAR(255) NOT NULL DEFAULT ''"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.10") ) {
    $db->print( 'Adding foreign key checks to hostserviceeventhandlers table',
        $/ );
    $dbh->do(
        "ALTER TABLE hostserviceeventhandlers ADD INDEX servicecheckid (servicecheckid)"
    );
    $dbh->do( "ALTER TABLE hostserviceeventhandlers ADD INDEX hostid (hostid)"
    );

    # Delete foreign keys that don't exist anymore before adding constraints
    $dbh->do(
        "DELETE hostserviceeventhandlers FROM hostserviceeventhandlers LEFT JOIN hosts ON hostid = hosts.id WHERE hosts.id IS NULL"
    );
    $dbh->do(
        "DELETE hostserviceeventhandlers FROM hostserviceeventhandlers LEFT JOIN servicechecks ON servicecheckid = servicechecks.id WHERE servicechecks.id IS NULL"
    );

    $dbh->do(
        "ALTER TABLE hostserviceeventhandlers ADD CONSTRAINT hostserviceeventhandlers_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );
    $dbh->do(
        "ALTER TABLE hostserviceeventhandlers ADD CONSTRAINT hostserviceeventhandlers_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.11") ) {
    $db->print( 'Adding on delete to foreign key checks', $/ );
    $dbh->do(
        "ALTER TABLE hosthosttemplates DROP FOREIGN KEY hosthosttemplates_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosthosttemplates ADD CONSTRAINT hosthosttemplates_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hosthosttemplates DROP FOREIGN KEY hosthosttemplates_hosttemplateid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosthosttemplates ADD CONSTRAINT hosthosttemplates_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hostservicechecks DROP FOREIGN KEY hostservicechecks_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE hostservicechecks ADD CONSTRAINT hostservicechecks_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hostservicechecks DROP FOREIGN KEY hostservicechecks_servicecheckid_fk"
    );
    $dbh->do(
        "ALTER TABLE hostservicechecks ADD CONSTRAINT hostservicechecks_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hosttemplateservicechecks DROP FOREIGN KEY hosttemplateservicechecks_hosttemplateid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosttemplateservicechecks ADD CONSTRAINT hosttemplateservicechecks_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hosttemplateservicechecks DROP FOREIGN KEY hosttemplateservicechecks_servicecheckid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosttemplateservicechecks ADD CONSTRAINT hosttemplateservicechecks_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hosthosttemplates DROP FOREIGN KEY hosthosttemplates_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosthosttemplates ADD CONSTRAINT hosthosttemplates_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicecheckhostexceptions DROP FOREIGN KEY servicecheckhostexceptions_servicecheck_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckhostexceptions ADD CONSTRAINT servicecheckhostexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicecheckhostexceptions DROP FOREIGN KEY servicecheckhostexceptions_host_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckhostexceptions ADD CONSTRAINT servicecheckhostexceptions_host_fk FOREIGN KEY (host) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehostexceptions DROP FOREIGN KEY servicechecktimedoverridehostexceptions_servicecheck_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehostexceptions ADD CONSTRAINT servicechecktimedoverridehostexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehostexceptions DROP FOREIGN KEY servicechecktimedoverridehostexceptions_host_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehostexceptions ADD CONSTRAINT servicechecktimedoverridehostexceptions_host_fk FOREIGN KEY (host) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicecheckhosttemplateexceptions DROP FOREIGN KEY servicecheckhosttemplateexceptions_servicecheck_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckhosttemplateexceptions ADD CONSTRAINT servicecheckhosttemplateexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicecheckhosttemplateexceptions DROP FOREIGN KEY servicecheckhosttemplateexceptions_hosttemplate_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckhosttemplateexceptions ADD CONSTRAINT servicecheckhosttemplateexceptions_hosttemplate_fk FOREIGN KEY (hosttemplate) REFERENCES hosttemplates(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehosttemplateexceptions DROP FOREIGN KEY servicechecktimedoverridehosttemplateexceptions_servicecheck_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehosttemplateexceptions ADD CONSTRAINT servicechecktimedoverridehosttemplateexceptions_servicecheck_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehosttemplateexceptions DROP FOREIGN KEY servicechecktimedoverridehosttemplateexceptions_hosttemplate_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecktimedoverridehosttemplateexceptions ADD CONSTRAINT servicechecktimedoverridehosttemplateexceptions_hosttemplate_fk FOREIGN KEY (hosttemplate) REFERENCES hosttemplates(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces DROP FOREIGN KEY hostsnmpinterfaces_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces ADD CONSTRAINT hostsnmpinterfaces_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE snmptraprules DROP FOREIGN KEY snmptraprules_servicechecks_fk"
    );
    $dbh->do(
        "ALTER TABLE snmptraprules ADD CONSTRAINT snmptraprules_servicechecks_fk FOREIGN KEY (servicecheck) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE keywordhosts DROP FOREIGN KEY keywordhosts_keywordid_fk"
    );
    $dbh->do(
        "ALTER TABLE keywordhosts ADD CONSTRAINT keywordhosts_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE keywordhosts DROP FOREIGN KEY keywordhosts_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE keywordhosts ADD CONSTRAINT keywordhosts_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE keywordservicechecks DROP FOREIGN KEY keywordservicechecks_keywordid_fk"
    );
    $dbh->do(
        "ALTER TABLE keywordservicechecks ADD CONSTRAINT keywordservicechecks_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE keywordservicechecks DROP FOREIGN KEY keywordservicechecks_servicecheckid_fk"
    );
    $dbh->do(
        "ALTER TABLE keywordservicechecks ADD CONSTRAINT keywordservicechecks_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );

    $dbh->do(
        "ALTER TABLE hosttemplatemanagementurls DROP FOREIGN KEY hosttemplatemanagementurls_hosttemplateid_fk"
    );
    $dbh->do(
        "ALTER TABLE hosttemplatemanagementurls ADD CONSTRAINT hosttemplatemanagementurls_hosttemplateid_fk FOREIGN KEY (hosttemplateid) REFERENCES hosttemplates(id) ON DELETE CASCADE"
    );

    $db->updated;
}

if ( $db->is_lower("3.7.12") ) {
    $db->print( 'Adding default monitored_by for hosts', $/ );
    $dbh->do( "ALTER TABLE hosts MODIFY monitored_by INT DEFAULT 1 NOT NULL" );
    $db->updated;
}

if ( $db->is_lower("3.7.13") ) {
    $dbh->do(
        "ALTER TABLE hostperformancemonitors DROP FOREIGN KEY hostperformancemonitors_hostid_fk"
    );
    $dbh->do(
        "ALTER TABLE hostperformancemonitors ADD CONSTRAINT hostperformancemonitors_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.14") ) {
    $dbh->do( "ALTER TABLE parents DROP FOREIGN KEY parents_hostid_fk" );
    $dbh->do(
        "ALTER TABLE parents ADD CONSTRAINT parents_hostid_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $dbh->do( "ALTER TABLE parents DROP FOREIGN KEY parents_parentid_fk" );
    $dbh->do(
        "ALTER TABLE parents ADD CONSTRAINT parents_parentid_fk FOREIGN KEY (parentid) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $dbh->do(
        "DELETE FROM parents WHERE hostid IN (SELECT host FROM monitoringclusternodes)"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.15") ) {
    $db->print( 'Adding default notification_interval for hosts', $/ );
    $dbh->do(
        "UPDATE hosts SET notification_interval=60 WHERE notification_interval IS NULL"
    );
    $dbh->do(
        "ALTER TABLE hosts MODIFY notification_interval INT DEFAULT 60 NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.16") ) {
    $db->print( 'Adding host attributes', $/ );
    $dbh->do( "
CREATE TABLE attributes (
  id INT AUTO_INCREMENT,
  name VARCHAR(64) NOT NULL,
  internally_generated TINYINT DEFAULT 0 NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (name)
) ENGINE=InnoDB
" );
    $dbh->do( "
CREATE TABLE host_attributes (
  host INT NOT NULL,
  attribute INT NOT NULL,
  value varchar(64) NOT NULL,
  arg1 TEXT DEFAULT '',
  arg2 TEXT DEFAULT '',
  arg3 TEXT DEFAULT '',
  arg4 TEXT DEFAULT '',
  arg5 TEXT DEFAULT '',
  arg6 TEXT DEFAULT '',
  arg7 TEXT DEFAULT '',
  arg8 TEXT DEFAULT '',
  arg9 TEXT DEFAULT '',
  PRIMARY KEY (host, attribute, value),
  INDEX (host),
  CONSTRAINT host_attributes_host_fk FOREIGN KEY (host) REFERENCES hosts(id) ON DELETE CASCADE,
  INDEX (attribute),
  CONSTRAINT host_attributes_attribute_fk FOREIGN KEY (attribute) REFERENCES attributes(id) ON DELETE CASCADE
) ENGINE=InnoDB
" );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (1,'SLAVENODE',1)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (2,'INTERFACE',1)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (3,'CLUSTERNODE',1)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (4,'DISK',0)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (5,'URL',0)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (6,'PROCESS',0)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (7,'NRPE_PORT',0)"
    );
    $dbh->do(
        "INSERT INTO `attributes` (`id`, `name`, `internally_generated`) VALUES (8,'SSH_PORT',0)"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.17") ) {
    $db->print( 'Adding to servicecheck multiple services flag', $/ );
    $dbh->do( "ALTER TABLE servicechecks ADD COLUMN attribute INT DEFAULT NULL"
    );
    $dbh->do( "ALTER TABLE servicechecks ADD INDEX (attribute)" );
    $dbh->do(
        "ALTER TABLE servicechecks ADD CONSTRAINT servicechecks_attribute_fk FOREIGN KEY (attribute) REFERENCES attributes(id)"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.18") ) {
    $db->print( 'Converting Slave-node checks to servicecheck', $/ );

    # Check if there already is something called "Slave-node"
    if (
        $dbh->selectrow_array(
            "SELECT 1 FROM servicechecks WHERE name='Slave-node'")
      )
    {
        die
          "There already is a service check called 'Slave-node' - remove and rerun the upgrade";
    }

    my (
        $notification_interval, $notification_period, $servicegroup,
        $notification_options,  $check_interval,      $retry_check_interval,
        $check_attempts
      )
      = $dbh->selectrow_array(
        "SELECT notification_interval, notification_period, servicegroup, notification_options, check_interval, retry_check_interval, check_attempts FROM embeddedservices WHERE id=2"
      );

    my $check_period =
      $dbh->selectrow_array( "SELECT id FROM timeperiods WHERE name='24x7'" );
    my $attributeid =
      $dbh->selectrow_array( "SELECT id FROM attributes WHERE name='SLAVENODE'"
      );

    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
event_handler,
attribute
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", {},
        "Slave-node",
        "Slave node status",
        $notification_interval,
        $notification_period,
        $servicegroup,
        $notification_options,
        $check_interval,
        $retry_check_interval,
        $check_attempts,
        1,
        $check_period,
        "check_opsview_slave_node",
        '%SLAVENODE%',
        "slave_node_resync",
        $attributeid
    );
    my $scid = $dbh->selectrow_array(
        "SELECT id FROM servicechecks WHERE name='Slave-node'"
    );

    # Setup association to master opsview server
    my $opsviewmaster =
      $dbh->selectrow_array( "SELECT host FROM monitoringservers WHERE id=1" );
    $dbh->do(
        "INSERT INTO hostservicechecks (hostid, servicecheckid) VALUES ($opsviewmaster, $scid)"
    );

    $db->updated;
}

if ( $db->is_lower("3.7.19") ) {
    $db->print( 'Adding to servicecheck multiple services flag', $/ );
    foreach my $i ( 1 .. 9 ) {
        $dbh->do(
            "ALTER TABLE attributes ADD COLUMN label$i VARCHAR(16) NOT NULL DEFAULT ''"
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.7.20") ) {
    $db->print( 'Converting Interface checks to servicecheck', $/ );

    # Check if there already is something called "Interface"
    if (
        $dbh->selectrow_array(
            "SELECT 1 FROM servicechecks WHERE name='Interface'")
      )
    {
        die
          "There already is a service check called 'Interface' - remove and rerun the upgrade";
    }

    my (
        $notification_interval, $notification_period, $servicegroup,
        $notification_options,  $check_interval,      $retry_check_interval,
        $check_attempts
      )
      = $dbh->selectrow_array(
        "SELECT notification_interval, notification_period, servicegroup, notification_options, check_interval, retry_check_interval, check_attempts FROM embeddedservices WHERE id=1"
      );

    my $check_period =
      $dbh->selectrow_array( "SELECT id FROM timeperiods WHERE name='24x7'" );
    my $attributeid =
      $dbh->selectrow_array( "SELECT id FROM attributes WHERE name='INTERFACE'"
      );

    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
attribute
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", {},
        "Interface",
        "SNMP Interface polling",
        $notification_interval,
        $notification_period,
        $servicegroup,
        $notification_options,
        $check_interval,
        $retry_check_interval,
        $check_attempts,
        1,
        $check_period,
        "check_snmp_linkstatus",
        '-H $HOSTADDRESS$ %INTERFACE:1%',
        $attributeid
    );
    my $scid = $dbh->selectrow_array(
        "SELECT id FROM servicechecks WHERE name='Interface'"
    );

    # Setup association to all hosts with snmpinterfaces
    my $hostids_arrayref = $dbh->selectcol_arrayref(
        "SELECT DISTINCT(hostid) FROM hostsnmpinterfaces"
    );
    foreach my $hostid (@$hostids_arrayref) {
        $dbh->do(
            "INSERT INTO hostservicechecks (hostid, servicecheckid) VALUES ($hostid, $scid)"
        );
    }

    $db->updated;
}

if ( $db->is_lower("3.7.21") ) {
    $db->print( 'Converting Cluster-node checks to servicecheck', $/ );

    # Check if there already is something called "Cluster-node"
    if (
        $dbh->selectrow_array(
            "SELECT 1 FROM servicechecks WHERE name='Cluster-node'")
      )
    {
        die
          "There already is a service check called 'Cluster-node' - remove and rerun the upgrade";
    }

    my (
        $notification_interval, $notification_period, $servicegroup,
        $notification_options,  $check_interval,      $retry_check_interval,
        $check_attempts
      )
      = $dbh->selectrow_array(
        "SELECT notification_interval, notification_period, servicegroup, notification_options, check_interval, retry_check_interval, check_attempts FROM embeddedservices WHERE id=3"
      );

    my $check_period =
      $dbh->selectrow_array( "SELECT id FROM timeperiods WHERE name='24x7'" );
    my $attributeid = $dbh->selectrow_array(
        "SELECT id FROM attributes WHERE name='CLUSTERNODE'"
    );

    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
event_handler,
attribute
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", {},
        "Cluster-node",
        "Cluster node status and takeover",
        $notification_interval,
        $notification_period,
        $servicegroup,
        $notification_options,
        $check_interval,
        $retry_check_interval,
        $check_attempts,
        1,
        $check_period,
        "check_opsview_slave_cluster",
        '%CLUSTERNODE:1%',
        'cluster_node_takeover_hosts',
        $attributeid
    );
    my $scid = $dbh->selectrow_array(
        "SELECT id FROM servicechecks WHERE name='Cluster-node'"
    );

    # Setup association to all opsview slave nodes
    my $opsviewmaster =
      $dbh->selectrow_array( "SELECT host FROM monitoringservers WHERE id=1" );
    $dbh->do(
        "INSERT INTO hostservicechecks SELECT host, $scid, 0 FROM monitoringclusternodes"
    );

    $db->updated;
}

if ( $db->is_lower("3.7.22") ) {
    $db->print( 'Dummy step', $/ );
    $db->updated;
}

if ( $db->is_lower("3.7.23") ) {
    $db->print( 'Removing embeddedservices table', $/ );
    $dbh->do( "DROP TABLE embeddedservices" );
    $db->updated;
}

if ( $db->is_lower("3.7.24") ) {
    $db->print( 'Migrating MRTG to host snmp tab', $/ );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN use_mrtg TINYINT DEFAULT 0 NOT NULL"
    );
    $dbh->do( "
UPDATE hosts, hostperformancemonitors
SET hosts.use_mrtg=1
WHERE hosts.id=hostperformancemonitors.hostid
 AND hostperformancemonitors.performancemonitorid=7
" );
    $dbh->do( "
UPDATE hosts, hosthosttemplates, hosttemplateperformancemonitors
SET hosts.use_mrtg=1
WHERE hosts.id=hosthosttemplates.hostid
 AND hosthosttemplates.hosttemplateid=hosttemplateperformancemonitors.hosttemplateid
 AND hosttemplateperformancemonitors.performancemonitorid=7
" );
    $db->updated;
}

if ( $db->is_lower("3.7.25") ) {
    $db->print( 'Set not null on remove_servicecheck', $/ );
    $dbh->do(
        "UPDATE hostservicechecks SET remove_servicecheck=0 WHERE remove_servicecheck IS NULL"
    );
    $dbh->do(
        "ALTER TABLE hostservicechecks MODIFY remove_servicecheck tinyint DEFAULT 0 NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.26") ) {
    $db->print( 'Set disable_name_change for servicechecks', $/ );
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN disable_name_change TINYINT NOT NULL DEFAULT 0"
    );
    $dbh->do(
        "UPDATE servicechecks SET disable_name_change=1 WHERE name IN ('Cluster-node','Slave-node','Interface')"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.27") ) {
    $db->print( 'Set new options for SNMP polling', $/ );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling ADD COLUMN label VARCHAR(255)"
    );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling ADD COLUMN calculate_rate TINYINT NOT NULL DEFAULT 0"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.28") ) {
    $db->print( 'Set missing cascade deletes for host objects', $/ );
    $dbh->do(
        "ALTER TABLE snmpwalkcache DROP FOREIGN KEY snmpwalkcache_hosts_fk"
    );
    $dbh->do(
        "ALTER TABLE snmpwalkcache ADD CONSTRAINT snmpwalkcache_hosts_fk FOREIGN KEY (hostid) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $dbh->do( "ALTER TABLE hostinfo DROP FOREIGN KEY hostinfo_hosts_fk" );
    $dbh->do(
        "ALTER TABLE hostinfo ADD CONSTRAINT hostinfo_hosts_fk FOREIGN KEY (id) REFERENCES hosts(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.29") ) {
    $db->print( 'Reset disable_name_change on special service checks', $/ );
    $dbh->do(
        "UPDATE servicechecks SET disable_name_change=1 WHERE name IN ('Cluster-node','Slave-node','Interface')"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.30") ) {
    $db->print( 'Converting calculate_rate into ENUM', $/ );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling CHANGE COLUMN calculate_rate old_calculate_rate TINYINT"
    );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling ADD COLUMN calculate_rate ENUM('no','per_second','per_minute','per_hour') DEFAULT 'no' NOT NULL"
    );
    $dbh->do(
        "UPDATE servicechecksnmppolling SET calculate_rate='per_second' WHERE old_calculate_rate=1"
    );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling DROP COLUMN old_calculate_rate"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.31") ) {
    $db->print( 'Add enable SNMP option', $/ );
    $dbh->do(
        "UPDATE hosts SET snmp_community = '' WHERE snmp_community IS NULL"
    );
    $dbh->do(
        "UPDATE hosts SET snmpv3_username = '' WHERE snmpv3_username IS NULL"
    );
    $dbh->do(
        "UPDATE hosts SET snmpv3_authpassword = '' WHERE snmpv3_authpassword IS NULL"
    );
    $dbh->do(
        "UPDATE hosts SET snmpv3_privpassword = '' WHERE snmpv3_privpassword IS NULL"
    );
    $dbh->do(
        "ALTER TABLE hosts MODIFY COLUMN snmp_community VARCHAR(255) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE hosts MODIFY COLUMN snmpv3_username VARCHAR(128) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE hosts MODIFY COLUMN snmpv3_authpassword VARCHAR(128) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE hosts MODIFY COLUMN snmpv3_privpassword VARCHAR(128) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE hosts ADD COLUMN enable_snmp TINYINT DEFAULT 0 NOT NULL AFTER icon"
    );
    $dbh->do(
        'UPDATE hosts SET enable_snmp=1 WHERE (((snmp_version = "1" OR snmp_version = "2c") AND snmp_community != "") OR (snmp_version = "3" AND snmpv3_authpassword != ""))'
    );
    $db->updated;
}

if ( $db->is_lower("3.7.32") ) {
    $db->print( 'Add more snmp interface options', $/ );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces CHANGE COLUMN warning throughput_warning varchar(30)"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces CHANGE COLUMN critical throughput_critical varchar(30)"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces ADD COLUMN errors_warning varchar(30) AFTER throughput_critical"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces ADD COLUMN errors_critical varchar(30) AFTER errors_warning"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces ADD COLUMN discards_warning varchar(30) AFTER errors_critical"
    );
    $dbh->do(
        "ALTER TABLE hostsnmpinterfaces ADD COLUMN discards_critical varchar(30) AFTER discards_warning"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.33") ) {
    $db->print( 'Add default snmp interface option', $/ );
    $dbh->do(
        "INSERT INTO hostsnmpinterfaces (hostid, interfacename,active) SELECT DISTINCT(hostid),'',0 FROM hostsnmpinterfaces"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.34") ) {
    $db->print( 'Add notice column and indexes into auditlogs', $/ );
    $dbh->do(
        "ALTER TABLE auditlogs ADD COLUMN notice TINYINT DEFAULT 0 NOT NULL AFTER reloadid"
    );
    $dbh->do( "ALTER TABLE auditlogs ADD INDEX (datetime), ADD INDEX (notice)"
    );
    $db->updated;
}

if ( $db->is_lower("3.7.35") ) {
    $db->print( 'Update Interface service check with new args' );
    my ( $oldargs, $olddescription ) = $dbh->selectrow_array(
        'SELECT args,description FROM servicechecks WHERE name="Interface"'
    );
    if ( !defined $oldargs ) {
        die
          "The service check named 'Interface' has been removed - this needs to be recreated before re-running the upgrade";
    }
    my $newargs = '-H $HOSTADDRESS$ -i -o %INTERFACE:1% %INTERFACE:2%';
    if ( $oldargs ne '-H $HOSTADDRESS$ %INTERFACE:1%' ) {
        $db->add_notice(
            "Changing arguments for service check 'Interface'. Was args='$oldargs', now args='$newargs'"
        );
    }
    $dbh->do( "UPDATE servicechecks SET args=? WHERE name='Interface'",
        {}, $newargs );
    if ( $olddescription eq "SNMP Interface Polling" ) {
        $dbh->do(
            "UPDATE servicechecks SET description=? WHERE name='Interface'",
            {}, 'SNMP interface throughput'
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.7.36") ) {
    $db->print( 'Adding Errors and Discards multi service checks' );

    my $already_exists = $dbh->selectrow_array(
        "SELECT name FROM servicechecks WHERE name='Errors'"
    );
    if ($already_exists) {
        die
          "There is a service check called 'Errors' - this is expected to be an Opsview specific service check. Please rename the existing service check before re-running the upgrade";
    }

    $already_exists = $dbh->selectrow_array(
        "SELECT name FROM servicechecks WHERE name='Dicards'"
    );
    if ($already_exists) {
        die
          "There is a service check called 'Discards' - this is expected to be an Opsview specific service check. Please rename the existing service check before re-running the upgrade";
    }

    my (
        $notification_interval, $notification_period, $servicegroup,
        $notification_options,  $check_interval,      $retry_check_interval,
        $check_attempts,        $check_period
      )
      = $dbh->selectrow_array(
        "SELECT notification_interval, notification_period, servicegroup, notification_options, check_interval, retry_check_interval, check_attempts,check_period FROM servicechecks WHERE name='Interface'"
      );
    if ( !defined $servicegroup ) {
        die
          "The service check named 'Interface' has been removed - this needs to be recreated before re-running the upgrade";
    }

    my $attributeid =
      $dbh->selectrow_array( "SELECT id FROM attributes WHERE name='INTERFACE'"
      );

    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
attribute,
disable_name_change
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", {},
        "Errors",
        "SNMP interface errors per minute",
        $notification_interval,
        $notification_period,
        $servicegroup,
        $notification_options,
        $check_interval,
        $retry_check_interval,
        $check_attempts,
        1,
        $check_period,
        "check_snmp_linkstatus",
        '-H $HOSTADDRESS$ %INTERFACE:1% -E %INTERFACE:3%',
        $attributeid,
        1,
    );
    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
attribute,
disable_name_change
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", {},
        "Discards",
        "SNMP interface discards per minute",
        $notification_interval,
        $notification_period,
        $servicegroup,
        $notification_options,
        $check_interval,
        $retry_check_interval,
        $check_attempts,
        1,
        $check_period,
        "check_snmp_linkstatus",
        '-H $HOSTADDRESS$ %INTERFACE:1% -D %INTERFACE:4%',
        $attributeid,
        1,
    );
    $db->updated;
}

if ( $db->is_lower("3.7.37") ) {
    $db->print( "Creating PASSWORDSAVE access and adding non-system roles\n" );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (14, "PASSWORDSAVE")' );

    # Add PASSWORDSAVE to all roles
    $dbh->do(
        'INSERT INTO roles_access SELECT DISTINCT(roleid), 14 FROM roles_access WHERE roleid >= 10'
    );

    $db->updated;
}

if ( $db->is_lower("3.9.1") ) {
    $db->print( "Ensuring DEFAULT CHARSET for table useragents is latin1" );
    $dbh->do( "ALTER TABLE useragents DEFAULT CHARSET='latin1'" );
    $db->updated;
}

# Due to an error in the 3.8 branch, 3.9.2 is considered part of the 3.8 branch. If there are any other changes
# that will be back ported to 3.8 branch, create a 3.8.1 action instead
if ( $db->is_lower("3.9.2") ) {
    $db->print( "Stripping all right padded spaces in snmp interface names" );
    $dbh->do(
        "UPDATE hostsnmpinterfaces SET shortinterfacename=RTRIM(shortinterfacename) WHERE shortinterfacename LIKE '% '"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.3") ) {
    $db->print( "Creating sessions table" );
    $dbh->do(
        'CREATE TABLE sessions (
        id char(72) PRIMARY KEY,
        session_data TEXT,
        expires int(10)
        ) ENGINE=InnoDB COMMENT="Opsview-Web session information stored directly by Catalyst"
        '
    );
    $dbh->do(
        'CREATE TABLE api_sessions (
        token char(72) PRIMARY KEY,
        expires_at int(10) NOT NULL,
        accessed_at int(10) NOT NULL,
        username varchar(128) NOT NULL,
        ip varchar(128) NOT NULL,
        INDEX (expires_at)
        ) ENGINE=InnoDB COMMENT="Opsview API2 session information"
        '
    );
    $dbh->do(
        'CREATE TABLE api_auditlogs (
        id int AUTO_INCREMENT,
        datetime datetime NOT NULL,
        username varchar(128) NOT NULL,
        text text NOT NULL,
        PRIMARY KEY (id),
        INDEX (datetime)
        ) ENGINE=InnoDB COMMENT="API2 audit logs";
        '
    );

    $db->updated;
}

if ( $db->is_lower("3.9.4") ) {
    $db->print( "Creating delete cascade for servicecheck dependencies" );
    $dbh->do(
        "ALTER TABLE servicecheckdependencies DROP FOREIGN KEY servicecheckdependencies_servicecheckid_fk"
    );
    $dbh->do(
        "ALTER TABLE servicecheckdependencies ADD CONSTRAINT servicecheckdependencies_servicecheckid_fk FOREIGN KEY (servicecheckid) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.5") ) {
    $db->print( "Adding unique name constraint to service groups" );
    $dbh->do( "ALTER TABLE servicegroups ADD CONSTRAINT UNIQUE (name)" );
    $db->updated;
}

if ( $db->is_lower("3.9.6") ) {
    $db->print(
        "Adding unique constraint to snmptraprules - confirming there are no duplicates first"
    );
    my $sth =
      $dbh->prepare( "SELECT id, servicecheck, name FROM snmptraprules" );
    $sth->execute;
    my $names;
    while ( my $row = $sth->fetchrow_hashref ) {

        # If name already exists, suffix with row id. This could have problems if by chance a name has this suffix already
        if ( $names->{ $row->{servicecheck} }->{ lc( $row->{name} ) } ) {
            $dbh->do(
                "UPDATE snmptraprules SET name=? WHERE id=?",
                {}, $row->{name} . " - " . $row->{id},
                $row->{id}
            );
        }
        $names->{ $row->{servicecheck} }->{ lc( $row->{name} ) } = 1;
    }
    $dbh->do(
        "ALTER TABLE snmptraprules ADD CONSTRAINT UNIQUE snmptraprules_name_servicecheck (name, servicecheck)"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.7") ) {
    $db->print(
        "Adding unique constraint to hosttemplatemanagementurls - confirming there are no duplicates first"
    );
    my $sth = $dbh->prepare(
        "SELECT id, hosttemplateid, name FROM hosttemplatemanagementurls"
    );
    $sth->execute;
    my $names;
    while ( my $row = $sth->fetchrow_hashref ) {

        # If name already exists, suffix with row id. This could have problems if by chance a name has this suffix already
        if ( $names->{ $row->{hosttemplateid} }->{ lc( $row->{name} ) } ) {
            $dbh->do(
                "UPDATE hosttemplatemanagementurls SET name=? WHERE id=?",
                {}, $row->{name} . " - " . $row->{id},
                $row->{id}
            );
        }
        $names->{ $row->{hosttemplateid} }->{ lc( $row->{name} ) } = 1;
    }
    $dbh->do(
        "ALTER TABLE hosttemplatemanagementurls ADD CONSTRAINT UNIQUE hosttemplatemanagementurls_name_hosttemplateid (name, hosttemplateid)"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.8") ) {
    $db->print( "Removing NULLs from timeperiods table" );
    $dbh->do( "
ALTER TABLE timeperiods
MODIFY COLUMN alias VARCHAR(128) NOT NULL,
MODIFY COLUMN sunday VARCHAR(255) NOT NULL,
MODIFY COLUMN monday VARCHAR(255) NOT NULL,
MODIFY COLUMN tuesday VARCHAR(255) NOT NULL,
MODIFY COLUMN wednesday VARCHAR(255) NOT NULL,
MODIFY COLUMN thursday VARCHAR(255) NOT NULL,
MODIFY COLUMN friday VARCHAR(255) NOT NULL,
MODIFY COLUMN saturday VARCHAR(255) NOT NULL
" );
    $db->updated;
}

if ( $db->is_lower("3.9.9") ) {
    $db->print( 'Set missing cascade deletes for servicecheck objects', $/ );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling DROP FOREIGN KEY servicechecksnmppolling_servicechecks_fk"
    );
    $dbh->do(
        "ALTER TABLE servicechecksnmppolling ADD CONSTRAINT servicechecksnmppolling_servicechecks_fk FOREIGN KEY (id) REFERENCES servicechecks(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.10") ) {
    $db->print( 'Convert hostcheckcommands table to include constraints' );

    # Check that adding constraint is not going to error
    if (
        $dbh->selectrow_array(
            "SELECT COUNT(*) FROM hostcheckcommands LEFT JOIN plugins ON hostcheckcommands.plugin=plugins.name WHERE plugins.name IS NULL"
        )
      )
    {
        print
          "There are host check commands that exist that do not use a valid plugin. Please check these host check commands:\n";
        my $sth = $dbh->prepare(
            "SELECT hostcheckcommands.name AS name, hostcheckcommands.plugin AS plugin FROM hostcheckcommands LEFT JOIN plugins ON hostcheckcommands.plugin=plugins.name WHERE plugins.name IS NULL"
        );
        $sth->execute;
        while ( my $row = $sth->fetchrow_hashref ) {
            print " Name:" . $row->{name} . ", Plugin:" . $row->{plugin} . "\n";
        }
        die( "Upgrade step cancelled - please fix and rerun upgrade" );
    }

    $dbh->do(
        "ALTER TABLE hostcheckcommands ADD INDEX (plugin), ADD CONSTRAINT hostcheckcommands_plugins_fk FOREIGN KEY (plugin) REFERENCES plugins(name)"
    );
    $dbh->do(
        "ALTER TABLE hostcheckcommands ADD COLUMN uncommitted TINYINT DEFAULT 0 NOT NULL, CHANGE COLUMN default_args args TEXT DEFAULT '' NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.11") ) {
    $db->print( 'Set missing uncommitted flag for attributes' );
    $dbh->do(
        "ALTER TABLE attributes ADD COLUMN uncommitted TINYINT DEFAULT 0 NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.12") ) {
    $db->print( 'Removing and renaming columns in contacts table' );
    $dbh->do(
        "ALTER TABLE contacts DROP FOREIGN KEY contacts_notification_period_fk, DROP INDEX notification_period, DROP INDEX username"
    );
    $dbh->do(
        "ALTER TABLE contacts DROP COLUMN use_email, DROP COLUMN email, DROP COLUMN use_mobile, DROP COLUMN mobile, DROP COLUMN host_notification_options, DROP COLUMN service_notification_options, DROP COLUMN notification_period, DROP COLUMN live_feed, DROP COLUMN notification_level, DROP COLUMN atom_max_items, DROP COLUMN atom_max_age, DROP COLUMN atom_collapsed"
    );
    $dbh->do(
        "ALTER TABLE contacts CHANGE COLUMN name fullname varchar(128) NOT NULL, CHANGE COLUMN username name varchar(128) NOT NULL, CHANGE COLUMN comment description VARCHAR(255) NOT NULL, CHANGE COLUMN password encrypted_password varchar(128)"
    );
    $dbh->do( "ALTER TABLE contacts ADD UNIQUE INDEX (name)" );
    $db->updated;
}

if ( $db->is_lower("3.9.13") ) {
    $db->print( 'Adding default attribute values' );
    $dbh->do(
        "ALTER TABLE attributes ADD COLUMN default_value TEXT DEFAULT '' NOT NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.14") ) {
    $db->print( 'Adding default attribute args' );
    $dbh->do(
        "ALTER TABLE attributes CHANGE default_value value VARCHAR(64) NOT NULL DEFAULT ''"
    );
    $dbh->do(
        "ALTER TABLE attributes
      ADD COLUMN arg1 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg2 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg3 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg4 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg5 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg6 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg7 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg8 TEXT NOT NULL DEFAULT '',
      ADD COLUMN arg9 TEXT NOT NULL DEFAULT ''"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.15") ) {
    $db->print( 'Adding index for faster viewport summary queries' );
    $dbh->do( "ALTER TABLE keywords ADD INDEX enabled (enabled, id)" );
    $db->updated;
}

if ( $db->is_lower("3.9.16") ) {
    $db->print( 'Adding SNMP port to hosts table' );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmp_port SMALLINT DEFAULT 161 AFTER snmp_version'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.17") ) {
    $db->print( 'Adding extra ODW option for full imports' );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN enable_full_odw_import SMALLINT DEFAULT 0 AFTER enable_odw_import'
    );
    $dbh->do(
        "UPDATE systempreferences SET enable_full_odw_import=enable_odw_import"
    );
    $db->updated;
}

if ( $db->is_lower("3.9.18") ) {
    $db->print(
        'Removing extra spaces at end of service check names and host attribute values'
    );
    $dbh->do( 'UPDATE servicechecks SET name=RTRIM(name)' );
    $dbh->do( 'UPDATE host_attributes SET value=RTRIM(value)' );
    $dbh->do( 'UPDATE attributes SET value=RTRIM(value)' );
    $db->updated;
}

if ( $db->is_lower("3.9.19") ) {
    $db->print(
        'Removing duplicated event handler configuration from host monitor to use central one instead'
    );
    $dbh->do( '
DELETE FROM hostserviceeventhandlers
USING servicechecks, hostserviceeventhandlers
WHERE servicechecks.id=hostserviceeventhandlers.servicecheckid
 AND servicechecks.event_handler = hostserviceeventhandlers.event_handler
' );
    $db->updated;
}

if ( $db->is_lower("3.9.20") ) {
    $db->print( "Adding Enterprise module links" );
    unless (
        $dbh->selectrow_array(
            "SELECT 1 FROM modules WHERE namespace='com.opsera.opsview.modules.reports'"
        )
      )
    {
        $dbh->do(
            "INSERT INTO modules SET name='Reports', namespace='com.opsera.opsview.modules.reports', description='Opsview Reports Module', url='http://www.opsview.com/products/enterprise-modules/reports', access='ADMINACCESS', enabled=1, priority=500"
        );
    }
    unless (
        $dbh->selectrow_array(
            "SELECT 1 FROM modules WHERE namespace='com.opsera.opsview.modules.servicedesk'"
        )
      )
    {
        $dbh->do(
            "INSERT INTO modules SET name='Service Desk Connector', namespace='com.opsera.opsview.modules.servicedesk', description='Opsview Service Desk Connector', url='http://www.opsview.com/products/enterprise-modules/service-desk-connector', access='ADMINACCESS', enabled=1, priority=501"
        );
    }
    unless (
        $dbh->selectrow_array(
            "SELECT 1 FROM modules WHERE namespace='com.opsera.opsview.modules.smsmessaging'"
        )
      )
    {
        $dbh->do(
            "INSERT INTO modules SET name='SMS Messaging', namespace='com.opsera.opsview.modules.smsmessaging', description='Opsview SMS Messaging', url='http://www.opsview.com/products/enterprise-modules/sms-messaging', access='ADMINACCESS', enabled=1, priority=502"
        );
    }
    unless (
        $dbh->selectrow_array(
            "SELECT 1 FROM modules WHERE namespace='com.opsera.opsview.modules.rancid'"
        )
      )
    {
        $dbh->do(
            "INSERT INTO modules SET name='RANCID', namespace='com.opsera.opsview.modules.rancid', description='Opsview RANCID', url='http://www.opsview.com/products/enterprise-modules/rancid', access='ADMINACCESS', enabled=1, priority=503"
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.9.21") ) {
    $db->print( 'Fix default value for auditlogs table' );
    $dbh->do(
        'ALTER TABLE auditlogs MODIFY COLUMN username VARCHAR(128) NOT NULL DEFAULT ""'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.22") ) {
    $db->print( 'Enforcing keyword name restrictions' );
    my $sth = $dbh->prepare( "SELECT id, name FROM keywords" );
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $oldname = $row->{name};
        my $newname = $oldname;
        $newname =~ s/[^\w-]/_/g;
        if ( $newname ne $oldname ) {
            $db->print(
                "Keyword '$oldname' converted to new name of '$newname'"
            );
            $dbh->do( "UPDATE keywords SET name=? WHERE id=?",
                {}, $newname, $row->{id} );
        }
    }
    $db->updated;
}

if ( $db->is_lower("3.9.23") ) {
    $db->print( 'Add one_time_token option for API sessions' );
    $dbh->do(
        'ALTER TABLE api_sessions ADD COLUMN one_time_token BOOLEAN NOT NULL DEFAULT 0'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.24") ) {
    $db->print( 'Add dependency_level for service checks' );
    $dbh->do(
        'ALTER TABLE servicechecks ADD COLUMN dependency_level TINYINT NOT NULL DEFAULT 0'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.25") ) {
    $db->print(
        'Fix foreign key constraint for servicechecks - any servicechecks with a servicegroup of NULL will be migrated to the first service group'
    );
    my $first_sg_id =
      $dbh->selectrow_array( "SELECT id FROM servicechecks ORDER BY id LIMIT 1"
      );
    $dbh->do(
        "UPDATE servicechecks SET servicegroup=$first_sg_id WHERE servicegroup IS NULL"
    );
    $dbh->do(
        'ALTER TABLE servicechecks MODIFY COLUMN servicegroup INT NOT NULL DEFAULT 0, MODIFY COLUMN plugin VARCHAR(128) DEFAULT NULL'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.26") ) {
    $db->print( 'Adding events view timeline default' );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN show_timeline BOOLEAN NOT NULL DEFAULT 1 AFTER soft_state_dependencies'
    );
    $db->updated;
}

if ( $db->is_lower("3.9.27") ) {
    $db->print( 'Adding support for host template changes to list of hosts' );
    $dbh->do(
        'ALTER TABLE hosthosttemplates MODIFY COLUMN priority INT NOT NULL DEFAULT 1000'
    );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN smart_hosttemplate_removal BOOLEAN NOT NULL DEFAULT 0 AFTER show_timeline'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.1") ) {
    $db->print(
        "Creating CONFIGUREKEYWORDS access and adding to all roles with CONFIGUREVIEW\n"
    );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (15, "CONFIGUREKEYWORDS")'
    );

    # Add CONFIGUREKEYWORDS to CONFIGUREVIEW roles
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 15 FROM roles_access WHERE accessid=12'
    );

    $db->updated;
}

if ( $db->is_lower("3.11.2") ) {
    $dbh->do(
        'ALTER TABLE roles ADD COLUMN all_hostgroups BOOLEAN DEFAULT 0 NOT NULL AFTER priority,
    ADD COLUMN all_servicegroups BOOLEAN DEFAULT 0 NOT NULL AFTER all_hostgroups,
    ADD COLUMN all_keywords BOOLEAN DEFAULT 0 NOT NULL AFTER all_servicegroups'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.3") ) {
    $db->print( "Adding role_access_hostgroups table" );
    $dbh->do( "DROP TABLE IF EXISTS role_access_hostgroups" );
    $dbh->do(
        "CREATE TABLE role_access_hostgroups (
    roleid INT NOT NULL,
    hostgroupid INT NOT NULL,
    PRIMARY KEY (roleid, hostgroupid),
    INDEX (roleid),
    CONSTRAINT role_access_hostgroups_roleid_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
    INDEX (hostgroupid),
    CONSTRAINT role_access_hostgroups_hostgroupid_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Role to host groups access list'"
    );
    $db->updated;
}

if ( $db->is_lower("3.11.4") ) {
    $db->print( "Adding role_access_servicegroups table" );
    $dbh->do( "DROP TABLE IF EXISTS role_access_servicegroups" );
    $dbh->do(
        "CREATE TABLE role_access_servicegroups (
    roleid INT NOT NULL,
    servicegroupid INT NOT NULL,
    PRIMARY KEY (roleid, servicegroupid),
    INDEX (roleid),
    CONSTRAINT role_access_servicegroups_roleid_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
    INDEX (servicegroupid),
    CONSTRAINT role_access_servicegroups_servicegroupid_fk FOREIGN KEY (servicegroupid) REFERENCES servicegroups(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Role to service groups access list'"
    );
    $db->updated;
}

if ( $db->is_lower("3.11.5") ) {
    $db->print( "Adding role_access_keywords table" );
    $dbh->do( "DROP TABLE IF EXISTS role_access_keywords" );
    $dbh->do(
        "CREATE TABLE role_access_keywords (
    roleid INT NOT NULL,
    keywordid INT NOT NULL,
    PRIMARY KEY (roleid, keywordid),
    INDEX (roleid),
    CONSTRAINT role_access_keywords_roleid_fk FOREIGN KEY (roleid) REFERENCES roles(id) ON DELETE CASCADE,
    INDEX (keywordid),
    CONSTRAINT role_access_keywords_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE
    ) ENGINE=InnoDB COMMENT='Role to keywords access list'"
    );
    $db->updated;
}

if ( $db->is_lower("3.11.6") ) {
    $db->print( "Migrating all contacts to new roles" );

    my $access_lookup = {};
    my $role_changed  = {};
    my $sth           = $dbh->prepare(
        "SELECT id,name,role,all_hostgroups,all_servicegroups FROM contacts ORDER BY name"
    );
    $sth->execute;
    while ( my $contact_row = $sth->fetchrow_hashref ) {

        # Create a string encoding all the access for this contact so we can reuse a role if everything matches
        my $accesses = $dbh->selectcol_arrayref(
            "SELECT accessid FROM roles_access WHERE roleid=? ORDER BY accessid",
            {}, $contact_row->{role},
        );
        my $config_hostgroups = $dbh->selectcol_arrayref(
            "SELECT hostgroupid FROM roles_hostgroups WHERE roleid=? ORDER BY hostgroupid",
            {}, $contact_row->{role},
        );
        my $config_monitoringservers = $dbh->selectcol_arrayref(
            "SELECT monitoringserverid FROM roles_monitoringservers WHERE roleid=? ORDER BY monitoringserverid",
            {}, $contact_row->{role},
        );
        my $hostgroups = $dbh->selectcol_arrayref(
            "SELECT hostgroupid FROM contact_hostgroups WHERE contactid=? ORDER BY hostgroupid",
            {}, $contact_row->{id}
        );
        my $servicegroups = $dbh->selectcol_arrayref(
            "SELECT servicegroupid FROM contact_servicegroups WHERE contactid=? ORDER BY servicegroupid",
            {}, $contact_row->{id}
        );
        my $keywords = $dbh->selectcol_arrayref(
            "SELECT keywordid FROM contact_keywords WHERE contactid=? ORDER BY keywordid",
            {}, $contact_row->{id}
        );

        # Need to add the role information here, otherwise a different role with same access would be used instead
        my $access_key = join( ",",
            "r" . $contact_row->{role},
            map {"a$_"} @$accesses,
            map {"ch$_"} @$config_hostgroups,
            map {"cm$_"} @$config_monitoringservers,
            "allhg" . $contact_row->{all_hostgroups},
            "allsg" . $contact_row->{all_servicegroups},
            map {"h$_"} @$hostgroups,
            map {"s$_"} @$servicegroups,
            map {"k$_"} @$keywords );

        # Create (or update) a new role based on current role
        if ( !exists $access_lookup->{$access_key} ) {

            my $oldrole_id = $contact_row->{role};
            my $newrole_id;

            # If the role has already been changed to include hostgroups/servicegroups/keywords, then clone role
            if ( $role_changed->{$oldrole_id} ) {
                my $oldrole_hash = $dbh->selectrow_hashref(
                    "SELECT name,description,priority FROM roles WHERE id=?",
                    {}, $oldrole_id );
                my $newrolename =
                  $oldrole_hash->{name} . " - " . $contact_row->{name};

                $dbh->do(
                    "INSERT INTO roles (name, description, priority, uncommitted) VALUES (?,?,?,1)",
                    {},
                    $newrolename,
                    $oldrole_hash->{description},
                    $oldrole_hash->{priority},
                );
                $newrole_id =
                  $dbh->last_insert_id( undef, undef, undef, undef );

                # Need to duplicate other tables
                $dbh->do(
                    "INSERT INTO roles_monitoringservers SELECT $newrole_id, monitoringserverid FROM roles_monitoringservers WHERE roleid=?",
                    {}, $oldrole_id,
                );
                $dbh->do(
                    "INSERT INTO roles_access SELECT $newrole_id, accessid FROM roles_access WHERE roleid=?",
                    {}, $oldrole_id,
                );
                $dbh->do(
                    "INSERT INTO roles_hostgroups SELECT $newrole_id, hostgroupid FROM roles_hostgroups WHERE roleid=?",
                    {}, $oldrole_id,
                );
            }
            else {
                $newrole_id = $oldrole_id;
                $role_changed->{$oldrole_id}++;
            }

            $dbh->do(
                "UPDATE roles SET all_hostgroups=?, all_servicegroups=? WHERE id=?",
                {},
                $contact_row->{all_hostgroups},
                $contact_row->{all_servicegroups},
                $newrole_id,
            );

            # Add in new table information, so matches contact information
            $dbh->do(
                "INSERT INTO role_access_hostgroups SELECT $newrole_id, hostgroupid FROM contact_hostgroups WHERE contactid=?",
                {}, $contact_row->{id},
            );
            $dbh->do(
                "INSERT INTO role_access_servicegroups SELECT $newrole_id, servicegroupid FROM contact_servicegroups WHERE contactid=?",
                {}, $contact_row->{id},
            );
            $dbh->do(
                "INSERT INTO role_access_keywords SELECT $newrole_id, keywordid FROM contact_keywords WHERE contactid=?",
                {}, $contact_row->{id},
            );

            $access_lookup->{$access_key} = $newrole_id;
        }
        $dbh->do(
            "UPDATE contacts SET role=?, uncommitted=1 WHERE id=?",
            {}, $access_lookup->{$access_key},
            $contact_row->{id}
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.11.7") ) {
    $db->print( "Removing redundant tables" );
    $dbh->do( "DROP TABLE contact_hostgroups" );
    $dbh->do( "DROP TABLE contact_servicegroups" );
    $dbh->do( "DROP TABLE contact_keywords" );
    $dbh->do(
        "ALTER TABLE contacts DROP COLUMN all_hostgroups, DROP COLUMN all_servicegroups"
    );
    $db->updated;
}

if ( $db->is_lower("3.11.8") ) {
    $db->print( "Adding all_keywords to notification profiles" );
    $dbh->do(
        "ALTER TABLE notificationprofiles ADD COLUMN all_keywords BOOLEAN DEFAULT 1 NOT NULL AFTER all_servicegroups"
    );
    $dbh->do( "UPDATE notificationprofiles SET all_keywords=0" );
    $db->updated;
}

if ( $db->is_lower("3.11.9") ) {
    $db->print( 'Adding date_format to systempreferences' );
    $dbh->do(
        'ALTER TABLE systempreferences ADD COLUMN date_format ENUM ("us", "euro", "iso8601", "strict-iso8601") DEFAULT "euro" NOT NULL'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.10") ) {
    $db->print( 'Adding "passive" to monitoringservers' );
    $dbh->do(
        'ALTER TABLE monitoringservers ADD COLUMN passive INT DEFAULT 0 NOT NULL AFTER activated'
    );
    $dbh->do(
        'ALTER TABLE monitoringclusternodes ADD COLUMN passive INT DEFAULT 0 NOT NULL AFTER activated'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.11") ) {
    $db->print( "Adding tidy_ifdescr_level to hosts" );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN tidy_ifdescr_level TINYINT DEFAULT 0 NOT NULL AFTER use_mrtg'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.12") ) {
    $db->print( "Adding snmp_max_msg_size to hosts" );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmp_max_msg_size SMALLINT UNSIGNED DEFAULT 0 NOT NULL AFTER tidy_ifdescr_level'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.13") ) {
    $db->print(
        "Creating DOWNTIMESOME and DOWNTIMEALL access and adding to all roles with ACTIONSOME or ACTIONALL\n"
    );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (16, "DOWNTIMEALL")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (17, "DOWNTIMESOME")' );

    # accessid=4 = ACTIONSOME, accessid=3=ACTIONALL
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 16 FROM roles_access WHERE accessid=3'
    );
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 17 FROM roles_access WHERE accessid=4'
    );

    $db->updated;
}

if ( $db->is_lower("3.11.14") ) {
    $db->print( "Creating monitor_packs table" );
    $dbh->do(
        'CREATE TABLE monitor_packs (
        id INT AUTO_INCREMENT PRIMARY KEY,
		name varchar(128) NOT NULL,
        alias varchar(255) NOT NULL,
		version varchar(16) NOT NULL,
        status ENUM("OK","NOTICE","FAILURE","INSTALLING") NOT NULL DEFAULT "INSTALLING",
        message TEXT NOT NULL,
        dependencies TEXT NOT NULL,
		created int NOT NULL,
		updated int NOT NULL,
		UNIQUE KEY(name)
	) ENGINE=InnoDB COMMENT="Opsview Monitor Packs"'
    );
    $db->updated;
}

if ( $db->is_lower("3.11.15") ) {
    $db->print( "Creating public keywords field" );
    $dbh->do(
        'ALTER TABLE keywords
        MODIFY COLUMN enabled BOOLEAN NOT NULL DEFAULT 0,
        MODIFY COLUMN all_hosts BOOLEAN NOT NULL DEFAULT 0,
        MODIFY COLUMN all_servicechecks BOOLEAN NOT NULL DEFAULT 0,
        MODIFY COLUMN uncommitted BOOLEAN NOT NULL DEFAULT 0,
        ADD COLUMN public BOOLEAN NOT NULL DEFAULT 0 AFTER all_servicechecks,
        DROP INDEX `enabled`,
        ADD INDEX enabled_id_public (enabled,id,public)'
    );
    $dbh->do( "UPDATE keywords SET public=1" );
    $db->updated;
}

if ( $db->is_lower("3.13.1") ) {
    $db->print( "Adding matpathid to hostgroups" );
    $dbh->do(
        'ALTER TABLE hostgroups ADD COLUMN matpathid TEXT NOT NULL DEFAULT ""'
    );
    $postupdate->{regenerate_hostgroups_lft_rgt}++;
    $db->updated;
}

if ( $db->is_lower("3.13.2") ) {
    $db->print( "Adding ON DELETE cascade to hostgroupinfo" );
    $dbh->do(
        "ALTER TABLE hostgroupinfo DROP FOREIGN KEY hostgroupinfo_hostgroups_fk"
    );
    $dbh->do(
        "ALTER TABLE hostgroupinfo ADD CONSTRAINT hostgroupinfo_hostgroups_fk FOREIGN KEY (id) REFERENCES hostgroups(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.3") ) {
    $db->print( "Adding ON DELETE cascade to reloadmessages" );
    $dbh->do(
        "ALTER TABLE reloadmessages DROP FOREIGN KEY reloadmessages_monitoringcluster_fk"
    );
    $dbh->do(
        "ALTER TABLE reloadmessages ADD CONSTRAINT reloadmessages_monitoringcluster_fk FOREIGN KEY (monitoringcluster) REFERENCES monitoringservers(id) ON DELETE CASCADE"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.4") ) {
    $db->print( "Adding serviceinfo table" );
    $dbh->do(
        "CREATE TABLE serviceinfo (
        id INT NOT NULL PRIMARY KEY,
        information TEXT
    ) ENGINE=InnoDB"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.5") ) {
    $db->print( "Check for invalid characters in notification methods" );
    my $sth = $dbh->prepare( "SELECT id, command FROM notificationmethods" );
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $old_command = $row->{command};
        my $new_command = $old_command;
        $new_command =~ s/[\/\$`\(\)!\*\?^%]//g;
        if ( $old_command ne $new_command ) {
            print "Some invalid characters removed from $old_command\n";
            $dbh->do( "UPDATE notificationmethods SET command=? WHERE id=?",
                {}, $new_command, $row->{id} );
        }
    }
    $db->updated;
}

if ( $db->is_lower("3.13.6") ) {
    $db->print( "Add service_info_url to systempreferences" );
    $dbh->do(
        "ALTER TABLE systempreferences ADD service_info_url varchar(255) default NULL"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.7") ) {
    $db->print( 'Adding new contextual menu option for viewports' );
    $dbh->do(
        "ALTER TABLE keywords ADD COLUMN show_contextual_menus BOOLEAN DEFAULT 1 NOT NULL AFTER public"
    );
    $db->updated;
}

if ( $db->is_lower("3.13.8") ) {
    $db->print( 'Adding new passive result type of cascaded_from' );

    # Pre-upgrade checks
    my $interface_id = $dbh->selectrow_array(
        "SELECT id FROM servicechecks WHERE name='Interface'"
    );
    unless ($interface_id) {
        die
          "Cannot find service check called 'Interface' - check if this exists";
    }
    my $already_exists = $dbh->selectrow_array(
        "SELECT name FROM servicechecks WHERE name='Interface Poller'"
    );
    if ($already_exists) {
        die
          "There is a service check called 'Interface Poller' - this is expected to be an Opsview specific service check. Please rename the existing service check before re-running the upgrade";
    }

    my $plugin_exists = $dbh->selectrow_array(
        "SELECT name FROM plugins WHERE name='check_snmp_interfaces_cascade'"
    );
    unless ($plugin_exists) {

        # We add this plugin if it doesn't already exist, to ensure below doesn't fail due to constraint errors
        # This plugin should be added as part of the upgrade and the scanning of the plugins directory
        # but this makes it more robust
        $dbh->do(
            "INSERT INTO plugins SET name='check_snmp_interfaces_cascade', help='Added by upgrade'"
        );
    }
    $dbh->do(
        "ALTER TABLE servicechecks ADD COLUMN cascaded_from INT DEFAULT NULL AFTER attribute, ADD COLUMN alert_from_failure SMALLINT DEFAULT 1 NOT NULL AFTER cascaded_from, ADD INDEX (cascaded_from), ADD CONSTRAINT servicechecks_cascaded_from_fk FOREIGN KEY (cascaded_from) REFERENCES servicechecks(id)"
    );

    # Create new service check called Interface Poller
    $dbh->do(
        "INSERT INTO servicechecks (
name,
description,
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
checktype,
check_period,
plugin,
args,
attribute,
disable_name_change
) SELECT 'Interface Poller', 'SNMP interface polling',
notification_interval,
notification_period,
servicegroup,
notification_options,
check_interval,
retry_check_interval,
check_attempts,
1, # Active
check_period,
'check_snmp_interfaces_cascade',
'-H \$HOSTNAME\$',
NULL, # No attribute set as only one check per host
1
 FROM servicechecks
 WHERE name='Interface'"
    );

    # Set same dependencies as Interface check
    my $interface_poller_id = $dbh->selectrow_array(
        "SELECT id FROM servicechecks WHERE name='Interface Poller'"
    );
    $dbh->do(
        "INSERT INTO servicecheckdependencies SELECT $interface_poller_id, dependencyid FROM servicecheckdependencies WHERE servicecheckid=?",
        {}, $interface_id
    );

    # Set Interface, Errors, Discards to be cascaded_from Interface Poller, and as passive and use alert_from_failure value from check_attempts
    $dbh->do(
        "UPDATE servicechecks SET checktype=2, cascaded_from=$interface_poller_id, alert_from_failure=check_attempts WHERE name IN ('Interface','Errors','Discards')"
    );

    # Anything currently using Interface service check, will automatically have the Interface Poller service check
    $dbh->do(
        "INSERT INTO hostservicechecks SELECT hostid,$interface_poller_id,0 FROM hostservicechecks WHERE servicecheckid=?",
        {}, $interface_id
    );
    $dbh->do(
        "INSERT INTO hosttemplateservicechecks SELECT hosttemplateid,$interface_poller_id FROM hosttemplateservicechecks WHERE servicecheckid=?",
        {}, $interface_id
    );

    $db->updated;
}

if ( $db->is_lower("3.13.9") ) {
    $db->print( "Adding snmp_extended_throughput_data to hosts" );
    $dbh->do(
        'ALTER TABLE hosts ADD COLUMN snmp_extended_throughput_data TINYINT DEFAULT 0 NOT NULL AFTER snmp_max_msg_size'
    );
    $db->updated;
}

if ( $db->is_lower("3.13.10") ) {
    $db->print( "Adding REPORTADMIN and REPORTUSER access" );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (18, "REPORTADMIN")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (19, "REPORTUSER")' );

    # accessid=9 = ADMINACCESS
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 18 FROM roles_access WHERE accessid=9'
    );
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 19 FROM roles_access WHERE accessid=9'
    );

    # Set permission at modules to be same
    $dbh->do(
        'UPDATE modules SET access="REPORTUSER" WHERE namespace="com.opsera.opsview.modules.reports" AND access="ADMINACCESS"'
    );

    $db->updated;
}

if ( $db->is_lower("3.13.11") ) {
    $db->print( "Add new installed column to modules" );
    $dbh->do(
        "ALTER TABLE modules ADD COLUMN installed BOOLEAN DEFAULT 0 NOT NULL"
    );

    # Update namespaces
    $dbh->do(
        "UPDATE modules SET namespace = REPLACE(namespace, 'com.opsera.opsview.', 'com.opsview.')"
    );

    # Update Nagvis and MRTG
    $dbh->do(
        "UPDATE modules SET installed = 1 WHERE namespace IN ('com.opsview.modules.nagvis', 'com.opsview.modules.mrtg', 'com.opsview.modules.nmis')"
    );

    $db->updated;
}

if ( $db->is_lower("3.13.12") ) {
    $db->print( "Amending schema_version to handle new style schema changes" );
    $dbh->do( "
        ALTER TABLE schema_version ADD COLUMN reason VARCHAR(255),
            ADD COLUMN created_at DATETIME,
            ADD COLUMN duration INT,
            ADD PRIMARY KEY (major_release)
    " );
    $db->updated;
}

# 3.15.X schema changes are for core and commercial branch
if ( $db->is_lower("3.15.1") ) {
    $db->print( "Updating with dashboard metrics" );
    $dbh->do(
        "INSERT INTO metadata VALUES ('dashboardPings','0'), ('dashboardLast','')"
    );
    $db->updated;
}

if ( $db->is_lower("3.15.2") ) {
    $db->print( "Disabling NMIS if not used" );
    my $nmis_used = $dbh->selectrow_array( "SELECT MAX(use_nmis) FROM hosts" );
    unless ($nmis_used) {
        $dbh->do(
            "UPDATE modules SET enabled=0 WHERE namespace='com.opsview.modules.nmis'"
        );
    }
    $db->updated;
}

if ( $db->is_lower("3.15.3") ) {
    $db->print( "Renaming RANCID to Netaudit" );
    $dbh->do(
        "UPDATE modules SET name='Netaudit', description='Opsview Netaudit' where namespace='com.opsview.modules.rancid'"
    );
    $db->updated;
}

if ( $db->is_lower("3.15.4") ) {
    $db->print( "Setting up initial Opsview Community" );

    $db->updated;
}

if ( $db->is_lower("3.15.5") ) {
    $db->print( "Access control for service checks" );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (20, "TESTCHANGE")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (21, "TESTALL")' );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (22, "TESTSOME")' );

    # Add TESTCHANGE and ADMINACCESS (accessid=9) roles
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 20 FROM roles_access WHERE accessid=9'
    );

    # ADD TESTALL to ACTIONALL roles
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 21 FROM roles_access WHERE accessid=3'
    );

    # Add TESTSOME to ACTIONSOME (accessid=4) roles
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 22 FROM roles_access WHERE accessid=4'
    );

    $db->updated;
}

if ( $db->is_lower('3.15.6') ) {
    $db->print( 'Shared notification profiles' );
    $dbh->do( "DROP TABLE IF EXISTS sharednotificationprofiles" );
    $dbh->do(
        q[
        CREATE TABLE sharednotificationprofiles (
            id int(11) NOT NULL AUTO_INCREMENT,
            name varchar(128) NOT NULL DEFAULT '',
            host_notification_options varchar(16) DEFAULT NULL,
            service_notification_options varchar(16) DEFAULT NULL,
            notification_period int(11) NOT NULL DEFAULT '1',
            all_hostgroups BOOLEAN NOT NULL DEFAULT '1',
            all_servicegroups BOOLEAN NOT NULL DEFAULT '1',
            all_keywords tinyint(1) NOT NULL DEFAULT '1',
            notification_level int(11) NOT NULL DEFAULT '1',
            role int(11) NOT NULL,
            uncommitted int(11) NOT NULL DEFAULT '0',
            PRIMARY KEY (id),
            UNIQUE (name),
            CONSTRAINT snp_notification_period FOREIGN KEY (notification_period) REFERENCES timeperiods (id),
            CONSTRAINT snp_role FOREIGN KEY (role) REFERENCES roles (id)
        ) ENGINE=InnoDB COMMENT="Shared notification profiles"
    ]
    );
    $dbh->do( "DROP TABLE IF EXISTS sharednotificationprofile_hostgroups" );
    $dbh->do(
        q[
        CREATE TABLE sharednotificationprofile_hostgroups (
            sharednotificationprofileid int NOT NULL,
            hostgroupid                 int NOT NULL,
            PRIMARY KEY (sharednotificationprofileid, hostgroupid),
            INDEX (sharednotificationprofileid),
            CONSTRAINT snp_hostgroups_sharednotificationprofileid_fk FOREIGN KEY (sharednotificationprofileid) REFERENCES sharednotificationprofiles(id) ON DELETE CASCADE,
            INDEX (hostgroupid),
            CONSTRAINT snp_hostgroups_hostgroupid_fk FOREIGN KEY (hostgroupid) REFERENCES hostgroups(id) ON DELETE CASCADE
        ) ENGINE=InnoDB COMMENT="Joining table for shared notification profiles to host groups";
    ]
    );

    $dbh->do( "DROP TABLE IF EXISTS sharednotificationprofile_servicegroups" );
    $dbh->do(
        q[
        CREATE TABLE sharednotificationprofile_servicegroups (
            sharednotificationprofileid int NOT NULL,
            servicegroupid        int NOT NULL,
            PRIMARY KEY (sharednotificationprofileid, servicegroupid),
            INDEX (sharednotificationprofileid),
            CONSTRAINT snp_servicegroups_sharednotificationprofileid_fk FOREIGN KEY (sharednotificationprofileid) REFERENCES sharednotificationprofiles(id) ON DELETE CASCADE,
            INDEX (servicegroupid),
            CONSTRAINT snp_servicegroups_servicegroupid_fk FOREIGN KEY (servicegroupid) REFERENCES servicegroups(id) ON DELETE CASCADE
        ) ENGINE=InnoDB COMMENT="Joining table for shared notification profiles to service groups";
    ]
    );

    $dbh->do( "DROP TABLE IF EXISTS sharednotificationprofile_keywords" );
    $dbh->do(
        q[
        CREATE TABLE sharednotificationprofile_keywords (
            sharednotificationprofileid int NOT NULL,
            keywordid             int NOT NULL,
            PRIMARY KEY (sharednotificationprofileid, keywordid),
            INDEX (sharednotificationprofileid),
            CONSTRAINT snp_keywords_sharednotificationprofileid_fk FOREIGN KEY (sharednotificationprofileid) REFERENCES sharednotificationprofiles(id) ON DELETE CASCADE,
            INDEX (keywordid),
            CONSTRAINT snp_keywords_keywordid_fk FOREIGN KEY (keywordid) REFERENCES keywords(id) ON DELETE CASCADE
        ) ENGINE=InnoDB COMMENT="Joining table for shared notification profiles to keywords";
    ]
    );

    $dbh->do(
        "DROP TABLE IF EXISTS sharednotificationprofile_notificationmethods"
    );
    $dbh->do(
        q[
        CREATE TABLE sharednotificationprofile_notificationmethods (
            sharednotificationprofileid int NOT NULL,
            notificationmethodid  int NOT NULL,
            PRIMARY KEY (sharednotificationprofileid, notificationmethodid),
            INDEX (sharednotificationprofileid),
            CONSTRAINT snp_notificationmethods_sharednotificationprofileid_fk FOREIGN KEY (sharednotificationprofileid) REFERENCES sharednotificationprofiles(id) ON DELETE CASCADE,
            INDEX (notificationmethodid),
            CONSTRAINT snp_notificationmethods_notificationmethodid_fk FOREIGN KEY (notificationmethodid) REFERENCES notificationmethods(id) ON DELETE CASCADE
        ) ENGINE=InnoDB COMMENT='Shared notification profile with multiple notification methods';
    ]
    );

    $dbh->do( "DROP TABLE IF EXISTS contact_sharednotificationprofile" );
    $dbh->do(
        q[
        CREATE TABLE contact_sharednotificationprofile (
            contactid INT NOT NULL,
            sharednotificationprofileid INT NOT NULL,
            priority INT NOT NULL DEFAULT 1000,
            PRIMARY KEY (contactid, sharednotificationprofileid),
            CONSTRAINT contact FOREIGN KEY (contactid) REFERENCES contacts(id) ON DELETE CASCADE,
            CONSTRAINT sharednotificationprofile FOREIGN KEY (sharednotificationprofileid) REFERENCES sharednotificationprofiles(id) ON DELETE CASCADE
        ) ENGINE=InnoDB COMMENT="Links contacts to shared notification profiles"
    ]
    );
    $db->updated;
}

if ( $db->is_lower("3.15.7") ) {
    $db->print( "Access control for shared notification profiles" );
    $dbh->do( 'INSERT INTO access (id, name) VALUES (23, "CONFIGUREPROFILES")'
    );

    # Add CONFIGUREPROFILES to CONFIGUREVIEW
    $dbh->do(
        'INSERT INTO roles_access SELECT roleid, 23 FROM roles_access WHERE accessid=12'
    );

    $db->updated;
}

if ( $db->is_lower("3.15.8") ) {
    $db->print( "sensitive_arguments for service checks" );
    $dbh->do(
        "ALTER TABLE servicechecks ADD `sensitive_arguments` BOOL DEFAULT 1"
    );
    $db->updated;
}

if ( $db->is_lower("3.15.9") ) {
    $db->print( "Add set_downtime_on_host_delete to systempreferences" );
    $dbh->do(
        "ALTER TABLE systempreferences ADD `set_downtime_on_host_delete` BOOL DEFAULT 1"
    );
    $db->updated;
}

if ( $db->is_lower("3.15.10") ) {
    $db->print( "Add exclude_handled to keywords" );
    $dbh->do(
        'ALTER TABLE keywords ADD exclude_handled BOOLEAN NOT NULL DEFAULT 0'
    );
    $db->updated;
}

if ( $db->is_lower("3.15.11") ) {
    $db->print( "Updating NagVis url" );
    $dbh->do(
        "UPDATE modules SET url='/modules/nagvis' where namespace='com.opsview.modules.nagvis'"
    );
    $db->updated;
}

unless (
    $db->is_installed(
        "20120906ios", "Adding iOS push notification profile", "all"
    )
  )
{
    $dbh->do(
        q[
        INSERT into notificationmethods
        SET active      = 1,
            name        = 'Push Notifications For iOS Mobile',
            namespace   = 'com.opsview.notificationmethods.iospush',
            master      = 1,
            command     = 'notify_by_ios_push',
            priority    = 1,
            uncommitted = 0
        ]
    );
    $db->updated;
}

unless (
    $db->is_installed(
        '20121023hostsidx', "opsview.hosts (ip,name) index", "all"
    )
  )
{
    $dbh->do( q[ ALTER TABLE hosts ADD KEY (ip,name) ] );
    $db->updated;
}

unless (
    $db->is_installed(
        '20130115envvars', "Support for envvars in plugins", "all"
    )
  )
{
    $dbh->do(
        q[ ALTER TABLE plugins ADD COLUMN envvars TEXT NOT NULL DEFAULT '' ]
    );
    $db->updated;
}

unless (
    $db->is_installed(
        '20130122snmpport', "Increasing the size of snmp_port", "all"
    )
  )
{
    $dbh->do( q[ ALTER TABLE hosts MODIFY snmp_port INT(11) DEFAULT 161 ] );
    $db->updated;
}

unless (
    $db->is_installed( '20130204baduuid', "Checking for bad UUID", "all" ) )
{
    my $rows_affected = $dbh->do(
        q[ UPDATE systempreferences SET uuid='' WHERE uuid IN ('4D479026-48F1-11E2-80B3-DDBC566DC397','42BFFD96-6570-11E2-B6D9-D2F0548F4B8A') ]
    );

    if ( $rows_affected > 0 ) {
        $db->print(
            "WARNING! A bad UUID has been detected on this system. If you use Opsview Mobile for iOS, you will need to run the application again to re-register your system for push notifications. See http://docs.opsview.com/doku.php?id=opsview:push-notifications-duplicate-uuid for details"
        );
    }
    $db->updated;
}

unless ( $db->is_installed( '20130219hsteh', "Host event handlers", 'all' ) ) {
    $dbh->do(
        q[ ALTER TABLE hosts ADD COLUMN event_handler VARCHAR(255) NOT NULL DEFAULT '' ]
    );
    $db->updated;
}

unless (
    $db->is_installed(
        '20130221snmpthro', "Increasing the size of snmp.throughput_*",
        'all'
    )
  )
{
    $dbh->do(
        q[ ALTER TABLE hostsnmpinterfaces
        MODIFY throughput_warning VARCHAR(255) DEFAULT NULL,
        MODIFY throughput_critical VARCHAR(255) DEFAULT NULL
        ]
    );
    $db->updated;
}

unless (
    $db->is_installed(
        '20130424alerts', "Support for limiting notification alerts", 'all'
    )
  )
{
    $dbh->do(
        q[ ALTER TABLE notificationprofiles
                   ADD notification_level_stop SMALLINT NOT NULL DEFAULT 0 ]
    );
    $dbh->do(
        q[ ALTER TABLE sharednotificationprofiles
                   ADD notification_level_stop SMALLINT NOT NULL DEFAULT 0 ]
    );
    $db->updated;
}

# PLACEHOLDER
# For future upgrade of Opsview Core where you cannot have an automatic Opsview reload
# We mark this upgrade lock file so that post installs do not generate an unactivated configuration
# of a single host which would lose downtimes, comments and acknowledgements of all other hosts
#if ( $db->is_lower("4.0.1") ) {
#    $db->print("Marking upgrade to Opsview 4");
#
#    # Don't worry if this backup fails - is an additional safety barrier
#    copy("/usr/local/nagios/var/retention.dat", "/tmp/retention.dat.opsview4_upgrade");
#
#    open F, ">", "/tmp/opsview4_upgrade_config_generation.lock" or die "Cannot create lock file";
#    close F;
#    $db->updated;
#}

unless (
    $db->is_installed(
        '20130521notmeth', "New notitication method on master", 'all'
    )
  )
{
    $dbh->do(
        q[
        ALTER TABLE notificationmethods
        MODIFY master TINYINT(1) NOT NULL DEFAULT '1'
        ]
    );
    $db->updated;
}

# This should not be added to Commercial!!!!
# Earlier Core was disabling include_major incorrectly, so we set that too
unless (
    $db->is_installed( '20130814surv', "Set survey to always send", 'all' ) )
{
    $dbh->do(
        q[ UPDATE systempreferences SET send_anon_data=1, updates_includemajor=1 ]
    );
    $db->updated;
}

unless ( $db->is_installed( '20130612accesses', "New accesses", 'all' ) ) {

    $dbh->do( q[ INSERT INTO access (id,name) VALUES (27,'CONFIGUREROLES') ] );

    # Add CONFIGUREROLES access to any role that has the CONFIGUREVIEW access.
    $dbh->do(
        q[
        INSERT IGNORE INTO roles_access (roleid, accessid)
            SELECT roleid, 27 FROM roles_access WHERE accessid = 12
        ]
    );

    $dbh->do( q[ INSERT INTO access (id,name) VALUES (28,'CONFIGURECONTACTS') ]
    );

    # Add CONFIGURECONTACTS access to any role that has the CONFIGUREVIEW access.
    $dbh->do(
        q[
        INSERT IGNORE INTO roles_access (roleid, accessid)
            SELECT roleid, 28 FROM roles_access WHERE accessid = 12
        ]
    );

    $dbh->do(
        q[ INSERT INTO access (id,name) VALUES (29,'CONFIGUREHOSTGROUPS') ]
    );

    # Add CONFIGUREHOSTGROUPS access to any role that has the CONFIGUREVIEW access.
    $dbh->do(
        q[
        INSERT IGNORE INTO roles_access (roleid, accessid)
            SELECT roleid, 29 FROM roles_access WHERE accessid = 12
        ]
    );

    $db->updated;

}

unless ( $db->is_installed( '20130702nagvis', "New access for Nagvis", 'all' ) )
{

    $dbh->do( q[ INSERT INTO access (id,name) VALUES (30,'NAGVIS') ] );

    # Add NAGVIS access to any role that has the VIEWSOME or VIEWALL accesses.
    $dbh->do(
        q[
        INSERT IGNORE INTO roles_access (roleid, accessid)
            SELECT roleid, 30 FROM roles_access WHERE accessid IN (1,2)
        ]
    );

    $dbh->do(
        q[ UPDATE modules SET access = 'NAGVIS' WHERE namespace = 'com.opsview.modules.nagvis' ]
    );

    $db->updated;

}

unless (
    $db->is_installed( "20130710hkmd", "Master housekeep metadata", "all" ) )
{

    my %settings = (
        last_housekeeping_time => time(),
        housekeeping_duration  => 0,
    );

    while ( my ( $name, $value ) = each %settings ) {
        $dbh->do( "INSERT INTO metadata (name, value) VALUES (?, ?)",
            undef, $name, $value );
    }

    $db->updated;
}

unless (
    $db->is_installed( "20130726opsp", "Update monitor_pack status", "all" ) )
{
    $dbh->do(
        "UPDATE monitor_packs SET status = 'NOTICE' WHERE status = 'FAILURE'"
    );
    $db->updated;
}

unless (
    $db->is_installed( '20130625meta', "Increase storage for metadata", 'all' )
  )
{
    $dbh->do( "ALTER TABLE metadata CHANGE name name VARCHAR(128)" );
    $dbh->do( "ALTER TABLE metadata CHANGE value value VARCHAR(255)" );

    $db->updated;
}

unless (
    $db->is_installed(
        '20130905hstckint', "Default host check interval is five minutes",
        'all'
    )
  )
{
    $dbh->do(
        q[ ALTER TABLE hosts MODIFY check_interval VARCHAR(16) DEFAULT 5 ]
    );
    $db->updated;
}

# end of updates
if ( $postupdate->{regenerate_hostgroups_lft_rgt} ) {
    $db->print( "Regenerating host group information" );
    require Opsview::Schema;
    my $schema = Opsview::Schema->my_connect;
    $schema->resultset("Hostgroups")->add_lft_rgt_values;
}

if ( $opts->{t} ) {

    # Usually, need manual intervention to remove non-MRTG performance monitors
    # For tests, just do it
    $dbh->do(
        "DELETE FROM hostperformancemonitors WHERE performancemonitorid != 7"
    );
    $dbh->do(
        "DELETE FROM hosttemplateperformancemonitors WHERE performancemonitorid != 7"
    );
    $dbh->do( "DELETE FROM performancemonitors WHERE id != 7" );
}

if ( $db_changed || $db->changed ) {
    print "Finished updating Opsview database", $/;
}
else {
    print "Opsview database already up to date", $/;
}

sub db_version_lower {
    my $target = shift;
    my $version =
      $dbh->selectrow_array( "SELECT value FROM metadata WHERE name='version'"
      );
    $version =~ s/[a-zA-Z]+$//; # Remove suffix letter
    my @a = split( /[\.-]/, $version );
    my @b = split( /[\.-]/, $target );
    my $rc =
         $a[0] <=> $b[0]
      || $a[1] <=> $b[1]
      || $a[2] <=> $b[2]
      || $a[3] <=> $b[3];
    if ( $rc == -1 ) {
        print "DB at version $version", $/;
    }
    return ( $rc == -1 );
}

sub set_db_version {
    my $version = shift;
    $dbh->do( "UPDATE metadata SET value='$version' WHERE name='version'" );
    print "Updated database to version $version", $/;
    $db_changed = 1;
}
