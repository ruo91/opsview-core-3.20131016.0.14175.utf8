#!/usr/bin/perl
#
#
# SYNTAX:
# 	nagconfgen {-s file | [-t] {path to write}} [monitoringserver_id]
#
# DESCRIPTION:
# 	Nagios config generator
# 	Reads the database information and creates the nagios configuration files
#	-s means only write only the snmp trapinfo into file
#	-t means test output. Avoids hostname lookups and nagiosgraph icons
#	If monitoringserver_id is set, will create the config for just that monitoringserver
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
use FindBin qw($Bin);
use lib "$Bin", "$Bin/../lib", "$Bin/../etc", "$Bin/../perl/lib";
use Opsview;
use Opsview::Host;
use Opsview::Reloadtime;
use Opsview::Reloadmessage;
use Opsview::Schema;
use Opsview::Utils;
use Opsview::Config;
use Opsview::Config::Web;
use Time::HiRes qw(gettimeofday);
use Getopt::Std;
use Set::Cluster;
use File::Copy;
use subs qw(warn);
use Data::Dumper;
use JSON;

my $opsview4_upgrade_config_generation_lock =
  "/tmp/opsview4_upgrade_config_generation.lock";

use Opsview::Statistics;

my $schema = Opsview::Schema->my_connect;

# PLACEHOLDER. Will need to add a lock in future to stop automatic upgrades
# See upgradedb_opsview.pl for setting of lock
#unlink $opsview4_upgrade_config_generation_lock;

# Catch all dies and log to database. If $^S==1, then an exception is caught lower down, so ignore these
$SIG{__DIE__} = sub {
    return if ( $^S == 1 );
    print "Critical: @_";
    log_to_db( "critical", @_ );
};

my $start_logging_to_db = 0;
my $exit                = 0;
my $test                = 0;
my $opts                = {};
getopts( "s:r:t", $opts ) or die "Incorrect options";

if ( $opts->{t} ) {

    # Override hostip, which does a hostname lookup
    eval
      'package Opsview::Host; sub hostip { my ($self, $a) = @_; return $a ? [$a] : ["10.11.12.13"]; }; package main;';
    $test = 1;
}

umask 027
  ; # Requirements is that owner (nagios) can read/write, but group (nagios), can read

my $start = gettimeofday;

# Globals
my $libexecpath                  = "/usr/local/nagios/libexec";
my $additional_freshness_latency = 1800;

my $main_configfilepath = shift @ARGV;
if ( !$main_configfilepath && !( $opts->{s} || $opts->{r} ) ) {
    die "Must specify a config directory";
}

my $configfilepath;
my $opsviewdb = Opsview->db_Main;
unless (@ARGV) {

    # Called just once, rather than once per monitoringserver
    # Same as pre-tasks from create_and_send_configs, but needed here to be consistent
    $opsviewdb->do( "TRUNCATE temporary_hostmonitoredbynode" );
    $opsviewdb->do( "TRUNCATE " . Opsview::Reloadmessage->table );
}

our $monitoringserver; # Needs to be global so subroutines can see this
my @hosts;             # Is needed across subroutines
my %monitors
  ; # Lookup of all the hosts that the current monitoringserver can see
my $host_to_primarynode =
  {}; # Hash of hosts to node, when using clustered slaves
my $host_to_secondarynode = {}; # Hash to lookup
my $monitoringserverhosts =
  {}; # Lookup by hostid of hosts used for monitoringservers (or slaves)
my $cluster;
my %contactgroups; # Lookup of contactgroups used
my $using_nmis;
my $multiple_services_lookup;
my $hostname_lookup          = {};
my $configuration_cache_data = {};

$Opsview::Schema::Hosts::CACHE_HOST_ATTRIBUTES = 1;

# Lookup of hosts and services
# Used by Interface Poller to verify if throughput/errors/discards enabled
# Example:
# $host_services_lookup = {
#   hostname => {
#     serviceA => 1,
#     serviceB => 1,
#     "multi: /" => 1,
#   }
# }
my $host_services_lookup;

# Run this to cache data so there are less db retrievals
# Ignore host caching. When parallelised, is not required because each host will only be retrieved as required
#my @hosts = Opsview::Host->retrieve_all;
# Servicechecks are useful because they are referenced multiple times
my @servicechecks = Opsview::Servicecheck->retrieve_all;
my @servicegroups = Opsview::Servicegroup->retrieve_all;
my @hostgroups    = Opsview::Hostgroup->retrieve_all;

# This is currently a fixed list of macros to send, to avoid sending too many unnecessary macros
my $nagios_envvars_for_notifications = join(
    ',', qw/
      CONTACTEMAIL
      CONTACTGROUPLIST
      CONTACTNAME
      CONTACTPAGER
      HOSTACKAUTHOR
      HOSTACKCOMMENT
      HOSTADDRESS
      HOSTALIAS
      HOSTATTEMPT
      HOSTDOWNTIME
      HOSTDURATION
      HOSTGROUPNAME
      HOSTNAME
      HOSTNOTIFICATIONNUMBER
      HOSTOUTPUT
      HOSTSTATE
      HOSTSTATETYPE
      LASTHOSTCHECK
      LASTHOSTDOWN
      LASTHOSTSTATE
      LASTHOSTSTATECHANGE
      LASTHOSTUNREACHABLE
      LASTHOSTUP
      LASTSERVICECHECK
      LASTSERVICECRITICAL
      LASTSERVICEOK
      LASTSERVICESTATE
      LASTSERVICESTATECHANGE
      LASTSERVICEWARNING
      LASTSTATECHANGE
      LONGDATETIME
      LONGHOSTOUTPUT
      LONGSERVICEOUTPUT
      NOTIFICATIONAUTHOR
      NOTIFICATIONCOMMENT
      NOTIFICATIONNUMBER
      NOTIFICATIONTYPE
      SERVICEACKAUTHOR
      SERVICEACKCOMMENT
      SERVICEATTEMPT
      SERVICEDESC
      SERVICEDOWNTIME
      SERVICEDURATION
      SERVICENOTIFICATIONNUMBER
      SERVICEOUTPUT
      SERVICESTATE
      SERVICESTATETYPE
      SHORTDATETIME
      TIMET
      /
);

# Use same list for event handlers for the moment. Should do a parsing trick like plugins in future
my $nagios_envvars_for_eventhandlers = $nagios_envvars_for_notifications;

# Lookup table
my $keyword_host_service_lookup = {};

my $nagcmd_gid = getgrnam( "nagcmd" );

my $load_snmp = 0;

# Set configurations
my $nagios_interval_length = Opsview::Config->nagios_interval_length;
my $nagios_interval_convert_from_minutes = 1;
if ( Opsview::Config->nagios_interval_length_in_seconds ) {
    $nagios_interval_convert_from_minutes = 60;
}

my $webcfg = Opsview::Config::Web->web_config;
my $override_base_prefix =
  ( $webcfg->{override_base_prefix} ? $webcfg->{override_base_prefix} : "" );
my $graph_url = $override_base_prefix;
$graph_url .= "/graph";

exit $exit if $opts->{s};

# Has to be below -s otherwise possibly extraneous errors on reload page
$start_logging_to_db = 1;

# This has to move further down because of -r and -s options
die("Directory $main_configfilepath doesnt exist")
  if ( !-d $main_configfilepath );

my @all_monitoringservers = $schema->resultset("Monitoringservers")->all;
my $system_preference     = $schema->resultset("Systempreferences")->find(1);

my $json = JSON->new->canonical(1)->indent(0);
if ($test) {
    $json->indent(2);
}

main();

my $stop = gettimeofday;
printf "\nNagios config re-generated in %.3f seconds\n\n", ( $stop - $start );
exit $exit;

sub plog {
    print scalar localtime, " ", shift, $/;
}

sub warn {
    log_to_db( "warning", @_ );
    CORE::warn( "WARNING: ", @_, "\n" );
}

sub log_to_db {
    return unless $start_logging_to_db;
    my $severity = shift;
    my $data     = {
        utime    => time,
        message  => "@_",
        severity => $severity,
    };
    $data->{monitoringcluster} = $monitoringserver->id if $monitoringserver;
    Opsview::Reloadmessage->create($data);
}

sub main {
    plog "Starting";
    unless (@all_monitoringservers) {
        die "No monitoringservers are defined!";
    }

    my @monitoringservers;

    # Get list of monitoring servers to process on
    # For testing purposes, leave facility to iterate through all monitoringservers
    if ( my $monitoringserver_id = shift @ARGV ) {
        $_ = $schema->resultset("Monitoringservers")->find($monitoringserver_id)
          or die "Invalid monitoring server: id=$monitoringserver_id";
        @monitoringservers = ($_);
    }
    else {

        # Although passive monitoringservers have config generated, they aren't sent out. So leave it to get generated to confirm
        # no changes in Nagios configuration
        @monitoringservers = @all_monitoringservers;
    }

    $monitoringserverhosts =
      $schema->resultset("Monitoringservers")->monitoringserverhosts_lookup;

    foreach $monitoringserver (@monitoringservers) {
        next unless $monitoringserver->is_active;

        my $ms_name = $monitoringserver->name;
        plog "--> Writing config files for $ms_name";

        my @all_nodes;
        if ( $monitoringserver->is_slave ) {
            plog( "Ignoring this monitoring slave server" );
            next;
        }

        $configfilepath = "$main_configfilepath/$ms_name";
        if ( !-d $configfilepath ) {
            mkdir $configfilepath
              or die "Cannot create directory $configfilepath: $!";
        }

        # Local directory for local customisations
        my $local_dir = "$configfilepath/local.d";
        if ( !-d $local_dir ) {
            mkdir $local_dir or die "Cannot create $local_dir: $!";
        }

        # Create the common directory. All contents of this directory will be put into /usr/local/nagios/etc/conf.d/{msname}
        my $common_dir = "$configfilepath/conf.d";
        if ( !-d $common_dir ) {
            mkdir $common_dir or die "Cannot create $common_dir: $!";
        }

        # This could be speeded up (using COUNT(*) in SQL in module)
        my @items;
        %monitors      = ();
        %contactgroups = ();
        my $it = $monitoringserver->monitors;
        while ( my $h = $it->next ) {
            $monitors{ $h->id } = $h->count_servicechecks;
            push @items, $h unless $monitoringserverhosts->{ $h->id };
        }

        write_master_cfg();
        write_nmis_nodecsv( "$configfilepath/nodes.csv" );

        # Need to get host informations based on monitoring server
        @hosts = $monitoringserver->monitors;
        plog( "Created distributed information" );

        create_keyword_lookup_list();

        # Writes out Nagios config files
        # check commands must come before services, as services will append to it
        write_checkcommands();
        write_servicecfg();

        # Note: write hosts after services - this way only relevant contactgroups are created
        write_hostcfg();
        write_hostgroupscfg();
        write_contactscfg();
        write_contactgroupscfg();
        write_nagioscfg();
        write_cgicfg();
        write_misccommandscfg();
        write_timeperiodscfg();
        write_notificationmethodvariables();
        write_nscacfg();
        write_nrdcfg();
        write_send_nscacfg();
        write_ndo2dbcfg();
        write_ndomodcfg();
        write_dependenciescfg();
        write_instance_cfg();

        $using_nmis = $schema->resultset("Hosts")->search(
            {
                use_nmis    => 1,
                enable_snmp => 1
            }
        )->count;
        if ( $monitoringserver->is_master ) {
            write_master_nmiscfg();
            write_nagvis_config();
            Opsview::Hostgroup->add_lft_rgt_values;
        }

        unless ( -d "$configfilepath/plugins" ) {
            mkdir "$configfilepath/plugins"
              or die "Can't create plugins/ directory";
        }
        write_interface_poller();
    }
}

sub write_interface_poller {
    my $cfgdir = "$configfilepath/plugins/check_snmp_interfaces_cascade";
    unless ( -d $cfgdir ) {
        mkdir "$cfgdir" or die "Can't create directory: $cfgdir";
    }
    foreach my $host ( $monitoringserver->monitors ) {

        # TODO: We're hardcoding the Interface Poller service check for now
        next
          unless
          exists $host_services_lookup->{ $host->name }->{"Interface Poller"};

        next unless $host->enable_snmp;

        my @interfaces = $host->snmpinterfaces( { active => 1 } );
        next unless @interfaces;

        my $data = {};
        map { $data->{host}->{$_} = $host->$_ }
          qw(snmp_version snmp_community snmp_port snmpv3_username
          snmpv3_authprotocol snmpv3_authpassword snmpv3_privprotocol snmpv3_privpassword
          tidy_ifdescr_level snmp_max_msg_size ip snmp_extended_throughput_data
        );

        my $default_thresholds =
          $host->snmpinterfaces( { interfacename => "" } )->first;

        # If default row does not exist, then warn for UI and move on
        unless ($default_thresholds) {
            warn( "No default row for SNMP interfaces for host name: "
                  . $host->name );
            next;
        }

        foreach my $int (@interfaces) {
            next unless $int->active;

            # Need to use this to work out the interface name from the device
            my ( $interfacename, undef ) =
              $int->actual_interface_name_and_index;
            my $indexid = $int->indexid;

            my $intdata = $data->{interfaces}->{$interfacename}->{$indexid} =
              {};
            map { $intdata->{$_} = $int->$_ } qw( shortinterfacename indexid );

            my $shortname = $int->shortinterfacename;

            # As this is repeated for throughput, errors and discards,
            # we have a common function here
            my $set_threshold_inherited = sub {
                foreach my $t (@_) {
                    my $value = $int->$t;
                    if ( defined $value && $value eq "" ) {
                        $value = $default_thresholds->$t;
                    }
                    if ( !defined $value ) {
                        $value = "";
                    }
                    $intdata->{$t} = $value;
                }
            };

            # Only include data when the service has been setup
            # TODO: This uses hardcoded service names at the moment. Maybe a lookup based on cascaded
            # servicechecks is a future improvement
            if (
                exists $host_services_lookup->{ $host->name }
                ->{"Interface: $shortname"} )
            {
                $intdata->{throughput} = 1;
                $set_threshold_inherited->(
                    qw(throughput_warning throughput_critical )
                );
            }
            if (
                exists $host_services_lookup->{ $host->name }
                ->{"Errors: $shortname"} )
            {
                $intdata->{errors} = 1;
                $set_threshold_inherited->(
                    qw(errors_warning errors_critical )
                );
            }
            if (
                exists $host_services_lookup->{ $host->name }
                ->{"Discards: $shortname"} )
            {
                $intdata->{discards} = 1;
                $set_threshold_inherited->(
                    qw(discards_warning discards_critical)
                );
            }
        }

        open OUTFILE, ">", "$cfgdir/" . $host->name . ".json"
          or die "Can't create file in $cfgdir: $!";
        print OUTFILE $json->encode($data);
        close OUTFILE;
    }
}

################################################################
# Writes hosts.cfg using @hosttable                            #
################################################################

# TODO: Add notes functionality back in ????
sub write_hostcfg {
    my $c = 0;
    open OUTFILE, ">$configfilepath/hosts.cfg"
      or die "Can't write file $configfilepath/hosts.cfg: $!";

    print OUTFILE <<"EOF";
# Host definition templates
define host{
	name				host-global
	event_handler_enabled		1	; Host event handler is enabled
	flap_detection_enabled		1	; Flap detection is enabled
	process_perf_data		1	; Process performance data
	retain_status_information	1	; Retain status information across program restarts
	retain_nonstatus_information	1	; Retain non-status information across program restarts
	max_check_attempts		2
	obsess_over_host		0
	check_freshness			0
	passive_checks_enabled		1
	check_interval			0	; For the moment, set check_interval to 0 so hosts only checked on demand, like Nagios 2
	contact_groups			empty
	register			0	; DONT REGISTER THIS DEFINITION IT'S JUST A TEMPLATE!
}

define hostescalation {
	name				hostescalation-global
	register			0
	last_notification		0	; Do not stop escalations
}

EOF

    # Caching the name of all servicegroups;
    my @servicegroupnames = ();
    foreach my $sg (@servicegroups) {
        push @servicegroupnames, $sg->typeid;
    }
    @servicegroupnames = sort @servicegroupnames;

    my $parents_lookup_args = {
        monitors_lookup              => \%monitors,
        monitoringserverhosts_lookup => $monitoringserverhosts,
    };
    my $parents_lookup =
      $schema->resultset("Hosts")->calculate_parents($parents_lookup_args);

    # We need to reset this so that each monitoring system only lists what it knows about
    $configuration_cache_data = {};

    # We need to keep a track of all hostnames used so parents are not looked up incorrectly as individual hosts maybe disabled
    # by being excluded from deactivated monitoring servers
    foreach my $host (@hosts) {
        $hostname_lookup->{ $host->name }++;
    }

    my $hostip_lookup = {};
    my %seen;

    foreach my $host (@hosts) {
        my $hostid   = $host->id;
        my $hostname = $host->name;
        my @parents =
          map { $hostname_lookup->{$_} ? $_ : () }
          ( @{ $parents_lookup->{$hostid} } );

        my $host_monitored_by_this_opsview_server =
          ( $monitoringserver == $host->get_column("monitored_by") );

        # Lookup and cache host IP's for checking potential
        # MRTG configuration errors
        if ( $host->use_mrtg && $host->enable_snmp ) {
            my $hostips;
            if ( exists $seen{$hostid} ) {
                $hostips = $seen{$hostid};
            }
            else {
                $hostips = $host->hostip;
                $seen{$hostid} = $hostips;
                unless (@$hostips) {
                    warn(
                            "Unable to lookup IP address for '"
                          . $hostname . "' ("
                          . $host->ip
                          . ") - ignoring MRTG configuration for this host"
                    );

                    # Keep previous behaviour when unable to look up IP's
                    #next;
                }
                else {
                    foreach my $h (@$hostips) {
                        push @{ $hostip_lookup->{$h} }, $hostname;
                    }
                }
            }
        }

        my $hostgroup = $host->hostgroup;
        my $hgname    = $hostgroup->name;
        if ( !exists $configuration_cache_data->{hostgroups}->{$hgname} ) {
            my $matpath = $hostgroup->matpath;
            $matpath =~ s/,$//;
            $configuration_cache_data->{hostgroups}->{$hgname} =
              { matpath => $matpath };
        }

        # The host goes into each hostgroup_servicegroup contactgroup
        # and keywords and also ov_monitored_by_master on master if it is actively checked
        my $hg = $hostgroup->typeid;
        my @cgs;
        foreach my $sgname (@servicegroupnames) {
            $_ = $hg . "_" . $sgname;
            next unless $contactgroups{$_};
            push @cgs, $_;
        }
        if ( my $keywordid_hashref =
            $keyword_host_service_lookup->{$hostname}->{keywords} )
        {
            push @cgs, map { "k" . $_ } ( sort keys %$keywordid_hashref );
        }
        if ( $monitoringserver->is_master && distributed() ) {
            if ($host_monitored_by_this_opsview_server) {
                push @cgs, "ov_monitored_by_master";
            }
        }

        my ( $icon_name, $icon_file );
        $_         = $host->icon;
        $icon_name = $_->name;
        $icon_file = $_->filename;

        my $host_info_url;
        if ( $_ = $system_preference->host_info_url ) {
            $host_info_url = $_;
        }
        else {
            $host_info_url = $override_base_prefix;
            $host_info_url .= "/info/host/" . $hostid;
        }

        print OUTFILE "# " . $hostname . " host definition
define host {
	host_name	" . $hostname . "
	alias		" . ( $host->alias || $hostname ) . "
	address		" . $host->ip . "
	hostgroups	" . $hgname . "
	check_interval	" . $host->check_interval . "
	retry_interval	" . $host->retry_check_interval . "
	max_check_attempts " . $host->check_attempts . "
	flap_detection_enabled	" . $host->flap_detection_enabled . "
	icon_image	$icon_file.png
	icon_image_alt	$icon_name
	vrml_image	$icon_file.png
	statusmap_image	$icon_file.png
	action_url	$host_info_url
";

        unless ($host_monitored_by_this_opsview_server) {
            print OUTFILE "	active_checks_enabled	0
";
        }

        if ( defined $host->check_period ) {
            print OUTFILE '	check_period	' . $host->check_period->name, $/;
        }

        print OUTFILE "	contact_groups	" . join( ",", @cgs ) . "\n" if (@cgs);
        map { $contactgroups{$_}++ } (@cgs);

        # If host is monitored by a slave, do not define a check_command on master
        if ($host_monitored_by_this_opsview_server) {
            if ( defined( my $hc = $host->check_command ) ) {
                my $args = $host->expand_host_macros( $hc->args );
                $args = $host->substitute_host_attributes($args);
                print OUTFILE "	check_command		check_host_"
                  . $hc->id()
                  . "!$args\n";
            }
            else {
                # if no host command defined, set it be always true
                print OUTFILE
                  "	check_command		my_check_dummy!0!'Assumed always up'\n";
            }
        }

        print OUTFILE "	parents	" . join( ",", @parents ) . "\n" if @parents;

        if ( $host->notifications_enabled ) {
            print OUTFILE "	notifications_enabled	1\n";
            print OUTFILE "	notification_interval	"
              . notification_interval_warning( $host->notification_interval,
                $host->check_interval )
              . "\n";
            print OUTFILE "	notification_period	"
              . $host->notification_period . "\n";
            print OUTFILE "	notification_options	"
              . $host->notification_options . "\n";
        }
        else {
            print OUTFILE "	notifications_enabled	0\n";
            print OUTFILE "	notification_interval	0\n";
            print OUTFILE "	notification_options	n\n";
        }

        if ( $host_monitored_by_this_opsview_server && $host->event_handler ) {
            my $event_handler_alias = "event-handler-host-" . $host->id;
            print OUTFILE "	event_handler       $event_handler_alias\n";
        }

        if (1) {
            print OUTFILE "	use	host-global\n";
        }

        print OUTFILE "}\n\n";

        $c++;
    }
    close OUTFILE;

    # Remove duplicate hostnames for each hostip
    foreach my $hostip ( keys %$hostip_lookup ) {
        my %hostname;
        map { $hostname{$_} = 1 } @{ $hostip_lookup->{$hostip} };
        $hostip_lookup->{$hostip} = [ sort keys %hostname ];

        # Warnings if more than one Nagios hostname for a single IP
        warn(
            "IP $hostip has more than 1 host associated with it for use with MRTG: "
              . join( ", ", sort( keys(%hostname) ) ) )
          if ( scalar keys %hostname > 1 );
    }

    plog "$c hosts written to hosts.cfg";
}

################################################################
# Writes services.cfg
################################################################

sub write_servicecfg {
    my $c = 0;
    open OUTFILE, ">$configfilepath/services.cfg"
      or die "Can't open file $configfilepath/services.cfg: $!";
    open COMMAND, ">>$configfilepath/checkcommands.cfg"
      or die "Can't open file $configfilepath/checkcommands.cfg: $!";

    print OUTFILE<<"EOF";
define service{
	name				service-global
	active_checks_enabled		1	; Active service checks are enabled
	passive_checks_enabled		1	; Passive service checks are enabled/accepted
	obsess_over_service		0	; We should obsess over this service (if necessary)
	check_freshness			0	; Default is to NOT check service 'freshness'
	notifications_enabled		1	; Service notifications are enabled
	event_handler_enabled		1	; Service event handler is enabled but ignored unless event_handler set
	flap_detection_enabled		1	; Flap detection is enabled
	process_perf_data		1	; Process performance data
	retain_status_information	1	; Retain status information across program restarts
	retain_nonstatus_information	1	; Retain non-status information across program restarts
	is_volatile			0
	check_period			24x7
	register			0	; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
}

define serviceescalation {
	name				serviceescalation-global
	register			0
	last_notification		0      ; Do not stop escalations
}

# Special commands
define command{
	command_name	my_negate
	command_line	$libexecpath/negate -t 240 $libexecpath/\$ARG1\$
}
define command{
        command_name    my_check_dummy
        command_line    $libexecpath/check_dummy \$ARG1\$ \$ARG2\$
        }
define command{
	command_name    set_to_stale
	command_line    /usr/local/nagios/bin/set_to_stale
	}
define command{
	command_name    set_to_stale_timedoverride
	command_line    /usr/local/nagios/bin/set_to_stale
	}
define command{
	command_name    refresh_state
	command_line    /usr/local/nagios/bin/refresh_state
    env NAGIOS_SERVICEDESC=\$SERVICEDESC\$
    env NAGIOS_SERVICEOUTPUT=\$SERVICEOUTPUT\$
    env NAGIOS_SERVICEPERFDATA=\$SERVICEPERFDATA\$
    env NAGIOS_SERVICESTATEID=\$SERVICESTATEID\$
    env NAGIOS_HOSTOUTPUT=\$HOSTOUTPUT\$
    env NAGIOS_HOSTPERFDATA=\$HOSTPERFDATA\$
    env NAGIOS_HOSTSTATEID=\$HOSTSTATEID\$
	}
define command{
	command_name    my_check_snmp
	command_line    $libexecpath/check_snmp -H \$HOSTADDRESS\$ \$ARG1\$ -o \$ARG2\$ \$ARG3\$
	}

# Below are the automatically generated check host definitions
EOF

    my $hostcheckcommands_rs = $schema->resultset("Hostcheckcommands")->search(
        {},
        {
            join     => "hosts",
            prefetch => "plugin",
            order_by => "me.id",
            distinct => 1,
        }
    );
    foreach my $hostcheck_definition ( $hostcheckcommands_rs->search() ) {
        my $id     = $hostcheck_definition->id();
        my $plugin = $hostcheck_definition->plugin();
        my $name   = $hostcheck_definition->name();
        my $command;
        my $envvars;

        # Need to check here because db could be set to NULL for plugin
        # This is a nice way of showing that there is some data missing
        if ( !defined $plugin ) {
            $command =
              "$libexecpath/check_dummy 2 \"Host check command not defined in Opsview\"";
        }
        else {

            # We use ARG1 so that host macros can be set
            $command = "$libexecpath/$plugin \$ARG1\$";
            $envvars = $plugin->envvars;
        }

        print OUTFILE<<"EOF";
# 'check_host_$id' command definition for $name
    define command{
        command_name    check_host_$id
        command_line    $command
EOF
        foreach my $env ( split( ",", $envvars ) ) {
            print OUTFILE "env NAGIOS_$env=\$$env\$\n";
        }
        print OUTFILE "}\n";

    }

    foreach my $h (@hosts) {
        my $service_template;
        if (1) {
            $service_template = "service-global";
        }

        my $host_monitored_by_this_opsview_server =
          ( $monitoringserver == $h->get_column("monitored_by") );

        my $array = $h->resolved_servicechecks;
        foreach my $sc (@$array) {
            next if $sc->{remove_servicecheck};
            my $s = $sc->{servicecheck};

            # Use variables to save Class::DBI accessors
            my $checktype   = $s->checktype->id;
            my $servicename = $s->name;

            next
              if $checktype == 3; # Ignore basic snmptrap servicechecks

            # Ignore SNMP traps as these are no longer available in Core
            if ( $checktype == 4 ) {
                next;
            }

            # TODO: This isn't the cleanest implementation. Interface Poller should not be generated
            # if there are no INTERFACE attributes set. This probably should be some configuration
            # on the Interface Poller servicecheck (eg, a tickbox of "Create X services per attribute"
            # with default X, but an option of 1). However, we'll just hard code here for now
            if ( $servicename eq "Interface Poller" ) {
                next if $h->snmpinterfaces( { active => 1 } )->count == 0;
            }

            # Need the multiple_services id to get the Attribute type from DBIx::Class because we're migrating away from Class::DBI
            # and the relationship is not present
            # We do this early because if this service check is a multiple one but there are no attributes set, then just ignore
            my $multiple_services_id =
              ( $checktype =~ /^(1|2)$/ && $s->attribute )
              ? $s->attribute
              : 0;
            my @multiple_service_attributes = ();
            if ($multiple_services_id) {
                my $multiple_services_attribute_name =
                  get_attribute_name($multiple_services_id);

                # Ignore these attributes, as not available in Core
                if ( $multiple_services_attribute_name eq "SLAVENODE" ) {
                    next;
                }
                if ( $multiple_services_attribute_name eq "CLUSTERNODE" ) {
                    next;
                }
                @multiple_service_attributes =
                  $h->host_attributes_for_name(
                    $multiple_services_attribute_name);
                next unless @multiple_service_attributes;
            }

            my @contactgroups =
              ( $h->hostgroup->typeid . "_" . $s->servicegroup->typeid );

            my @contactgroup_keywordids;

            # Add keywords, if appropriate. Deliberately ignore host=* and service=*
            if ( my $keywordid_hashref =
                $keyword_host_service_lookup->{ $h->name }->{services}
                ->{$servicename} )
            {
                foreach my $keyword_id ( keys %$keywordid_hashref ) {
                    push @contactgroup_keywordids, $keyword_id;
                }
            }
            if ( my $keywordid_hashref =
                $keyword_host_service_lookup->{"*"}->{services}->{$servicename}
              )
            {
                foreach my $keyword_id ( keys %$keywordid_hashref ) {
                    push @contactgroup_keywordids, $keyword_id;
                }
            }
            if ( my $keywordid_hashref =
                $keyword_host_service_lookup->{ $h->name }->{services}->{"*"} )
            {
                foreach my $keyword_id ( keys %$keywordid_hashref ) {
                    push @contactgroup_keywordids, $keyword_id;
                }
            }

            # Set contact groups
            foreach my $keyword_id (@contactgroup_keywordids) {

                # We set this here so that only hosts that actually have services associated will be recorded
                $keyword_host_service_lookup->{ $h->name }->{keywords}
                  ->{$keyword_id}++;

                push @contactgroups, "k" . $keyword_id;
            }

            my $commandalias;

            my %notification_options;
            map { $notification_options{$_}++ }
              split( ",", $s->notification_options );
            if ( !$host_monitored_by_this_opsview_server ) {
                $commandalias = "set_to_stale";
            }
            elsif ( $checktype == 1 ) {
                $commandalias = $h->expand_host_macros(
                    $s->command(
                        args => $sc->{args},
                        sep  => "!"
                    )
                );

                # We expand macros out, unless this is going to be a multiple services check, in which case it gets expanded out later
                if ( !$multiple_services_id ) {
                    $commandalias =
                      $h->substitute_host_attributes($commandalias);
                }
            }
            elsif ( $checktype == 4 || $checktype == 2 ) {

                # You would think that these should only be set if check_freshness==1, but Nagios wants some command alias to
                # get set
                if ( $s->freshness_type eq "renotify" ) {
                    $commandalias = "refresh_state";
                }
                elsif ( $s->freshness_type eq "set_stale" ) {
                    $commandalias =
                        "my_check_dummy!"
                      . $s->stale_state . "!"
                      . Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $s->stale_text
                        )
                      );
                }
            }
            elsif ( $checktype == 5 ) { # SNMP polling
                 # Ignore these types of checks unless SNMP enabled
                next unless $h->enable_snmp;

                $commandalias = "my_check_snmp";
                my $oid = $s->oid;
                if ( $oid =~ /^\.?(\d+\.)*\d+$/ ) {

                    # Already numeric - leave it
                }
                else {
                    load_snmp();
                    $oid = &SNMP::translateObj($oid);
                }
                my $snmp_auth;
                if ( $h->snmp_version eq "3" ) {
                    my $snmpv3_username = Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $h->snmpv3_username
                        )
                    );
                    my $snmpv3_authprotocol =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $h->snmpv3_authprotocol
                        )
                      );
                    my $snmpv3_authpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $h->snmpv3_authpassword
                        )
                      );
                    my $snmpv3_privprotocol = uc(
                        Opsview::Utils->make_shell_friendly(
                            Opsview::Utils->cleanup_args_for_nagios(
                                $h->snmpv3_privprotocol
                            )
                        )
                    );
                    my $snmpv3_privpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $h->snmpv3_privpassword
                        )
                      );
                    $snmp_auth =
                      "-P 3 -L authPriv -U $snmpv3_username -a $snmpv3_authprotocol -A $snmpv3_authpassword -x $snmpv3_privprotocol -X $snmpv3_privpassword";
                }
                else {
                    $snmp_auth =
                        "-P "
                      . $h->snmp_version . " -C "
                      . (
                        Opsview::Utils->make_shell_friendly(
                            Opsview::Utils->cleanup_args_for_nagios(
                                $h->snmp_community
                            )
                        )
                      );
                }

                # snmp port
                $snmp_auth .= " -p " . $h->snmp_port;

                my $other_args = $s->check_snmp_threshold_args;
                $other_args .= " -l " . $s->label if $s->label;

                # At the moment, this is run from nagconfgen. Should move to Opsview::Schema::Servicechecksnmppolling in future
                if ( $s->calculate_rate eq "per_second" ) {
                    $other_args .= " --rate";
                }
                elsif ( $s->calculate_rate eq "per_minute" ) {
                    $other_args .= " --rate --rate-multiplier=60";
                }
                elsif ( $s->calculate_rate eq "per_hour" ) {
                    $other_args .= " --rate --rate-multiplier=3600";
                }
                $commandalias .= "!$snmp_auth!$oid!$other_args";
            }
            else {
                $commandalias = "set_to_stale";
            }

            my $check_interval = $s->check_interval
              || ( 5 * $nagios_interval_convert_from_minutes );
            print OUTFILE "# "
              . $servicename
              . " service definition for host "
              . $h->name . "
define service {
	host_name " . $h->name . "
	service_description	" . $servicename . "
	check_command		$commandalias
	retry_check_interval	"
              . ( $s->retry_check_interval
                  || ( 1 * $nagios_interval_convert_from_minutes ) )
              . "
";

            if ($host_monitored_by_this_opsview_server) {
                if ( $sc->{event_handler} ) {
                    my ( $cmd, $args ) = split( m/ /, $sc->{event_handler}, 2 );
                    my $command_alias =
                      "host" . $h->id . "_service" . $s->id . "_eh-" . $cmd;
                    my $command = "$libexecpath/eventhandlers/" . $cmd;

                    # if there's an event handler for this service check, set it...
                    print OUTFILE "	event_handler       $command_alias
";

                    print COMMAND "# event handler
define command {
	command_name        $command_alias
	command_line        $command $args
";
                    foreach my $env (
                        split( ",", $nagios_envvars_for_eventhandlers ) )
                    {
                        print COMMAND "env NAGIOS_$env=\$$env\$\n";
                    }
                    print COMMAND "}\n";
                }
                elsif ( $s->event_handler ) {
                    my $event_handler_alias = "event-handler-" . $s->id;
                    print OUTFILE "	event_handler       $event_handler_alias\n";
                }
            }

            if ( $sc->{timedoverride} && ${commandalias} ne "set_to_stale" ) {
                my $args = $h->expand_host_macros(
                    $s->command(
                        args => $sc->{timedoverride_args},
                        sep  => "!"
                    )
                );
                $args = $h->substitute_host_attributes($args);
                print OUTFILE "	check_timeperiod_command    "
                  . $sc->{timedoverride_timeperiod}
                  . ",$args\n";
            }

            if ( $s->check_period ) {
                print OUTFILE '	check_period		' . $s->check_period, $/;
            }
            else {
                print OUTFILE '	check_period		' . $h->check_period, $/;
            }

            # Active checks respect the check_attempts and flap_detection_enabled in the database
            # Otherwise, check_attempts should be 1 for passive checks/SNMPtraps
            if ( $checktype == 1 or $checktype == 5 ) {
                print OUTFILE "	max_check_attempts      "
                  . ( $s->check_attempts || 3 ) . "\n";
                print OUTFILE "	flap_detection_enabled	"
                  . $s->flap_detection_enabled . "\n";
            }
            else {
                print OUTFILE "	max_check_attempts	"
                  . ( $s->alert_from_failure || 1 ) . "\n";
                print OUTFILE "	flap_detection_enabled	0\n";
                $check_interval = 0;
            }

            if ( $s->stalking ) {
                print OUTFILE "	stalking_options " . $s->stalking . "\n";
            }
            if ( $s->volatile ) {
                print OUTFILE "	is_volatile " . $s->volatile . "\n";
            }

            # Disable active checks unless:
            #  check type is "Active" and this monitoring server is the one that the host is on
            if (
                !(
                    (
                           $checktype == 1
                        or $checktype == 5
                    )
                    && ($host_monitored_by_this_opsview_server)
                )
              )
            {
                print OUTFILE "	active_checks_enabled	0
"
            }

            my $freshness_threshold_add;

            # Only enable notifications if the service and the host want it
            if ( $s->notifications_enabled && $h->notifications_enabled ) {
                my $notification_interval;
                if ( defined $s->notification_interval ) {
                    $notification_interval = $s->notification_interval;
                }
                elsif ( defined $h->notification_interval ) {
                    $notification_interval = $h->notification_interval;
                }
                else {
                    $notification_interval =
                      15 * $nagios_interval_convert_from_minutes;
                }
                print OUTFILE "	notifications_enabled	1
	notification_period	"
                  . ( $s->notification_period || $h->notification_period ) . "
	notification_interval	"
                  . notification_interval_warning( $notification_interval,
                    $check_interval )
                  . "
	notification_options	" . join( ",", sort keys %notification_options ) . "
";

                # Resubmit passive checks for advanced snmptraps + passive checks if renotify is set
                # Only apply to slave as master may get extraneous stale results
                if (   ( $checktype == 4 || $checktype == 2 )
                    && $s->check_freshness
                    && $host_monitored_by_this_opsview_server
                    && $s->freshness_type eq "renotify" )
                {
                    $freshness_threshold_add =
                      $notification_interval * $nagios_interval_length;
                }
            }
            else {
                print OUTFILE "	notifications_enabled	0
	notification_period	24x7
	notification_interval	0
	notification_options	n
";
            }

            if (   ( $checktype == 4 || $checktype == 2 )
                && $s->check_freshness
                && $host_monitored_by_this_opsview_server
                && $s->freshness_type eq "set_stale" )
            {
                $freshness_threshold_add = $s->stale_threshold_seconds;
            }

            if ( defined $freshness_threshold_add ) {

                # Nagios will ignore freshness_threshold==0 && check_interval==0
                # as it is impossible to work out the actual value to use.
                # Since we know the interval, we'll set that, which is all Nagios would
                # do anyway
                if ( $freshness_threshold_add == 0 ) {
                    $freshness_threshold_add =
                      $check_interval * $nagios_interval_length;
                }

                print OUTFILE "	check_freshness		1
	freshness_threshold	$freshness_threshold_add
";
                $check_interval = 0;
            }

            # We need to add this later on because passive service checks
            # in a slave cluster will have the active_checks_enabled flipped
            # on. Setting to 0 will stop it from being executed unnecessarily
            print OUTFILE "	normal_check_interval	$check_interval\n";

            my @actual_contactgroup_names = @contactgroups;
            if ( $monitoringserver->is_master && distributed() ) {
                if ($host_monitored_by_this_opsview_server) {
                    push @actual_contactgroup_names, "ov_monitored_by_master";
                }
            }
            print OUTFILE "	contact_groups	"
              . join( ",", @actual_contactgroup_names ) . "\n";
            map { $contactgroups{$_}++ } @actual_contactgroup_names;

            if (
                (
                       $checktype == 1
                    or $checktype == 5
                )
                && !$host_monitored_by_this_opsview_server
              )
            {
                print OUTFILE "	check_freshness		1
";
            }

            # Add servicegroup and description information into notes, so notification handlers can access this information
            # In Nagios 3, this can be added into service stanza using custom macros
            print OUTFILE "	notes	"
              . $s->servicegroup->name . ':'
              . $s->description . "\n";
            if ( $monitoringserver->is_master ) {
                if ( !$multiple_services_id ) {

                    # Add performance graph if rrd is available
                    # We use notes_url in Runtime::Searches to know if a service has perfdata or not
                    if (
                        $s->supports_performance(
                            host   => $h,
                            rrddir => Opsview::Config->root_dir . "/var/rrd"
                        ) == 1
                      )
                    {
                        unless ($test) {
                            print OUTFILE
                              "	notes_url	$graph_url?host=\$HOSTNAME\$&service=\$SERVICEDESC\$
        icon_image	graph.png
        icon_image_alt	View graphs
    ";
                        }
                    }
                }
            }

            print OUTFILE "	use	$service_template\n";

            if ( !$multiple_services_id ) {
                print OUTFILE "}\n\n";

                $host_services_lookup->{ $h->name }->{$servicename} = 1;
            }
            else {
                my $template_name = "multiple-" . $h->id . "-" . $s->id;
                print OUTFILE "	register 0\n";
                print OUTFILE "	name $template_name\n";
                print OUTFILE "}\n\n";

                # Create a definition for each instance of the host variable
                foreach my $host_attribute (@multiple_service_attributes) {
                    my $overrides = $host_attribute->arg_lookup_hash();

                    my $subst_command =
                      $h->substitute_host_attributes( $commandalias,
                        $overrides );
                    my $service_desc =
                      $servicename . ": " . $host_attribute->value;

                    if ( length $service_desc > 128 ) {
                        die(
                            "Service description '$service_desc' is greater than 128 characters. Please change the attribute or service check name to be shorter"
                        );
                    }

                    # Save list of multiple service checks for creating dependencies
                    push
                      @{ $multiple_services_lookup->{ $h->name }->{$servicename}
                      }, $service_desc;

                    print OUTFILE "define service {
	host_name " . $h->name . "
	service_description	$service_desc
	check_command		$subst_command
	use $template_name
";
                    if ( $monitoringserver->is_master ) {

                        # Add performance graph if rrd is available
                        # We use notes_url in Runtime::Searches to know if a service has perfdata or not
                        if (
                            $s->supports_performance(
                                name   => $service_desc,
                                host   => $h,
                                rrddir => Opsview::Config->root_dir
                                  . "/var/rrd"
                            ) == 1
                          )
                        {
                            unless ($test) {
                                print OUTFILE
                                  "	notes_url	$graph_url?host=\$HOSTNAME\$&service=\$SERVICEDESC\$
            icon_image	graph.png
            icon_image_alt	View graphs
        ";
                            }
                        }
                    }
                    print OUTFILE "}\n";

                    $host_services_lookup->{ $h->name }->{$service_desc} = 1;
                }
            }

            $c++;
        }

    }
    close OUTFILE;
    close COMMAND;
    plog "$c service definitions written to services.cfg";
}

sub write_checkcommands {
    my $c = 0;
    open COMMAND, ">$configfilepath/checkcommands.cfg"
      or die "Can't open file $configfilepath/checkcommands.cfg: $!";
    my @plugins = $schema->resultset("Plugins")->search(
        { "servicechecks.plugin" => { "!=" => undef } },
        {
            join     => "servicechecks",
            distinct => 1,
            columns  => [qw(name envvars)],
        }
    );
    foreach my $plugin (@plugins) {
        print COMMAND "define command {
        command_name    " . $plugin->name . "
        command_line    $libexecpath/" . $plugin->name . " \$ARG1\$
";
        foreach my $env ( split( ",", $plugin->envvars ) ) {
            print COMMAND "env NAGIOS_$env=\$$env\$\n";
        }
        print COMMAND "}\n";
        $c++;
    }
    foreach my $sc (
        $schema->resultset("Servicechecks")->search(
            { event_handler => { "!=" => "" } },
            { columns       => [qw/id event_handler/] }
        )
      )
    {
        print COMMAND "define command {
command_name event-handler-" . $sc->id . "
command_line $libexecpath/eventhandlers/" . $sc->event_handler . "
";
        foreach my $env ( split( ",", $nagios_envvars_for_eventhandlers ) ) {
            print COMMAND "env NAGIOS_$env=\$$env\$\n";
        }
        print COMMAND "}\n";
        $c++;
    }
    foreach my $host (
        $schema->resultset("Hosts")->search(
            { event_handler => { "!=" => "" } },
            { columns       => [qw/id event_handler/] }
        )
      )
    {
        print COMMAND "define command {
command_name event-handler-host-" . $host->id . "
command_line $libexecpath/eventhandlers/" . $host->event_handler . "
";
        foreach my $env ( split( ",", $nagios_envvars_for_eventhandlers ) ) {
            print COMMAND "env NAGIOS_$env=\$$env\$\n";
        }
        print COMMAND "}\n";
        $c++;
    }

    close COMMAND;
    plog "$c commands written to checkcommands.cfg";
}

sub write_master_cfg {
    open OUTFILE, ">$configfilepath/master.cfg"
      or die "Can't write to master.cfg: $!";
    print OUTFILE "define service {
	name			service-distributed
	register		0
	use			service-global
	active_checks_enabled	0
	check_freshness		1
	check_command		!set_to_stale
}
define service {
	name			service-slave-eventhandler
	register		0
	event_handler_enabled	0
}
";

    close OUTFILE;
}

################################################################
# Writes NMIS' master stuff
################################################################
sub write_master_nmiscfg {
    open OUTFILE, ">$configfilepath/nmis.conf"
      or die "Can't write to nmis.conf: $!";
    open ORIGINAL, "/usr/local/nagios/nmis/conf/nmis.conf"
      or die "Can't read nmis.conf: $!";
    my @original = <ORIGINAL>;
    close ORIGINAL;
    my $this_host = $system_preference->opsview_server_name
      || Opsview::Monitoringserver->get_master->host->ip;
    map {
        s/^nmis_host=.*/nmis_host=$this_host/;
        s%^<cgi_url_base>=.*%<cgi_url_base>=$override_base_prefix/cgi-nmis%;
        s%^<url_base>=.*%<url_base>=$override_base_prefix/static/nmis%;
    } @original;
    print OUTFILE @original;
    close OUTFILE;

    # The master.csv file controls whether NMIS is used or not, via call_nmis
    open OUTFILE, ">$configfilepath/master.csv"
      or die "Can't write to file $configfilepath/master.csv: $!";
    if ($using_nmis) {
        my $name   = $monitoringserver->host->name;
        my $hostip = $monitoringserver->host->ip;
        print OUTFILE <<EOF;
Name	Host
$name	$hostip
EOF
    }
    close OUTFILE;

    open OUTFILE_SLAVE, ">$configfilepath/slave.csv"
      or die "Can't write to file $configfilepath/slave.csv: $!";
    open OUTFILE_SLAVES, ">$configfilepath/slaves.csv"
      or die "Can't write to file $configfilepath/slaves.csv: $!";
    print OUTFILE_SLAVE <<EOF;
Name	Host	Var	Data	NodeFile
EOF
    print OUTFILE_SLAVES <<EOF;
Name	Host	Port	Conf	Community	Secure
EOF
    close OUTFILE_SLAVE;
    close OUTFILE_SLAVES;

}

################################################################
# Write Nagvis configuration
# This is a bit different to everything else as it will make a change to
# the configuration file immediately. This needs to be done
# because there are other data that a user could change straight away, so
# changing this immediately (rather than wait for verification) is preferable
# The changes are connection details and other items which are not actually
# host/service specific, so this should be okay
################################################################
sub write_nagvis_config {
    my $nagvis_dir        = "/usr/local/nagios/nagvis";
    my $nagvis_config     = "$nagvis_dir/etc/nagvis.ini.php";
    my $nagvis_config_new = "$configfilepath/nagvis.ini.php";

    # This shouldn't happen, but we restore the file appropriately from the sample
    unless ( -e $nagvis_config ) {
        if ( !-e $nagvis_config . "-sample" ) {
            die "Cannot find sample nagvis file";
        }
        copy( $nagvis_config . "-sample", $nagvis_config )
          or die "Cannot copy $nagvis_config";
    }

    open OLD,     "<", $nagvis_config;
    open OUTFILE, ">", $nagvis_config_new
      or die "Can't write to $nagvis_config_new: $!";
    my $htmlbase = $override_base_prefix;
    my $dbname   = Opsview::Config->runtime_db;
    my $dbuser   = Opsview::Config->runtime_dbuser;
    my $dbpass   = Opsview::Config->runtime_dbpasswd;

    while (<OLD>) {
        s%^;?htmlbase=.*%htmlbase="$htmlbase/nagvis"%;
        s%^;?htmlcgi=.*%htmlcgi="$htmlbase/cgi-bin"%;
        s%^opsviewbase=.*%opsviewbase="$htmlbase"%;
        s%^htmlshape=.*%htmlshape="$htmlbase/images/logos/"%;
        s/^;?dbname=.*/dbname="$dbname"/;
        s/^;?dbhost=.*/dbhost="localhost"/;
        s/^;?dbuser=.*/dbuser="$dbuser"/;
        s/^;?dbpass=.*/dbpass="$dbpass"/;
        print OUTFILE $_;
    }
    close OLD     or die "Can't close to nagvis.ini.php: $!";
    close OUTFILE or die "Can't close $nagvis_config_new: $!";

    if ( !$test ) {
        move( $nagvis_config, "$nagvis_config.old" )
          or die "Cannot move $nagvis_config to $nagvis_config.old: $!";
        move( $nagvis_config_new, $nagvis_config )
          or die "Cannot rename $nagvis_config_new to $nagvis_config: $!";
        chmod 0660, $nagvis_config
          or die "Can't amend permissions on nagvis config file: $!";
        chown -1, $nagcmd_gid, $nagvis_config
          or die "Can't amend group ownership on nagvis config file: $!";
    }
}

################################################################
# Writes hostgroups.cfg
################################################################

sub write_hostgroupscfg {
    my $c = 0;

    open OUTFILE, ">$configfilepath/hostgroups.cfg"
      or die "Can't write to file $configfilepath/hostgroups.cfg: $!";

    my $it =
      Opsview::Hostgroup->retrieve_by_monitoringserver($monitoringserver);
    while ( my $hostgroup = $it->next ) {
        next unless $hostgroup->count_hosts;

        print OUTFILE "define hostgroup {
	hostgroup_name	" . $hostgroup->name . "
	alias		" . $hostgroup->name . "
}

";
        $c++;
    }
    close OUTFILE;
    plog "$c hostgroups written to hostgroups.cfg";
}

################################################################
# Writes dependencies.cfg
################################################################

sub write_dependenciescfg {
    my $c = 0;

    # Note - writes to services file
    open OUTFILE, ">> $configfilepath/services.cfg"
      or die "Can't write to file $configfilepath/services.cfg: $!";

    my $dependencies =
      Opsview::Servicecheck->resolved_dependencies($monitoringserver);
    foreach my $row (@$dependencies) {
        my $temp_service_list;

        # If there are multiple services associated, use that list
        if ( my $host_attributes_list =
            $multiple_services_lookup->{ $row->{host}->{name} }
            ->{ $row->{servicecheck}->{name} } )
        {
            $temp_service_list = $host_attributes_list;
        }

        # If it is meant to be a multiple services but nothing associated, then no dependency required
        elsif ( $row->{servicecheck}->{attribute} ) {
            $temp_service_list = [];

        }

        # Else this is a normal service check with dependency
        else {
            $temp_service_list = [ $row->{servicecheck}->{name} ];
        }

        foreach my $servicename (@$temp_service_list) {
            next unless $hostname_lookup->{ $row->{host}->{name} };

            # Do some filtering to check that these services exist first, due to other logic
            # that may remove these definitions
            next
              unless exists $host_services_lookup->{ $row->{host}->{name} }
              ->{ $row->{dependency}->{name} };
            next
              unless exists $host_services_lookup->{ $row->{host}->{name} }
              ->{$servicename};

            print OUTFILE "define servicedependency {
host_name	" . $row->{host}->{name} . "
service_description	" . $row->{dependency}->{name} . "
dependent_host_name	" . $row->{host}->{name} . "
dependent_service_description	" . $servicename . "
notification_failure_criteria	w,c,u
execution_failure_criteria w,c,u
}
";
            $c++;
        }
    }
    close OUTFILE;
    plog "$c dependencies written to services.cfg";
}

################################################################
# Writes contacts.cfg                                          #
################################################################

sub write_contactscfg {
    my $c  = 0;
    my $np = 0;

    open OUTFILE, ">$configfilepath/contacts.cfg"
      or die "Can't open file $configfilepath/contacts.cfg: $!";

    print OUTFILE <<'EOF';
# contact template - required as nagios -v complains if a contact does not
# have any commands
define contact {
	name					global-contact
	service_notification_commands		notify-none
	host_notification_commands		notify-none
	email					dummy@localhost
	service_notification_period		24x7
	host_notification_period		24x7
	service_notification_options		n
	host_notification_options		n
	register				0
}
EOF

    # Use this array to cache the contacts, to save later lookups
    my @all_contacts =
      $schema->resultset("Contacts")->search( undef, { order_by => "name" } );

    my @used_contacts;

    foreach my $contact (@all_contacts) {

        # Ignore contacts without Nagios access
        next
          unless $contact->has_access(
            "VIEWSOME",   "VIEWALL", "NOTIFYSOME", "ACTIONALL",
            "ACTIONSOME", "ADMINACCESS"
          );

        my $profile_number = 1;

        # Strip unused contactgroups
        my @contactgroups = grep { $contactgroups{$_} } $contact->contactgroups;

        # Ignore contacts that do not have access to anything
        next unless (@contactgroups);

        push @used_contacts, $contact;

        print OUTFILE "# '" . $contact->fullname . "' contact definition
define contact {
	contact_name	" . $contact->username . "
	alias		" . $contact->fullname . "
	use		global-contact
";
        print OUTFILE "	contactgroups	" . join( ",", @contactgroups ) . "\n";

        unless ( $contact->has_access("ACTIONALL")
            || $contact->has_access("ACTIONSOME") )
        {
            print OUTFILE "	can_submit_commands	0\n";
        }
        print OUTFILE "}\n\n";
        $c++;

        foreach my $notificationprofile (
            $contact->notificationprofiles,
            $contact->sharednotificationprofiles
          )
        {

            # Strip unused contact groups
            my @contactgroups =
              sort grep { $contactgroups{$_} }
              $notificationprofile->contactgroups;

            my @service_notification_commands = ();
            my @host_notification_commands    = ();

            my $username = $contact->username;
            my $nice_name =
              sprintf( "%02d", $profile_number )
              . lc( $notificationprofile->name );
            $nice_name =~ s/ //g;
            my $contact_name = $username . "/" . $nice_name;

            my $temp_contact_name = $contact_name;

            print OUTFILE "# '" . $contact->name . "' contact definition
define contact {
	contact_name	$temp_contact_name
	alias		" . $contact->fullname . "
	use		global-contact
	service_notification_period	" . $notificationprofile->notification_period . "
	host_notification_period	" . $notificationprofile->notification_period . "
	notification_level_start		" . $notificationprofile->notification_level . "
";
            print OUTFILE "	notification_level_stop		"
              . $notificationprofile->notification_level_stop . "\n"
              if $notificationprofile->notification_level_stop > 0;

            if (@contactgroups) {
                print OUTFILE "	contactgroups	"
                  . join( ",", @contactgroups ) . "\n";
            }

            my $contact_variables;
            my $required_variables = {};

            if ( $contact->has_access("NOTIFYSOME") ) {

                $contact_variables = $contact->variables;

                NOTIFICATIONMETHOD:
                foreach my $notificationmethod (
                    $notificationprofile->notificationmethods(
                        { active => 1 }
                    )
                  )
                {
                    my @missing_list;
                    if ( $notificationmethod->command
                        =~ /^opsview_notification/ )
                    {
                        push @missing_list, "Ignoring notification method '"
                          . $notificationmethod->name . "'";
                    }
                    else {
                        foreach my $required_variable (
                            $notificationmethod->required_variables_list )
                        {
                            if (
                                !exists $contact_variables->{$required_variable}
                              )
                            {
                                push @missing_list,
                                  "Missing required variable $required_variable for contact "
                                  . $contact->name
                                  . " for notification method "
                                  . $notificationmethod->name
                                  . " - ignoring this notification";
                            }
                        }
                    }
                    if (@missing_list) {
                        warn( join( "; ", @missing_list ) );
                        next NOTIFICATIONMETHOD;
                    }

                    # Check if should be added based on "notify on master" or "notify on slave" logic in a distributed setup
                    my $add = 1;

                    if ($add) {
                        push @host_notification_commands,
                          "notify-by-" . $notificationmethod->nagios_name;
                        push @service_notification_commands,
                          "notify-by-" . $notificationmethod->nagios_name;
                        map { $required_variables->{$_}++ }
                          $notificationmethod->required_variables_list;
                    }
                }

                # Because of object inheritance, if host_notification_commands is not set,
                # will inherit host-notify-by-email - needed to stop nagios complaining at config validation time.
                # However, this means the config could say to notify using this dummy email
                # We override the notification options and set to "n" if no notification commands set. This will
                # definitely stop notifications
                if (@host_notification_commands) {
                    print_contact_variables( $contact_variables,
                        $required_variables );
                    print OUTFILE "	host_notification_commands	"
                      . join( ",", @host_notification_commands ) . "\n";
                    print OUTFILE "	host_notification_options	"
                      . $notificationprofile->host_notification_options . "\n";
                }
                else {
                    print OUTFILE "	host_notification_options	n\n";
                }

                if (@service_notification_commands) {
                    print OUTFILE "	service_notification_commands	"
                      . join( ",", @service_notification_commands ) . "\n";
                    print OUTFILE "	service_notification_options	"
                      . $notificationprofile->service_notification_options
                      . "\n";
                }
                else {
                    print OUTFILE "	service_notification_options	n\n";
                }
                $np++;
            }

            unless ( $contact->has_access("ACTIONALL")
                || $contact->has_access("ACTIONSOME") )
            {
                print OUTFILE "	can_submit_commands	0\n";
            }

            print OUTFILE "}\n\n";
            $c++;

            $profile_number++;
        }
    }
    close OUTFILE;
    plog "$c contacts ($np profiles) written to contacts.cfg";

    if ( Opsview::Config->authentication eq "htpasswd" ) {
        open OUTFILE, ">$configfilepath/htpasswd.users"
          or die "Can't open file $configfilepath/htpasswd.users: $!";
        open ADMIN, ">$configfilepath/htpasswd.admin"
          or die "Can't open file $configfilepath/htpasswd.admin: $!";
        foreach my $contact (@used_contacts) {
            next unless $contact->encrypted_password;
            next
              unless $contact->has_access(
                "VIEWSOME",   "VIEWALL", "NOTIFYSOME", "ACTIONALL",
                "ACTIONSOME", "ADMINACCESS"
              );
            print OUTFILE $contact->username, ":", $contact->encrypted_password,
              $/;
            next unless $contact->has_access( "ADMINACCESS" );
            print ADMIN $contact->username, ":", $contact->encrypted_password,
              $/;
        }
        close OUTFILE;
        close ADMIN;
        chmod 0640, "$configfilepath/htpasswd.users",
          "$configfilepath/htpasswd.admin"
          or die "Can't amend permissions for htpasswd files: $!";
        chown -1, $nagcmd_gid, "$configfilepath/htpasswd.users",
          "$configfilepath/htpasswd.admin"
          or die "Can't amend group ownership for htpasswd files: $!";
        plog "$c contacts written to htpasswd.users";
    }
}

# hosts.dat is a slave file to resolve a host's name to its ip
# Used primarily for NMIS' clustering
sub write_host_dat {
    my $list = shift;
    open OUTFILE, "> $configfilepath/hosts.dat"
      or die "Cannot open hosts.dat: $!";
    foreach my $h (@$list) {
        print OUTFILE join( "\t",
            $h->name,
            $h->ip,
            $host_to_primarynode->{ $h->id }->name,
            $host_to_secondarynode->{ $h->id }
              && $host_to_secondarynode->{ $h->id }->name ),
          "\n";
    }
    close OUTFILE;
}

################################################################
# Writes NMIS' nodes.csv file
################################################################

sub write_nmis_nodecsv {
    my ( $nodecsv_file, $monitoring_node ) = @_;
    my @list;
    foreach my $host ( $monitoringserver->monitors ) {
        if ( $host->use_nmis && $host->enable_snmp ) {
            next if ( $host->snmp_community eq "" );
            my $nmis_active = "true";
            my $role        = "core";
            $role = "access" if ( $host->children->count == 0 );
            push @list,
              join( "\t",
                $nmis_active,          "false",
                "false",               "true",
                $host->snmp_community, "N/A",
                $host->nmis_node_type, $host->hostgroup->name,
                "wan",                 $host->ip,
                "false",               $role,
                "true",                "n/a",
                $host->snmp_port )
              . "\n";
        }
    }
    open NODEFILE, ">$nodecsv_file" or die "Can't write file $nodecsv_file: $!";
    if ( @list || $monitoringserver->is_master ) {

        # Must be non-empty on master
        print NODEFILE <<"EOF";
active	calls	cbqos	collect	community	depend	devicetype	group	net	node	rancid	role	runupdate	services	snmpport
EOF
    }
    if (@list) {
        print NODEFILE @list;
    }
    close NODEFILE;
}

################################################################
# Writes contactgroups.cfg
################################################################

sub write_contactgroupscfg {
    my $c = 0;

    open OUTFILE, ">$configfilepath/contactgroups.cfg"
      or die "Can't open file $configfilepath/contactgroups.cfg: $!";

    print OUTFILE "define contactgroup {
	contactgroup_name empty
	alias empty
}

";

    # Only create contactgroups that have been already found
    my @contactgroups = sort keys %contactgroups;
    foreach my $cg (@contactgroups) {
        print OUTFILE "define contactgroup {
	contactgroup_name	$cg
	alias			$cg
}
";
        $c++;
    }

    close OUTFILE;
    plog "$c groups written to contactgroups.cfg";
}

sub write_cgicfg {
    my $cgi = <<"HEADER". <<'EOF';

##############################################
#
# cgi.cfg - Nagios configuration of CGIs
#
##############################################
HEADER

# MAIN CONFIGURATION FILE
# This tells the CGIs where to find your main configuration file.
# The CGIs will read the main and host config files for any other
# data they might need.

main_config_file=/usr/local/nagios/etc/nagios.cfg



# PHYSICAL HTML PATH
# This is the path where the HTML files for Nagios reside.  This
# value is used to locate the logo images needed by the statusmap
# and statuswrl CGIs.

physical_html_path=/usr/local/nagios/share



# URL HTML PATH
# This is the path portion of the URL that corresponds to the
# physical location of the Nagios HTML files (as defined above).
# This value is used by the CGIs to locate the online documentation
# and graphics.  If you access the Nagios pages with an URL like
# http://www.myhost.com/nagios, this value should be '/nagios'
# (without the quotes).
# NOTE: This value is generated by Opsview

url_html_path=%URL_HTML_PATH%



# CONTEXT-SENSITIVE HELP
# This option determines whether or not a context-sensitive
# help icon will be displayed for most of the CGIs.
# Values: 0 = disables context-sensitive help
#         1 = enables context-sensitive help

show_context_help=0



# PENDING STATES OPTION
# This option determines what states should be displayed in the web
# interface for hosts/services that have not yet been checked.
# Values: 0 = leave hosts/services that have not been check yet in their original state
#         1 = mark hosts/services that have not been checked yet as PENDING

use_pending_states=0




# AUTHENTICATION USAGE
# This option controls whether or not the CGIs will use any
# authentication when displaying host and service information, as
# well as committing commands to Nagios for processing.
#
# Read the HTML documentation to learn how the authorization works!
#
# NOTE: It is a really *bad* idea to disable authorization, unless
# you plan on removing the command CGI (cmd.cgi)!  Failure to do
# so will leave you wide open to kiddies messing with Nagios and
# possibly hitting you with a denial of service attack by filling up
# your drive by continuously writing to your command file!
#
# Setting this value to 0 will cause the CGIs to *not* use
# authentication (bad idea), while any other value will make them
# use the authentication functions (the default).

use_authentication=1



# DEFAULT USER
# Setting this variable will define a default user name that can
# access pages without authentication.  This allows people within a
# secure domain (i.e., behind a firewall) to see the current status
# without authenticating.  You may want to use this to avoid basic
# authentication if you are not using a secure server since basic
# authentication transmits passwords in the clear.
#
# Important:  Do not define a default username unless you are
# running a secure web server and are sure that everyone who has
# access to the CGIs has been authenticated in some manner!  If you
# define this variable, anyone who has not authenticated to the web
# server will inherit all rights you assign to this user!

#default_user_name=guest



# SYSTEM/PROCESS INFORMATION ACCESS
# This option is a comma-delimited list of all usernames that
# have access to viewing the Nagios process information as
# provided by the Extended Information CGI (extinfo.cgi).  By
# default, *no one* has access to this unless you choose to
# not use authorization.  You may use an asterisk (*) to
# authorize any user who has authenticated to the web server.

authorized_for_system_information=%ADMINS%



# CONFIGURATION INFORMATION ACCESS
# This option is a comma-delimited list of all usernames that
# can view ALL configuration information (hosts, commands, etc).
# By default, users can only view configuration information
# for the hosts and services they are contacts for. You may use
# an asterisk (*) to authorize any user who has authenticated
# to the web server.

authorized_for_configuration_information=%ADMINS%



# SYSTEM/PROCESS COMMAND ACCESS
# This option is a comma-delimited list of all usernames that
# can issue shutdown and restart commands to Nagios via the
# command CGI (cmd.cgi).  Users in this list can also change
# the program mode to active or standby. By default, *no one*
# has access to this unless you choose to not use authorization.
# You may use an asterisk (*) to authorize any user who has
# authenticated to the web server.

authorized_for_system_commands=%ADMINS%



# GLOBAL HOST/SERVICE VIEW ACCESS
# These two options are comma-delimited lists of all usernames that
# can view information for all hosts and services that are being
# monitored.  By default, users can only view information
# for hosts or services that they are contacts for (unless you
# you choose to not use authorization). You may use an asterisk (*)
# to authorize any user who has authenticated to the web server.


authorized_for_all_services=%VIEW_ALL%
authorized_for_all_hosts=%VIEW_ALL%



# GLOBAL HOST/SERVICE COMMAND ACCESS
# These two options are comma-delimited lists of all usernames that
# can issue host or service related commands via the command
# CGI (cmd.cgi) for all hosts and services that are being monitored.
# By default, users can only issue commands for hosts or services
# that they are contacts for (unless you you choose to not use
# authorization).  You may use an asterisk (*) to authorize any
# user who has authenticated to the web server.

authorized_for_all_service_commands=%CHANGE_ALL%
authorized_for_all_host_commands=%CHANGE_ALL%




# STATUSMAP BACKGROUND IMAGE
# This option allows you to specify an image to be used as a
# background in the statusmap CGI.  It is assumed that the image
# resides in the HTML images path (i.e. /usr/local/nagios/share/images).
# This path is automatically determined by appending "/images"
# to the path specified by the 'physical_html_path' directive.
# Note:  The image file may be in GIF, PNG, JPEG, or GD2 format.
# However, I recommend that you convert your image to GD2 format
# (uncompressed), as this will cause less CPU load when the CGI
# generates the image.

#statusmap_background_image=smbackground.gd2



# DEFAULT STATUSMAP LAYOUT METHOD
# This option allows you to specify the default layout method
# the statusmap CGI should use for drawing hosts.  If you do
# not use this option, the default is to use user-defined
# coordinates.  Valid options are as follows:
#	0 = User-defined coordinates
#	1 = Depth layers
#       2 = Collapsed tree
#       3 = Balanced tree
#       4 = Circular
#       5 = Circular (Marked Up)

default_statusmap_layout=%DEFAULT_STATUSMAP_LAYOUT%



# DEFAULT STATUSWRL LAYOUT METHOD
# This option allows you to specify the default layout method
# the statuswrl (VRML) CGI should use for drawing hosts.  If you
# do not use this option, the default is to use user-defined
# coordinates.  Valid options are as follows:
#	0 = User-defined coordinates
#       2 = Collapsed tree
#       3 = Balanced tree
#       4 = Circular

default_statuswrl_layout=%DEFAULT_STATUSWRL_LAYOUT%



# STATUSWRL INCLUDE
# This option allows you to include your own objects in the
# generated VRML world.  It is assumed that the file
# resides in the HTML path (i.e. /usr/local/nagios/share).

#statuswrl_include=myworld.wrl



# PING SYNTAX
# This option determines what syntax should be used when
# attempting to ping a host from the WAP interface (using
# the statuswml CGI.  You must include the full path to
# the ping binary, along with all required options.  The
# $HOSTADDRESS$ macro is substituted with the address of
# the host before the command is executed.
# Please note that the syntax for the ping binary is
# notorious for being different on virtually ever *NIX
# OS and distribution, so you may have to tweak this to
# work on your system.

ping_syntax=/bin/ping -n -U -c 5 $HOSTADDRESS$



# REFRESH RATE
# This option allows you to specify the refresh rate in seconds
# of various CGIs (status, statusmap, extinfo, and outages).

refresh_rate=%REFRESH_RATE%



# ESCAPE HTML TAGS
# This option determines whether HTML tags in host and service
# status output is escaped in the web interface.  If enabled,
# your plugin output will not be able to contain clickable links.

escape_html_tags=1




# SOUND OPTIONS
# These options allow you to specify an optional audio file
# that should be played in your browser window when there are
# problems on the network.  The audio files are used only in
# the status CGI.  Only the sound for the most critical problem
# will be played.  Order of importance (higher to lower) is as
# follows: unreachable hosts, down hosts, critical services,
# warning services, and unknown services. If there are no
# visible problems, the sound file optionally specified by
# 'normal_sound' variable will be played.
#
#
# <varname>=<sound_file>
#
# Note: All audio files must be placed in the /media subdirectory
# under the HTML path (i.e. /usr/local/nagios/share/media/).

#host_unreachable_sound=hostdown.wav
#host_down_sound=hostdown.wav
#service_critical_sound=critical.wav
#service_warning_sound=warning.wav
#service_unknown_sound=warning.wav
#normal_sound=noproblem.wav



# URL TARGET FRAMES
# These options determine the target frames in which notes and
# action URLs will open.

action_url_target=_blank
notes_url_target=_blank




# LOCK AUTHOR NAMES OPTION
# This option determines whether users can change the author name
# when submitting comments, scheduling downtime.  If disabled, the
# author names will be locked into their contact name, as defined in Nagios.
# Values: 0 = allow editing author names
#         1 = lock author names (disallow editing)

lock_author_names=1

EOF
    my @viewall =
      map { $_->username }
      ( $schema->resultset("Contacts")->all_with_access("VIEWALL") );
    my @changeall =
      map { $_->username }
      ( $schema->resultset("Contacts")->all_with_access("ACTIONALL") );
    my @admins =
      map { $_->username }
      ( $schema->resultset("Contacts")->all_with_access("ADMINACCESS") );

    my $viewall   = join( ",", @viewall );
    my $changeall = join( ",", @changeall );
    my $admins    = join( ",", @admins );

    $cgi =~ s/%VIEW_ALL%/$viewall/g;
    $cgi =~ s/%CHANGE_ALL%/$changeall/g;
    $cgi =~ s/%ADMINS%/$admins/g;

    my $default_statusmap_layout = $system_preference->default_statusmap_layout;
    my $default_statuswrl_layout = $system_preference->default_statuswrl_layout;
    my $refresh_rate             = $system_preference->refresh_rate;

    $cgi =~ s/%DEFAULT_STATUSMAP_LAYOUT%/$default_statusmap_layout/g;
    $cgi =~ s/%DEFAULT_STATUSWRL_LAYOUT%/$default_statuswrl_layout/g;
    $cgi =~ s/%REFRESH_RATE%/$refresh_rate/g;

    my $url_html_path = $override_base_prefix || "/";
    $cgi =~ s/%URL_HTML_PATH%/$url_html_path/g;

    # Override stuff from opsview.conf
    foreach my $line ( split( "\n", Opsview::Config->overrides ) ) {
        my ( $cgi_var, $cgi_value ) = ( $line =~ /^cgi_(\w+)=(.*)$/ );
        next unless $cgi_var;
        $cgi =~ s/\n#?$cgi_var=.*\n/\n$cgi_var=$cgi_value\n/;
    }

    open OUTFILE, "> $configfilepath/cgi.cfg"
      or die "Can't open file $configfilepath/cgi.cfg: $!";
    print OUTFILE $cgi;
    close OUTFILE;
    plog "Written cgi.cfg";
}

sub write_misccommandscfg {
    open OUTFILE, "> $configfilepath/misccommands.cfg"
      or die "Can't open file $configfilepath/misccommands.cfg: $!";
    print OUTFILE <<"HEADER". <<'EOF';
################################################################################
#
# misccommands.cfg - Generated by nagconfgen.pl
#
################################################################################
HEADER

define command{
    command_name notify-none
    command_line /usr/bin/printf "No notification"
}



################################################################################
#
# PERFORMANCE DATA COMMANDS
#
################################################################################

# For nagiosgraph, master only
define command{
 command_name process-service-perfdata-nagiosgraph
 command_line /usr/local/nagios/bin/rotate_async_log perfdata.log perfdatarrd
 }
define command {
 command_name	process-host-cache-data
 command_line    /usr/local/nagios/bin/process-cache-data cache_host.log
}
define command {
 command_name	process-service-cache-data
 command_line /usr/local/nagios/bin/process-cache-data cache_service.log
}
define command {
	command_name	rotate_ndo_log
	command_line	/usr/local/nagios/bin/rotate_ndo_log
}

EOF

    foreach my $notificationmethod (
        $schema->resultset("Notificationmethods")->search( { active => 1 } ) )
    {
        if ( $notificationmethod->command =~ /^opsview_notification/ ) {
            plog( "Ignoring this notification command" );
            next;
        }
        print OUTFILE "
define command{
	command_name notify-by-" . $notificationmethod->nagios_name . "
	command_line " . $notificationmethod->command_line . "
";

        # Need to get variables, based on the notification method
        # Can ignore email and pager as these are already covered
        my @extras =
          map { $_ = "_CONTACT$_" }
          grep { !/^(EMAIL|PAGER)$/ }
          ( $notificationmethod->required_variables_list );

        foreach
          my $env ( split( ",", $nagios_envvars_for_notifications ), @extras )
        {
            print OUTFILE "env NAGIOS_$env=\$$env\$\n";
        }
        print OUTFILE "}\n";
    }

    close OUTFILE;
    plog "Written misccommands.cfg";
}

sub write_nagioscfg {
    my $nagios_cfg = <<"HEADER". <<'EOF';
##############################################################################
#
# nagios.cfg - Generated by nagconfgen.pl
#
##############################################################################
HEADER


# LOG FILE
# This is the main log file where service and host events are logged
# for historical purposes.  This should be the first option specified
# in the config file!!!

log_file=/usr/local/nagios/var/nagios.log



# OBJECT CONFIGURATION FILE(S)
# This is the configuration file in which you define hosts, host
# groups, contacts, contact groups, services, etc.  I guess it would
# be better called an object definition file, but for historical
# reasons it isn't.  You can split object definitions into several
# different config files by using multiple cfg_file statements here.
# Nagios will read and process all the config files you define.
# This can be very useful if you want to keep command definitions
# separate from host and contact definitions...

# Plugin commands (service and host check commands)
# Arguments are likely to change between different releases of the
# plugins, so you should use the same config file provided with the
# plugin release rather than the one provided with Nagios.
cfg_file=checkcommands.cfg
cfg_file=misccommands.cfg
cfg_file=contactgroups.cfg
cfg_file=contacts.cfg
cfg_file=hostgroups.cfg
cfg_file=hosts.cfg
cfg_file=services.cfg
cfg_file=timeperiods.cfg
%DIST_CFG%
%NODE_CFG%
cfg_dir=conf.d
cfg_dir=local.d


# OBJECT CACHE FILE
# This option determines where object definitions are cached when
# Nagios starts/restarts.  The CGIs read object definitions from
# this cache file (rather than looking at the object config files
# directly) in order to prevent inconsistencies that can occur
# when the config files are modified after Nagios starts.

object_cache_file=%OBJECT_CACHE_FILE%



# PRE-CACHED OBJECT FILE
# This options determines the location of the precached object file.
# If you run Nagios with the -p command line option, it will preprocess
# your object configuration file(s) and write the cached config to this
# file.  You can then start Nagios with the -u option to have it read
# object definitions from this precached file, rather than the standard
# object configuration files (see the cfg_file and cfg_dir options above).
# Using a precached object file can speed up the time needed to (re)start
# the Nagios process if you've got a large and/or complex configuration.
# Read the documentation section on optimizing Nagios to find our more
# about how this feature works.

precached_object_file=/usr/local/nagios/var/objects.precache



# RESOURCE FILE
# This is an optional resource file that contains $USERx$ macro
# definitions. Multiple resource files can be specified by using
# multiple resource_file definitions.  The CGIs will not attempt to
# read the contents of resource files, so information that is
# considered to be sensitive (usernames, passwords, etc) can be
# defined as macros in this file and restrictive permissions (600)
# can be placed on this file.

# Not required in opsview
#resource_file=/usr/local/nagios/etc/resource.cfg



# STATUS FILE
# This is where the current status of all monitored services and
# hosts is stored.  Its contents are read and processed by the CGIs.
# The contents of the status file are deleted every time Nagios
#  restarts.

status_file=%STATUS_DAT%



# STATUS FILE UPDATE INTERVAL
# This option determines the frequency (in seconds) that
# Nagios will periodically dump program, host, and
# service status data.

status_update_interval=10



# NAGIOS USER
# This determines the effective user that Nagios should run as.
# You can either supply a username or a UID.

nagios_user=nagios



# NAGIOS GROUP
# This determines the effective group that Nagios should run as.
# You can either supply a group name or a GID.

nagios_group=nagios



# EXTERNAL COMMAND OPTION
# This option allows you to specify whether or not Nagios should check
# for external commands (in the command file defined below).  By default
# Nagios will *not* check for external commands, just to be on the
# cautious side.  If you want to be able to use the CGI command interface
# you will have to enable this.
# Values: 0 = disable commands, 1 = enable commands

check_external_commands=1



# EXTERNAL COMMAND FILE
# This is the file that Nagios checks for external command requests.
# It is also where the command CGI will write commands that are submitted
# by users, so it must be writeable by the user that the web server
# is running as (usually 'nobody').  Permissions should be set at the
# directory level instead of on the file, as the file is deleted every
# time its contents are processed.

command_file=/usr/local/nagios/var/rw/nagios.cmd



# LOCK FILE
# This is the lockfile that Nagios will use to store its PID number
# in when it is running in daemon mode.

lock_file=/usr/local/nagios/var/nagios.lock



# TEMP FILE
# This is a temporary file that is used as scratch space when Nagios
# updates the status log, cleans the comment file, etc.  This file
# is created, used, and deleted throughout the time that Nagios is
# running.

temp_file=/usr/local/nagios/var/nagios.tmp



# TEMP PATH
# This is path where Nagios can create temp files for service and
# host check results, etc.

temp_path=/tmp



# EVENT BROKER OPTIONS
# Controls what (if any) data gets sent to the event broker.
# Values:  0      = Broker nothing
#         -1      = Broker everything
#         <other> = See documentation

# We remove timed events, log entries and system commands
# Need to keep external commands for altinity_distributed_commands, but filter at ndomod level
event_broker_options=1047517



# EVENT BROKER MODULE(S)
# This directive is used to specify an event broker module that should
# by loaded by Nagios at startup.  Use multiple directives if you want
# to load more than one module.  Arguments that should be passed to
# the module at startup are seperated from the module path by a space.
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING !!! WARNING !!! WARNING !!! WARNING !!! WARNING !!! WARNING
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Do NOT overwrite modules while they are being used by Nagios or Nagios
# will crash in a fiery display of SEGFAULT glory.  This is a bug/limitation
# either in dlopen(), the kernel, and/or the filesystem.  And maybe Nagios...
#
# The correct/safe way of updating a module is by using one of these methods:
#    1. Shutdown Nagios, replace the module file, restart Nagios
#    2. Delete the original module file, move the new module file into place, restart Nagios
#
# Example:
#
#   broker_module=<modulepath> [moduleargs]

#broker_module=/somewhere/module1.o
#broker_module=/somewhere/module2.o arg1 arg2=3 debug=0
%BROKER_MODULES%




# LOG ROTATION METHOD
# This is the log rotation method that Nagios should use to rotate
# the main log file. Values are as follows..
#	n	= None - don't rotate the log
#	h	= Hourly rotation (top of the hour)
#	d	= Daily rotation (midnight every day)
#	w	= Weekly rotation (midnight on Saturday evening)
#	m	= Monthly rotation (midnight last day of month)

log_rotation_method=d



# LOG ARCHIVE PATH
# This is the directory where archived (rotated) log files should be
# placed (assuming you've chosen to do log rotation).

log_archive_path=/usr/local/nagios/var/archives



# LOGGING OPTIONS
# If you want messages logged to the syslog facility, as well as the
# Nagios log file set this option to 1.  If not, set it to 0.

use_syslog=0



# NOTIFICATION LOGGING OPTION
# If you don't want notifications to be logged, set this value to 0.
# If notifications should be logged, set the value to 1.

log_notifications=%LOG_NOTIFICATIONS%



# SERVICE RETRY LOGGING OPTION
# If you don't want service check retries to be logged, set this value
# to 0.  If retries should be logged, set the value to 1.

log_service_retries=%LOG_SERVICE_RETRIES%



# HOST RETRY LOGGING OPTION
# If you don't want host check retries to be logged, set this value to
# 0.  If retries should be logged, set the value to 1.

log_host_retries=%LOG_HOST_RETRIES%



# EVENT HANDLER LOGGING OPTION
# If you don't want host and service event handlers to be logged, set
# this value to 0.  If event handlers should be logged, set the value
# to 1.

log_event_handlers=%LOG_EVENT_HANDLERS%



# INITIAL STATES LOGGING OPTION
# If you want Nagios to log all initial host and service states to
# the main log file (the first time the service or host is checked)
# you can enable this option by setting this value to 1.  If you
# are not using an external application that does long term state
# statistics reporting, you do not need to enable this option.  In
# this case, set the value to 0.

log_initial_states=%LOG_INITIAL_STATES%


# CURRENT STATES LOGGING OPTION
# If you don't want Nagios to log all current host and service states
# after log has been rotated to the main log file, you can disable this
# option by setting this value to 0. Default value is 1.

log_current_states=1


# EXTERNAL COMMANDS LOGGING OPTION
# If you don't want Nagios to log external commands, set this value
# to 0.  If external commands should be logged, set this value to 1.
# Note: This option does not include logging of passive service
# checks - see the option below for controlling whether or not
# passive checks are logged.

log_external_commands=%LOG_EXTERNAL_COMMANDS%



# PASSIVE CHECKS LOGGING OPTION
# If you don't want Nagios to log passive host and service checks, set
# this value to 0.  If passive checks should be logged, set
# this value to 1.

log_passive_checks=%LOG_PASSIVE_CHECKS%



# GLOBAL HOST AND SERVICE EVENT HANDLERS
# These options allow you to specify a host and service event handler
# command that is to be run for every host or service state change.
# The global event handler is executed immediately prior to the event
# handler that you have optionally specified in each host or
# service definition. The command argument is the short name of a
# command definition that you define in your host configuration file.
# Read the HTML docs for more information.

#global_host_event_handler=process-host-eventdata-mysql
#global_service_event_handler=process-service-eventdata-mysql



# SERVICE INTER-CHECK DELAY METHOD
# This is the method that Nagios should use when initially
# "spreading out" service checks when it starts monitoring.  The
# default is to use smart delay calculation, which will try to
# space all service checks out evenly to minimize CPU load.
# Using the dumb setting will cause all checks to be scheduled
# at the same time (with no delay between them)!  This is not a
# good thing for production, but is useful when testing the
# parallelization functionality.
#	n	= None - don't use any delay between checks
#	d	= Use a "dumb" delay of 1 second between checks
#	s	= Use "smart" inter-check delay calculation
#       x.xx    = Use an inter-check delay of x.xx seconds

service_inter_check_delay_method=s



# MAXIMUM SERVICE CHECK SPREAD
# This variable determines the timeframe (in minutes) from the
# program start time that an initial check of all services should
# be completed.  Default is 30 minutes.

max_service_check_spread=5



# SERVICE CHECK INTERLEAVE FACTOR
# This variable determines how service checks are interleaved.
# Interleaving the service checks allows for a more even
# distribution of service checks and reduced load on remote
# hosts.  Setting this value to 1 is equivalent to how versions
# of Nagios previous to 0.0.5 did service checks.  Set this
# value to s (smart) for automatic calculation of the interleave
# factor unless you have a specific reason to change it.
#       s       = Use "smart" interleave factor calculation
#       x       = Use an interleave factor of x, where x is a
#                 number greater than or equal to 1.

service_interleave_factor=s



# HOST INTER-CHECK DELAY METHOD
# This is the method that Nagios should use when initially
# "spreading out" host checks when it starts monitoring.  The
# default is to use smart delay calculation, which will try to
# space all host checks out evenly to minimize CPU load.
# Using the dumb setting will cause all checks to be scheduled
# at the same time (with no delay between them)!
#	n       = None - don't use any delay between checks
#	d       = Use a "dumb" delay of 1 second between checks
#	s       = Use "smart" inter-check delay calculation
#       x.xx    = Use an inter-check delay of x.xx seconds

host_inter_check_delay_method=s



# MAXIMUM HOST CHECK SPREAD
# This variable determines the timeframe (in minutes) from the
# program start time that an initial check of all hosts should
# be completed.  Default is 30 minutes.

max_host_check_spread=15



# MAXIMUM CONCURRENT SERVICE CHECKS
# This option allows you to specify the maximum number of
# service checks that can be run in parallel at any given time.
# Specifying a value of 1 for this variable essentially prevents
# any service checks from being parallelized.  A value of 0
# will not restrict the number of concurrent checks that are
# being executed.

max_concurrent_checks=50



# HOST AND SERVICE CHECK REAPER FREQUENCY
# This is the frequency (in seconds!) that Nagios will process
# the results of host and service checks.

check_result_reaper_frequency=2




# MAX CHECK RESULT REAPER TIME
# This is the max amount of time (in seconds) that  a single
# check result reaper event will be allowed to run before
# returning control back to Nagios so it can perform other
# duties.

max_check_result_reaper_time=30




# CHECK RESULT PATH
# This is directory where Nagios stores the results of host and
# service checks that have not yet been processed.
#
# Note: Make sure that only one instance of Nagios has access
# to this directory!

check_result_path=%CHECK_RESULT_PATH%




# MAX CHECK RESULT FILE AGE
# This option determines the maximum age (in seconds) which check
# result files are considered to be valid.  Files older than this
# threshold will be mercilessly deleted without further processing.

max_check_result_file_age=3600




# CACHED HOST CHECK HORIZON
# This option determines the maximum amount of time (in seconds)
# that the state of a previous host check is considered current.
# Cached host states (from host checks that were performed more
# recently that the timeframe specified by this value) can immensely
# improve performance in regards to the host check logic.
# Too high of a value for this option may result in inaccurate host
# states being used by Nagios, while a lower value may result in a
# performance hit for host checks.  Use a value of 0 to disable host
# check caching.

cached_host_check_horizon=15



# CACHED SERVICE CHECK HORIZON
# This option determines the maximum amount of time (in seconds)
# that the state of a previous service check is considered current.
# Cached service states (from service checks that were performed more
# recently that the timeframe specified by this value) can immensely
# improve performance in regards to predictive dependency checks.
# Use a value of 0 to disable service check caching.

cached_service_check_horizon=15



# ENABLE PREDICTIVE HOST DEPENDENCY CHECKS
# This option determines whether or not Nagios will attempt to execute
# checks of hosts when it predicts that future dependency logic test
# may be needed.  These predictive checks can help ensure that your
# host dependency logic works well.
# Values:
#  0 = Disable predictive checks
#  1 = Enable predictive checks (default)

enable_predictive_host_dependency_checks=1



# ENABLE PREDICTIVE SERVICE DEPENDENCY CHECKS
# This option determines whether or not Nagios will attempt to execute
# checks of service when it predicts that future dependency logic test
# may be needed.  These predictive checks can help ensure that your
# service dependency logic works well.
# Values:
#  0 = Disable predictive checks
#  1 = Enable predictive checks (default)

enable_predictive_service_dependency_checks=1



# SOFT STATE DEPENDENCIES
# This option determines whether or not Nagios will use soft state
# information when checking host and service dependencies. Normally
# Nagios will only use the latest hard host or service state when
# checking dependencies. If you want it to use the latest state (regardless
# of whether its a soft or hard state type), enable this option.
# Values:
#  0 = Don't use soft state dependencies (default)
#  1 = Use soft state dependencies

soft_state_dependencies=%SOFT_STATE_DEPENDENCIES%


# TIME CHANGE ADJUSTMENT THRESHOLDS
# These options determine when Nagios will react to detected changes
# in system time (either forward or backwards).

#time_change_threshold=900


# AUTO-RESCHEDULING OPTION
# This option determines whether or not Nagios will attempt to
# automatically reschedule active host and service checks to
# "smooth" them out over time.  This can help balance the load on
# the monitoring server.
# WARNING: THIS IS AN EXPERIMENTAL FEATURE - IT CAN DEGRADE
# PERFORMANCE, RATHER THAN INCREASE IT, IF USED IMPROPERLY

auto_reschedule_checks=0



# AUTO-RESCHEDULING INTERVAL
# This option determines how often (in seconds) Nagios will
# attempt to automatically reschedule checks.  This option only
# has an effect if the auto_reschedule_checks option is enabled.
# Default is 30 seconds.
# WARNING: THIS IS AN EXPERIMENTAL FEATURE - IT CAN DEGRADE
# PERFORMANCE, RATHER THAN INCREASE IT, IF USED IMPROPERLY

auto_rescheduling_interval=30




# AUTO-RESCHEDULING WINDOW
# This option determines the "window" of time (in seconds) that
# Nagios will look at when automatically rescheduling checks.
# Only host and service checks that occur in the next X seconds
# (determined by this variable) will be rescheduled. This option
# only has an effect if the auto_reschedule_checks option is
# enabled.  Default is 180 seconds (3 minutes).
# WARNING: THIS IS AN EXPERIMENTAL FEATURE - IT CAN DEGRADE
# PERFORMANCE, RATHER THAN INCREASE IT, IF USED IMPROPERLY

auto_rescheduling_window=180



# TIMEOUT VALUES
# These options control how much time Nagios will allow various
# types of commands to execute before killing them off.  Options
# are available for controlling maximum time allotted for
# service checks, host checks, event handlers, notifications, the
# ocsp command, and performance data commands.  All values are in
# seconds.

service_check_timeout=60
host_check_timeout=30
# event handlers may take longer than 10 seconds. Watch out as nagios stops new checks over this period
event_handler_timeout=60
notification_timeout=30
perfdata_timeout=12



# RETAIN STATE INFORMATION
# This setting determines whether or not Nagios will save state
# information for services and hosts before it shuts down.  Upon
# startup Nagios will reload all saved service and host state
# information before starting to monitor.  This is useful for
# maintaining long-term data on state statistics, etc, but will
# slow Nagios down a bit when it (re)starts.  Since its only
# a one-time penalty, I think its well worth the additional
# startup delay.

retain_state_information=1



# STATE RETENTION FILE
# This is the file that Nagios should use to store host and
# service state information before it shuts down.  The state
# information in this file is also read immediately prior to
# starting to monitor the network when Nagios is restarted.
# This file is used only if the preserve_state_information
# variable is set to 1.

state_retention_file=/usr/local/nagios/var/retention.dat

# Opsview patch: synchronise state information between master and slaves
# Only applicable on slaves
%SYNC_RETENTION_FILE%




# RETENTION DATA UPDATE INTERVAL
# This setting determines how often (in minutes) that Nagios
# will automatically save retention data during normal operation.
# If you set this value to 0, Nagios will not save retention
# data at regular interval, but it will still save retention
# data before shutting down or restarting.  If you have disabled
# state retention, this option has no effect.

retention_update_interval=60



# USE RETAINED PROGRAM STATE
# This setting determines whether or not Nagios will set
# program status variables based on the values saved in the
# retention file.  If you want to use retained program status
# information, set this value to 1.  If not, set this value
# to 0.

use_retained_program_state=1



# USE RETAINED SCHEDULING INFO
# This setting determines whether or not Nagios will retain
# the scheduling info (next check time) for hosts and services
# based on the values saved in the retention file.  If you
# If you want to use retained scheduling info, set this
# value to 1.  If not, set this value to 0.

use_retained_scheduling_info=1



# RETAINED ATTRIBUTE MASKS (ADVANCED FEATURE)
# The following variables are used to specify specific host and
# service attributes that should *not* be retained by Nagios during
# program restarts.
#
# The values of the masks are bitwise ANDs of values specified
# by the "MODATTR_" definitions found in include/common.h.
# For example, if you do not want the current enabled/disabled state
# of flap detection and event handlers for hosts to be retained, you
# would use a value of 24 for the host attribute mask...
# MODATTR_EVENT_HANDLER_ENABLED (8) + MODATTR_FLAP_DETECTION_ENABLED (16) = 24

# This mask determines what host attributes are not retained
# Opsview: set to 15 so that notifications, active checks, passive checks and event handling comes from config file
retained_host_attribute_mask=15

# This mask determines what service attributes are not retained
# Opsview: see host setting
retained_service_attribute_mask=15

# These two masks determine what process attributes are not retained.
# There are two masks, because some process attributes have host and service
# options.  For example, you can disable active host checks, but leave active
# service checks enabled.
retained_process_host_attribute_mask=0
retained_process_service_attribute_mask=0

# These two masks determine what contact attributes are not retained.
# There are two masks, because some contact attributes have host and
# service options.  For example, you can disable host notifications for
# a contact, but leave service notifications enabled for them.
retained_contact_host_attribute_mask=0
retained_contact_service_attribute_mask=0



# INTERVAL LENGTH
# This is the seconds per unit interval as used in the
# host/contact/service configuration files.  Setting this to 60 means
# that each interval is one minute long (60 seconds).  Other settings
# have not been tested much, so your mileage is likely to vary...

interval_length=%INTERVAL_LENGTH%


# CHECK FOR UPDATES
# This option determines whether Nagios will automatically check to
# see if new updates (releases) are available.  It is recommend that you
# enable this option to ensure that you stay on top of the latest critical
# patches to Nagios.  Nagios is critical to you - make sure you keep it in
# good shape.  Nagios will check once a day for new updates. Data collected
# by Nagios Enterprises from the update check is processed in accordance
# with our privacy policy - see http://api.nagios.org for details.

check_for_updates=0



# BARE UPDATE CHECK
# This option deterines what data Nagios will send to api.nagios.org when
# it checks for updates.  By default, Nagios will send information on the
# current version of Nagios you have installed, as well as an indicator as
# to whether this was a new installation or not.  Nagios Enterprises uses
# this data to determine the number of users running specific version of
# Nagios.  Enable this option if you do not want this information to be sent.

bare_update_check=0


# AGGRESSIVE HOST CHECKING OPTION
# If you don't want to turn on aggressive host checking features, set
# this value to 0 (the default).  Otherwise set this value to 1 to
# enable the aggressive check option.  Read the docs for more info
# on what aggressive host check is or check out the source code in
# base/checks.c

use_aggressive_host_checking=0



# SERVICE CHECK EXECUTION OPTION
# This determines whether or not Nagios will actively execute
# service checks when it initially starts.  If this option is
# disabled, checks are not actively made, but Nagios can still
# receive and process passive check results that come in.  Unless
# you're implementing redundant hosts or have a special need for
# disabling the execution of service checks, leave this enabled!
# Values: 1 = enable checks, 0 = disable checks

execute_service_checks=1



# PASSIVE SERVICE CHECK ACCEPTANCE OPTION
# This determines whether or not Nagios will accept passive
# service checks results when it initially (re)starts.
# Values: 1 = accept passive checks, 0 = reject passive checks

accept_passive_service_checks=1



# HOST CHECK EXECUTION OPTION
# This determines whether or not Nagios will actively execute
# host checks when it initially starts.  If this option is
# disabled, checks are not actively made, but Nagios can still
# receive and process passive check results that come in.  Unless
# you're implementing redundant hosts or have a special need for
# disabling the execution of host checks, leave this enabled!
# Values: 1 = enable checks, 0 = disable checks

execute_host_checks=1



# PASSIVE HOST CHECK ACCEPTANCE OPTION
# This determines whether or not Nagios will accept passive
# host checks results when it initially (re)starts.
# Values: 1 = accept passive checks, 0 = reject passive checks

accept_passive_host_checks=1



# NOTIFICATIONS OPTION
# This determines whether or not Nagios will sent out any host or
# service notifications when it is initially (re)started.
# Values: 1 = enable notifications, 0 = disable notifications

enable_notifications=%NOTIFICATIONS%



# EVENT HANDLER USE OPTION
# This determines whether or not Nagios will run any host or
# service event handlers when it is initially (re)started.  Unless
# you're implementing redundant hosts, leave this option enabled.
# Values: 1 = enable event handlers, 0 = disable event handlers

enable_event_handlers=1



# PROCESS PERFORMANCE DATA OPTION
# This determines whether or not Nagios will process performance
# data returned from service and host checks.  If this option is
# enabled, host performance data will be processed using the
# host_perfdata_command (defined below) and service performance
# data will be processed using the service_perfdata_command (also
# defined below).  Read the HTML docs for more information on
# performance data.
# Values: 1 = process performance data, 0 = do not process performance data

process_performance_data=%PROCESS_PERFORMANCE_DATA%



# HOST AND SERVICE PERFORMANCE DATA PROCESSING COMMANDS
# These commands are run after every host and service check is
# performed.  These commands are executed only if the
# enable_performance_data option (above) is set to 1.  The command
# argument is the short name of a command definition that you
# define in your host configuration file.  Read the HTML docs for
# more information on performance data.

#host_perfdata_command=process-host-perfdata-mysql
#service_perfdata_command=process-service-perfdata-mysql



# HOST AND SERVICE PERFORMANCE DATA FILES
# These files are used to store host and service performance data.
# Performance data is only written to these files if the
# enable_performance_data option (above) is set to 1.

host_perfdata_file=%PROCESS_PERFORMANCE_HST_LOG%
service_perfdata_file=%PROCESS_PERFORMANCE_SVC_LOG%



# HOST AND SERVICE PERFORMANCE DATA FILE TEMPLATES
# These options determine what data is written (and how) to the
# performance data files.  The templates may contain macros, special
# characters (\t for tab, \r for carriage return, \n for newline)
# and plain text.  A newline is automatically added after each write
# to the performance data file.  Some examples of what you can do are
# shown below.

host_perfdata_file_template=%PROCESS_PERFORMANCE_HST_TEMPLATE%
service_perfdata_file_template=%PROCESS_PERFORMANCE_SVC_TEMPLATE%



# HOST AND SERVICE PERFORMANCE DATA FILE MODES
# This option determines whether or not the host and service
# performance data files are opened in write ("w") or append ("a")
# mode. If you want to use named pipes, you should use the special
# pipe ("p") mode which avoid blocking at startup, otherwise you will
# likely want the defult append ("a") mode.

# Opsview Nagios 2.9+ fixed a bug re: opening in wrong mode. "w" means open file,
# but then close when the service_perfdata_file_processing_command is run.
# This should be an "a", but insert.pl does not null the file after processing.
# We leave Nagios to do it
# In distributed setups, we leave process-cache to truncate, so use "a" here
host_perfdata_file_mode=%PROCESS_PERFORMANCE_HST_MODE%
service_perfdata_file_mode=%PROCESS_PERFORMANCE_SVC_MODE%



# HOST AND SERVICE PERFORMANCE DATA FILE PROCESSING INTERVAL
# These options determine how often (in seconds) the host and service
# performance data files are processed using the commands defined
# below.  A value of 0 indicates the files should not be periodically
# processed.

host_perfdata_file_processing_interval=%PROCESS_PERFORMANCE_HST_INTERVAL%
service_perfdata_file_processing_interval=%PROCESS_PERFORMANCE_SVC_INTERVAL%



# HOST AND SERVICE PERFORMANCE DATA FILE PROCESSING COMMANDS
# These commands are used to periodically process the host and
# service performance data files.  The interval at which the
# processing occurs is determined by the options above.

host_perfdata_file_processing_command=%PROCESS_PERFORMANCE_HST_COMMAND%
service_perfdata_file_processing_command=%PROCESS_PERFORMANCE_SVC_COMMAND%



# OBSESS OVER SERVICE CHECKS OPTION
# OBSESS OVER HOST CHECKS OPTION
obsess_over_services=%OBSESS%
obsess_over_hosts=%OBSESS%
# OBSESSIVE COMPULSIVE SERVICE PROCESSOR COMMAND
# OBSESS OVER HOST CHECKS OPTION
# Not used in Opsview
#ocsp_command=
#ochp_command=



# TRANSLATE PASSIVE HOST CHECKS OPTION
# This determines whether or not Nagios will translate
# DOWN/UNREACHABLE passive host check results into their proper
# state for this instance of Nagios.  This option is useful
# if you have distributed or failover monitoring setup.  In
# these cases your other Nagios servers probably have a different
# "view" of the network, with regards to the parent/child relationship
# of hosts.  If a distributed monitoring server thinks a host
# is DOWN, it may actually be UNREACHABLE from the point of
# this Nagios instance.  Enabling this option will tell Nagios
# to translate any DOWN or UNREACHABLE host states it receives
# passively into the correct state from the view of this server.
# Values: 1 = perform translation, 0 = do not translate (default)

translate_passive_host_checks=0



# PASSIVE HOST CHECKS ARE SOFT OPTION
# This determines whether or not Nagios will treat passive host
# checks as being HARD or SOFT.  By default, a passive host check
# result will put a host into a HARD state type.  This can be changed
# by enabling this option.
# Values: 0 = passive checks are HARD, 1 = passive checks are SOFT

passive_host_checks_are_soft=1



# ORPHANED HOST/SERVICE CHECK OPTIONS
# These options determine whether or not Nagios will periodically
# check for orphaned host service checks.  Since service checks are
# not rescheduled until the results of their previous execution
# instance are processed, there exists a possibility that some
# checks may never get rescheduled.  A similar situation exists for
# host checks, although the exact scheduling details differ a bit
# from service checks.  Orphaned checks seem to be a rare
# problem and should not happen under normal circumstances.
# If you have problems with service checks never getting
# rescheduled, make sure you have orphaned service checks enabled.
# Values: 1 = enable checks, 0 = disable checks

check_for_orphaned_services=1
check_for_orphaned_hosts=1



# SERVICE FRESHNESS CHECK OPTION
# This option determines whether or not Nagios will periodically
# check the "freshness" of service results.  Enabling this option
# is useful for ensuring passive checks are received in a timely
# manner.
# Values: 1 = enabled freshness checking, 0 = disable freshness checking

check_service_freshness=1



# SERVICE FRESHNESS CHECK INTERVAL
# This setting determines how often (in seconds) Nagios will
# check the "freshness" of service check results.  If you have
# disabled service freshness checking, this option has no effect.

service_freshness_check_interval=60


# SERVICE CHECK TIMEOUT STATE
# This setting determines the state Nagios will report when a
# service check times out - that is does not respond within
# service_check_timeout seconds.  This can be useful if a
# machine is running at too high a load and you do not want
# to consider a failed service check to be critical (the default).
# Valid settings are:
# c - Critical (default)
# u - Unknown
# w - Warning
# o - OK

service_check_timeout_state=c


# HOST FRESHNESS CHECK OPTION
# This option determines whether or not Nagios will periodically
# check the "freshness" of host results.  Enabling this option
# is useful for ensuring passive checks are received in a timely
# manner.
# Values: 1 = enabled freshness checking, 0 = disable freshness checking

check_host_freshness=0



# HOST FRESHNESS CHECK INTERVAL
# This setting determines how often (in seconds) Nagios will
# check the "freshness" of host check results.  If you have
# disabled host freshness checking, this option has no effect.

host_freshness_check_interval=60




# ADDITIONAL FRESHNESS THRESHOLD LATENCY
# This setting determines the number of seconds that Nagios
# will add to any host and service freshness thresholds that
# it calculates (those not explicitly specified by the user).

additional_freshness_latency=%ADDITIONAL_FRESHNESS_LATENCY%




# FLAP DETECTION OPTION
# This option determines whether or not Nagios will try
# and detect hosts and services that are "flapping".
# Flapping occurs when a host or service changes between
# states too frequently.  When Nagios detects that a
# host or service is flapping, it will temporarily suppress
# notifications for that host/service until it stops
# flapping.  Flap detection is very experimental, so read
# the HTML documentation before enabling this feature!
# Values: 1 = enable flap detection
#         0 = disable flap detection (default)

enable_flap_detection=1



# FLAP DETECTION THRESHOLDS FOR HOSTS AND SERVICES
# Read the HTML documentation on flap detection for
# an explanation of what this option does.  This option
# has no effect if flap detection is disabled.
# Opsview: Set to default Nagios values, and allow overrides
low_service_flap_threshold=20.0
high_service_flap_threshold=30.0
low_host_flap_threshold=20.0
high_host_flap_threshold=30.0



# DATE FORMAT OPTION
# This option determines how short dates are displayed. Valid options
# include:
#	us		(MM-DD-YYYY HH:MM:SS)
#	euro    	(DD-MM-YYYY HH:MM:SS)
#	iso8601		(YYYY-MM-DD HH:MM:SS)
#	strict-iso8601	(YYYY-MM-DDTHH:MM:SS)
#

date_format=%DATE_FORMAT%




# TIMEZONE OFFSET
# This option is used to override the default timezone that this
# instance of Nagios runs in.  If not specified, Nagios will use
# the system configured timezone.
#
# NOTE: In order to display the correct timezone in the CGIs, you
# will also need to alter the Apache directives for the CGI path
# to include your timezone.  Example:
#
#   <Directory "/usr/local/nagios/sbin/">
#      SetEnv TZ "Australia/Brisbane"
#      ...
#   </Directory>

#use_timezone=US/Mountain
#use_timezone=Australia/Brisbane




# ILLEGAL OBJECT NAME CHARACTERS
# This option allows you to specify illegal characters that cannot
# be used in host names, service descriptions, or names of other
# object types.

illegal_object_name_chars=%ILLEGAL_OBJECT_NAME_CHARS%



# ILLEGAL MACRO OUTPUT CHARACTERS
# This option allows you to specify illegal characters that are
# stripped from macros before being used in notifications, event
# handlers, etc.  This DOES NOT affect macros used in service or
# host check commands.
# The following macros are stripped of the characters you specify:
#	$HOSTOUTPUT$
#	$HOSTPERFDATA$
#	$HOSTACKAUTHOR$
#	$HOSTACKCOMMENT$
#	$SERVICEOUTPUT$
#	$SERVICEPERFDATA$
#	$SERVICEACKAUTHOR$
#	$SERVICEACKCOMMENT$

illegal_macro_output_chars=`~$&|"<>



# REGULAR EXPRESSION MATCHING
# This option controls whether or not regular expression matching
# takes place in the object config files.  Regular expression
# matching is used to match host, hostgroup, service, and service
# group names/descriptions in some fields of various object types.
# Values: 1 = enable regexp matching, 0 = disable regexp matching

use_regexp_matching=0



# "TRUE" REGULAR EXPRESSION MATCHING
# This option controls whether or not "true" regular expression
# matching takes place in the object config files.  This option
# only has an effect if regular expression matching is enabled
# (see above).  If this option is DISABLED, regular expression
# matching only occurs if a string contains wildcard characters
# (* and ?).  If the option is ENABLED, regexp matching occurs
# all the time (which can be annoying).
# Values: 1 = enable true matching, 0 = disable true matching

use_true_regexp_matching=0



# ADMINISTRATOR EMAIL/PAGER ADDRESSES
# The email and pager address of a global administrator (likely you).
# Nagios never uses these values itself, but you can access them by
# using the $ADMINEMAIL$ and $ADMINPAGER$ macros in your notification
# commands.

admin_email=nagios
admin_pager=pagenagios




# DAEMON CORE DUMP OPTION
# This option determines whether or not Nagios is allowed to create
# a core dump when it runs as a daemon.  Note that it is generally
# considered bad form to allow this, but it may be useful for
# debugging purposes.  Enabling this option doesn't guarantee that
# a core file will be produced, but that's just life...
# Values: 1 - Allow core dumps
#         0 - Do not allow core dumps (default)

daemon_dumps_core=%DAEMON_DUMPS_CORE%



# LARGE INSTALLATION TWEAKS OPTION
# This option determines whether or not Nagios will take some shortcuts
# which can save on memory and CPU usage in large Nagios installations.
# Read the documentation for more information on the benefits/tradeoffs
# of enabling this option.
# Values: 1 - Enabled tweaks
#         0 - Disable tweaks (default)

use_large_installation_tweaks=%LARGE_INSTALLATION%



# ENABLE ENVIRONMENT MACROS
# This option determines whether or not Nagios will make all standard
# macros available as environment variables when host/service checks
# and system commands (event handlers, notifications, etc.) are
# executed.  Enabling this option can cause performance issues in
# large installations, as it will consume a bit more memory and (more
# importantly) consume more CPU.
# Values: 1 - Enable environment variable macros (default)
#         0 - Disable environment variable macros

enable_environment_macros=1



# CHILD PROCESS MEMORY OPTION
# This option determines whether or not Nagios will free memory in
# child processes (processed used to execute system commands and host/
# service checks).  If you specify a value here, it will override
# program defaults.
# Value: 1 - Free memory in child processes
#        0 - Do not free memory in child processes

#free_child_process_memory=1



# CHILD PROCESS FORKING BEHAVIOR
# This option determines how Nagios will fork child processes
# (used to execute system commands and host/service checks).  Normally
# child processes are fork()ed twice, which provides a very high level
# of isolation from problems.  Fork()ing once is probably enough and will
# save a great deal on CPU usage (in large installs), so you might
# want to consider using this.  If you specify a value here, it will
# program defaults.
# Value: 1 - Child processes fork() twice
#        0 - Child processes fork() just once

#child_processes_fork_twice=1



# DEBUG LEVEL
# This option determines how much (if any) debugging information will
# be written to the debug file.  OR values together to log multiple
# types of information.
# Values:
#          -1 = Everything
#          0 = Nothing
#          1 = Functions
#          2 = Configuration
#          4 = Process information
#         8 = Scheduled events
#          16 = Host/service checks
#          32 = Notifications
#          64 = Event broker
#          128 = External commands
#          256 = Commands
#          512 = Scheduled downtime
#          1024 = Comments
#          2048 = Macros

debug_level=0



# DEBUG VERBOSITY
# This option determines how verbose the debug log out will be.
# Values: 0 = Brief output
#         1 = More detailed
#         2 = Very detailed

debug_verbosity=1



# DEBUG FILE
# This option determines where Nagios should write debugging information.

debug_file=/usr/local/nagios/var/log/nagios.debug



# MAX DEBUG FILE SIZE
# This option determines the maximum size (in bytes) of the debug file.  If
# the file grows larger than this size, it will be renamed with a .old
# extension.  If a file already exists with a .old extension it will
# automatically be deleted.  This helps ensure your disk space usage doesn't
# get out of control when debugging Nagios.

max_debug_file_size=10000000


EOF

    # fix syntax coloros broken by: illegal_macro_output_chars=`

    my $log_notifications   = $system_preference->log_notifications;
    my $log_service_retries = $system_preference->log_service_retries;
    my $log_host_retries    = $system_preference->log_host_retries;
    my $log_event_handlers  = $system_preference->log_event_handlers;
    my $log_external_commands = 1; # Always set to yes
    my $log_passive_checks      = $system_preference->log_passive_checks;
    my $daemon_dumps_core       = $system_preference->daemon_dumps_core;
    my $soft_state_dependencies = $system_preference->soft_state_dependencies;
    my $date_format             = $system_preference->date_format;
    my $status_dat              = Opsview::Config->status_dat;
    my $check_result_path       = Opsview::Config->check_result_path;
    my $object_cache_file       = Opsview::Config->object_cache_file;

    # This should always be off. It only helps with Nagios CGI reports for new host/services that have just been created
    # The nightly rollover will set a CURRENT STATE for reporting purposes
    # If set to 1, will negatively impact the NDO import on a Nagios reload
    my $log_initial_states = 0;

    $nagios_cfg =~ s/%LOG_NOTIFICATIONS%/$log_notifications/g;
    $nagios_cfg =~ s/%LOG_SERVICE_RETRIES%/$log_service_retries/g;
    $nagios_cfg =~ s/%LOG_HOST_RETRIES%/$log_host_retries/g;
    $nagios_cfg =~ s/%LOG_EVENT_HANDLERS%/$log_event_handlers/g;
    $nagios_cfg =~ s/%LOG_INITIAL_STATES%/$log_initial_states/g;
    $nagios_cfg =~ s/%LOG_EXTERNAL_COMMANDS%/$log_external_commands/g;
    $nagios_cfg =~ s/%LOG_PASSIVE_CHECKS%/$log_passive_checks/g;
    $nagios_cfg =~ s/%DAEMON_DUMPS_CORE%/$daemon_dumps_core/g;
    $nagios_cfg =~ s/%SOFT_STATE_DEPENDENCIES%/$soft_state_dependencies/g;
    $nagios_cfg =~ s/%INTERVAL_LENGTH%/$nagios_interval_length/g;
    $_ = Opsview->invalid_nagios_chars;
    $nagios_cfg =~ s/%ILLEGAL_OBJECT_NAME_CHARS%/$_/g;
    $nagios_cfg
      =~ s/%ADDITIONAL_FRESHNESS_LATENCY%/$additional_freshness_latency/g;
    $nagios_cfg =~ s/%DATE_FORMAT%/$date_format/g;
    $nagios_cfg =~ s/%STATUS_DAT%/$status_dat/g;
    $nagios_cfg =~ s/%CHECK_RESULT_PATH%/$check_result_path/g;
    $nagios_cfg =~ s/%OBJECT_CACHE_FILE%/$object_cache_file/g;

    # Testing mode has large installations off. This is so that test results
    # come back in a particular order to prove exactly the same
    my $large_installation = $test ? 0 : 1;
    $nagios_cfg =~ s/%LARGE_INSTALLATION%/$large_installation/g;

    my @broker_modules = ();
    push @broker_modules,
      "broker_module=/usr/local/nagios/bin/opsview_notificationprofiles.o";
    if ( $monitoringserver->is_master ) {
        push @broker_modules,
          "broker_module=/usr/local/nagios/bin/ndomod.o config_file=/usr/local/nagios/etc/ndomod.cfg";
        push @broker_modules,
          "broker_module=/usr/local/nagios/bin/altinity_set_initial_state.o";
    }
    my $broker_modules = join( "\n", @broker_modules );
    $nagios_cfg =~ s/%BROKER_MODULES%/$broker_modules/g;

    $nagios_cfg =~ s/%OBSESS%/0/g;

    my $host_template       = "";
    my $service_template    = "";
    my $sync_retention_file = "";

    if ($test) {
        $nagios_cfg =~ s/%NOTIFICATIONS%/0/g;
    }
    if (1) {
        $nagios_cfg =~ s/%NOTIFICATIONS%/1/g;
        $nagios_cfg =~ s/%PROCESS_PERFORMANCE_DATA%/1/g;
        $nagios_cfg =~ s/^.*%PROCESS_PERFORMANCE_HST_COMMAND%.*$//mg;
        $nagios_cfg
          =~ s/%PROCESS_PERFORMANCE_SVC_COMMAND%/process-service-perfdata-nagiosgraph/g;
        $nagios_cfg =~ s/%PROCESS_PERFORMANCE_HST_MODE%/w/g;
        $nagios_cfg =~ s/%PROCESS_PERFORMANCE_SVC_MODE%/w/g;
        $nagios_cfg =~ s/%PROCESS_PERFORMANCE_HST_INTERVAL%/0/g;
        $nagios_cfg =~ s/%PROCESS_PERFORMANCE_SVC_INTERVAL%/10/g;
        $nagios_cfg =~ s/^.*%PROCESS_PERFORMANCE_HST_LOG%.*$//mg;
        $nagios_cfg
          =~ s!%PROCESS_PERFORMANCE_SVC_LOG%!/usr/local/nagios/var/perfdata.log!g;
        $nagios_cfg =~ s/%NODE_CFG%//g;
        $nagios_cfg =~ s/%DIST_CFG%/cfg_file=master.cfg/g;
        $host_template = 'empty';
        $service_template =
          '$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$';
    }

    $nagios_cfg =~ s/%PROCESS_PERFORMANCE_HST_TEMPLATE%/$host_template/mg;
    $nagios_cfg =~ s/%PROCESS_PERFORMANCE_SVC_TEMPLATE%/$service_template/mg;
    $nagios_cfg =~ s/%SYNC_RETENTION_FILE%/$sync_retention_file/g;

    # Override stuff from opsview.conf
    foreach my $line ( split( "\n", Opsview::Config->overrides ) ) {
        my ( $nagios_var, $nagios_value ) = ( $line =~ /^nagios_(\w+)=(.*)$/ );
        next unless $nagios_var;
        $nagios_cfg =~ s/\n#?$nagios_var=.*\n/\n$nagios_var=$nagios_value\n/;
    }

    open OUTFILE, "> $configfilepath/nagios.cfg"
      or die "Can't open file $configfilepath/nagios.cfg: $!";
    print OUTFILE $nagios_cfg;
    close OUTFILE;

    plog "Written nagios.cfg";
}

sub write_timeperiodscfg {
    open OUTFILE, "> $configfilepath/timeperiods.cfg"
      or die "Can't open file $configfilepath/timeperiods.cfg: $!";
    print OUTFILE <<"HEADER";
################################################################################
#
# timeperiods.cfg
#
################################################################################
HEADER

    my $tpit = $schema->resultset("Timeperiods")->search;
    while ( my $tp = $tpit->next ) {
        my $alias = $tp->alias || $tp->name; # Alias must be set

        print OUTFILE "# '" . $tp->name . "' timeperiod definition\n";
        print OUTFILE "define timeperiod{\n";
        printf OUTFILE "\t%-15s %s\n", "timeperiod_name", $tp->name;
        printf OUTFILE "\t%-15s %s\n", "alias",           $alias;

        foreach my $day (
            qw/ sunday monday tuesday wednesday thursday friday saturday /)
        {
            printf OUTFILE "\t%-15s %s\n", "$day", $tp->$day if ( $tp->$day );
        }
        print OUTFILE "\t}\n\n";
    }

    plog "Written timeperiods.cfg";
}

sub write_nscacfg {
    my $nsca = <<"HEADER". <<'EOF';
################################################################################
#
# nsca.cfg
#
################################################################################
HEADER

# PID FILE
# The name of the file in which the NSCA daemon should write it's process ID
# number.  The file is only written if the NSCA daemon is started by the root
# user as a single- or multi-process daemon.

pid_file=/usr/local/nagios/var/nsca.pid


# PORT NUMBER
# Port number we should wait for connections on.
# This must be a non-priveledged port (i.e. > 1024).

server_port=5667



# SERVER ADDRESS
# Address that nrpe has to bind to in case there are
# more as one interface and we do not want nrpe to bind
# (thus listen) on all interfaces.

server_address=%NSCA_SERVER_ADDRESS%



# NSCA USER
# This determines the effective user that the NSCA daemon should run as.
# You can either supply a username or a UID.
#
# NOTE: This option is ignored if NSCA is running under either inetd or xinetd

nsca_user=nagios



# NSCA GROUP
# This determines the effective group that the NSCA daemon should run as.
# You can either supply a group name or a GID.
#
# NOTE: This option is ignored if NSCA is running under either inetd or xinetd

nsca_group=nagios




# NSCA CHROOT
# If specified, determines a directory into which the nsca daemon
# will perform a chroot(2) operation before dropping its privileges.
# for the security conscious this can add a layer of protection in
# the event that the nagios daemon is compromised.
#
# NOTE: if you specify this option, the command file will be opened
#       relative to this directory.

#nsca_chroot=/var/run/nagios/rw



# DEBUGGING OPTION
# This option determines whether or not debugging
# messages are logged to the syslog facility.
# Values: 0 = debugging off, 1 = debugging on

debug=0



# COMMAND FILE
# This is the location of the Nagios command file that the daemon
# should write all service check results that it receives.

command_file=/usr/local/nagios/var/rw/nagios.cmd


# ALTERNATE DUMP FILE
# This is used to specify an alternate file the daemon should
# write service check results to in the event the command file
# does not exist.  It is important to note that the command file
# is implemented as a named pipe and only exists when Nagios is
# running.  You may want to modify the startup script for Nagios
# to dump the contents of this file into the command file after
# it starts Nagios.  Or you may simply choose to ignore any
# check results received while Nagios was not running...

#alternate_dump_file=/usr/local/nagios/var/rw/nsca.dump



# AGGREGATED WRITES OPTION
# This option determines whether or not the nsca daemon will
# aggregate writes to the external command file for client
# connections that contain multiple check results.  If you
# are queueing service check results on remote hosts and
# sending them to the nsca daemon in bulk, you will probably
# want to enable bulk writes, as this will be a bit more
# efficient.
# Values: 0 = do not aggregate writes, 1 = aggregate writes

aggregate_writes=1



# APPEND TO FILE OPTION
# This option determines whether or not the nsca daemon will
# will open the external command file for writing or appending.
# This option should almost *always* be set to 0!
# Values: 0 = open file for writing, 1 = open file for appending

append_to_file=0



# MAX PACKET AGE OPTION
# This option is used by the nsca daemon to determine when client
# data is too old to be valid.  Keeping this value as small as
# possible is recommended, as it helps prevent the possibility of
# "replay" attacks.  This value needs to be at least as long as
# the time it takes your clients to send their data to the server.
# Values are in seconds.  The max packet age cannot exceed 15
# minutes (900 seconds). If this variable is set to zero (0), no
# packets will be rejected based on their age.

max_packet_age=30



# DECRYPTION PASSWORD
# This is the password/passphrase that should be used to descrypt the
# incoming packets.  Note that all clients must encrypt the packets
# they send using the same password!
# IMPORTANT: You don't want all the users on this system to be able
# to read the password you specify here, so make sure to set
# restrictive permissions on this config file!

password=%PASSWORD%



# DECRYPTION METHOD
# This option determines the method by which the nsca daemon will
# decrypt the packets it receives from the clients.  The decryption
# method you choose will be a balance between security and performance,
# as strong encryption methods consume more processor resources.
# You should evaluate your security needs when choosing a decryption
# method.
#
# Note: The decryption method you specify here must match the
#       encryption method the nsca clients use (as specified in
#       the send_nsca.cfg file)!!
# Values:
#
# 	0 = None	(Do NOT use this option)
#       1 = Simple XOR  (No security, just obfuscation, but very fast)
#
#       2 = DES
#       3 = 3DES (Triple DES)
#	4 = CAST-128
#	5 = CAST-256
#	6 = xTEA
#	7 = 3WAY
#	8 = BLOWFISH
#	9 = TWOFISH
#	10 = LOKI97
#	11 = RC2
#	12 = ARCFOUR
#
#	14 = RIJNDAEL-128
#	15 = RIJNDAEL-192
#	16 = RIJNDAEL-256
#
#	19 = WAKE
#	20 = SERPENT
#
#	22 = ENIGMA (Unix crypt)
#	23 = GOST
#	24 = SAFER64
#	25 = SAFER128
#	26 = SAFER+
#

decryption_method=%ENCRYPTION_METHOD%
EOF

    my $passwd = Opsview::Config->dbpasswd;
    $nsca =~ s/%PASSWORD%/$passwd/;
    my $server_address = Opsview::Config->nsca_server_address;
    $nsca =~ s/%NSCA_SERVER_ADDRESS%/$server_address/;
    my $encryption_method = Opsview::Config->nsca_encryption_method;
    $nsca =~ s/%ENCRYPTION_METHOD%/$encryption_method/;

    open OUTFILE, "> $configfilepath/nsca.cfg"
      or die "Can't open file $configfilepath/nsca.cfg: $!";
    print OUTFILE $nsca;
    close OUTFILE;
    chmod 0600, "$configfilepath/nsca.cfg";
    plog "Written nsca.cfg";
}

sub write_nrdcfg {

    # Could possibly change the max_servers value dynamically based on number of slave nodes
    # But this would require a restart of nrd. Perhaps patch Net::Server to monitor this config
    # file and re-read when changed
    my $nrd = <<'EOF';
# NRD configuration - generated by nagconfgen
server_type PreFork
min_servers 4
min_spare_servers 1
max_spare_servers 2
max_servers 12

user nagios
group nagios
background 1
setsid 1
reverse_lookups off
host 127.0.0.1
port 5669
timeout 120

# logging
log_file Log::Log4perl
log_level 2
log4perl_conf /usr/local/nagios/etc/Log4perl.conf
log4perl_logger nrd

# access control
cidr_allow 127.0.0.0/8

encryption_method 2
serializer crypt
encrypt_type Blowfish
encrypt_key %NRD_SHARED_PASSWORD%
writer resultdir
check_result_path %CHECK_RESULT_PATH%
batch_results 1
long_check_result_filename 1
EOF

    my $nrd_shared_password = Opsview::Config->nrd_shared_password;
    $nrd =~ s/%NRD_SHARED_PASSWORD%/$nrd_shared_password/;

    my $check_result_path = Opsview::Config->check_result_path;
    $nrd =~ s/%CHECK_RESULT_PATH%/$check_result_path/g;

    open OUTFILE, "> $configfilepath/nrd.conf"
      or die "Can't open file $configfilepath/nrd.conf $!";
    print OUTFILE $nrd;
    close OUTFILE;
    chmod 0600, "$configfilepath/nrd.conf";
    plog "Written nrd.conf";

    my $send_nrd = <<'EOF';
# send_nrd configuration - generated by nagconfgen
host 127.0.0.1
serializer crypt
encrypt_type Blowfish
encrypt_key %NRD_SHARED_PASSWORD%
timeout 30
EOF

    $send_nrd =~ s/%NRD_SHARED_PASSWORD%/$nrd_shared_password/;

    open OUTFILE, "> $configfilepath/send_nrd.cfg"
      or die "Can't open file $configfilepath/send_nrd.cfg: $!";
    print OUTFILE $send_nrd;
    close OUTFILE;
    chmod 0600, "$configfilepath/send_nrd.cfg";
    plog "Written send_nrd.cfg";
}

sub write_send_nscacfg {
    my $send_nsca = <<'EOF';
################################################################################
#
# send_nsca.cfg
#
################################################################################

# ENCRYPTION PASSWORD
# This is the password/passphrase that should be used to encrypt the
# outgoing packets.  Note that the nsca daemon must use the same
# password when decrypting the packet!
# IMPORTANT: You don't want all the users on this system to be able
# to read the password you specify here, so make sure to set
# restrictive permissions on this config file!

password=%PASSWORD%



# ENCRYPTION METHOD
# This option determines the method by which the send_nsca client will
# encrypt the packets it sends to the nsca daemon.  The encryption
# method you choose will be a balance between security and performance,
# as strong encryption methods consume more processor resources.
# You should evaluate your security needs when choosing an encryption
# method.
#
# Note: The encryption method you specify here must match the
#       decryption method the nsca daemon uses (as specified in
#       the nsca.cfg file)!!
# Values:
# 	0 = None	(Do NOT use this option)
#       1 = Simple XOR  (No security, just obfuscation, but very fast)
#
#       2 = DES
#       3 = 3DES (Triple DES)
#	4 = CAST-128
#	5 = CAST-256
#	6 = xTEA
#	7 = 3WAY
#	8 = BLOWFISH
#	9 = TWOFISH
#	10 = LOKI97
#	11 = RC2
#	12 = ARCFOUR
#
#	14 = RIJNDAEL-128
#	15 = RIJNDAEL-192
#	16 = RIJNDAEL-256
#
#	19 = WAKE
#	20 = SERPENT
#
#	22 = ENIGMA (Unix crypt)
#	23 = GOST
#	24 = SAFER64
#	25 = SAFER128
#	26 = SAFER+
#

encryption_method=%ENCRYPTION_METHOD%
EOF

    my $passwd = Opsview::Config->dbpasswd;
    $send_nsca =~ s/%PASSWORD%/$passwd/;
    my $encryption_method = Opsview::Config->nsca_encryption_method;
    $send_nsca =~ s/%ENCRYPTION_METHOD%/$encryption_method/;

    open OUTFILE, "> $configfilepath/send_nsca.cfg"
      or die "Can't open file $configfilepath/send_nsca.cfg: $!";
    print OUTFILE $send_nsca;
    close OUTFILE;
    chmod 0600, "$configfilepath/send_nsca.cfg";
    plog "Written send_nsca.cfg";
}

# Some of this data is constructed from the host creation phase
sub write_notificationmethodvariables {

    my $file = shift || "$configfilepath/notificationmethodvariables.cfg";

    my $rs =
      $schema->resultset("Notificationmethods")->search( { active => 1 } );
    if ( !$monitoringserver->is_master ) {
        $rs = $rs->search( { master => 0 } );
    }

    my $variables = {};
    while ( my $it = $rs->next ) {
        if ( $it->command =~ /^opsview_notification/ ) {
            plog( "Ignoring this notification method" );
            next;
        }
        $variables->{ $it->namespace } = $it->variables_hash;
    }

    # Don't set this yet - I can see the value of a baseurl, but not a server
    # name
    # $configuration_cache_data->{preferences}->{servername} =
    #   $system_preference->opsview_server_name;

    $configuration_cache_data->{system} = { uuid => $system_preference->uuid };

    # Set indent level 1 for testing so we can see changes easily
    my $d = Data::Dumper->new(
        [ $variables, $configuration_cache_data ],
        [qw(notificationmethodvariables config)]
    );
    my $indent_level = $test ? 1 : 0;

    open my $fh, '>', $file or die "Can't open file $file: $!";
    print $fh $d->Indent($indent_level)->Dump, '1;', $/;
    close $fh;

    plog "Written notificationmethodvariables.cfg";
}

sub write_instance_cfg {

    open OUTFILE, "> $configfilepath/instance.cfg"
      or die "Can't open file instance.cfg: $!";
    print OUTFILE "# This file is generated by nagconfgen
\$archive_retention_days=" . Opsview::Config->archive_retention_days . ";
\$rrd_retention_days=" . Opsview::Config->rrd_retention_days . ";
\$override_base_prefix='$override_base_prefix';
\$nmis_maxthreads=" . Opsview::Config->nmis_maxthreads . ";
\$report_retention_days=" . Opsview::Config->report_retention_days . ";
\$nmis_retention_days=" . Opsview::Config->nmis_retention_days . ";
\$status_dat='" . Opsview::Config->status_dat . "';
\$check_result_path='" . Opsview::Config->check_result_path . "';
\$object_cache_file='" . Opsview::Config->object_cache_file . "';
1;
";
    close OUTFILE;
    chown -1, $nagcmd_gid, "$configfilepath/instance.cfg"
      or die "Can't amend group ownership on instance.cfg file: $!";
}

sub write_ndo2dbcfg {
    my $runtime_db       = Opsview::Config->runtime_db;
    my $runtime_dbuser   = Opsview::Config->runtime_dbuser;
    my $runtime_dbpasswd = Opsview::Config->runtime_dbpasswd;

    my $ndo2db = <<"EOF";
#####################################################################
# NDO2DB DAEMON CONFIG FILE
#####################################################################

# USER/GROUP PRIVILIGES
# These options determine the user/group that the daemon should run as.
# You can specify a number (uid/gid) or a name for either option.

ndo2db_user=nagios
ndo2db_group=nagios


# SOCKET TYPE
# This option determines what type of socket the daemon will create
# an accept connections from.
# Value:
#   unix = Unix domain socket (default)
#   tcp  = TCP socket

socket_type=unix
#socket_type=tcp


# SOCKET NAME
# This option determines the name and path of the UNIX domain
# socket that the daemon will create and accept connections from.
# This option is only valid if the socket type specified above
# is "unix".

socket_name=/usr/local/nagios/var/ndo.sock



# TCP PORT
# This option determines what port the daemon will listen for
# connections on.  This option is only vlaid if the socket type
# specified above is "tcp".

tcp_port=5668



# DATABASE SERVER TYPE
# This option determines what type of DB server the daemon should
# connect to.
# Values:
# 	mysql = MySQL
#       pgsql = PostgreSQL

db_servertype=mysql



# DATABASE HOST
# This option specifies what host the DB server is running on.

db_host=localhost



# DATABASE PORT
# This option specifies the port that the DB server is running on.
# Values:
# 	3306 = Default MySQL port
#	5432 = Default PostgreSQL port

db_port=3306



# DATABASE NAME
# This option specifies the name of the database that should be used.

db_name=$runtime_db



# DATABASE TABLE PREFIX
# Determines the prefix (if any) that should be prepended to table names.

#db_prefix=
db_prefix=nagios_



# DATABASE USERNAME/PASSWORD
# This is the username/password that will be used to authenticate to the DB.
# The user needs at least SELECT, INSERT, UPDATE, and DELETE privileges on
# the database.

db_user=$runtime_dbuser
db_pass=$runtime_dbpasswd



## TABLE TRIMMING OPTIONS
# Several database tables containing Nagios event data can become quite large
# over time.  Most admins will want to trim these tables and keep only a
# certain amount of data in them.  The options below are used to specify the
# age (in MINUTES) that data should be allowd to remain in various tables
# before it is deleted.  Using a value of zero (0) for any value means that
# that particular table should NOT be automatically trimmed.

# Opsview Housekeeping now done in opsview_master_housekeep
max_timedevents_age=0
max_systemcommands_age=0
max_servicechecks_age=0
max_hostchecks_age=0
max_eventhandlers_age=0
max_externalcommands_age=0



# DEBUG LEVEL
# This option determines how much (if any) debugging information will
# be written to the debug file.  OR values together to log multiple
# types of information.
# This also controls whether the "Succcessfully connected to MySQL database"
# syslog message is sent - anything other than 0 will log these messages
# Values: -1 = Everything
#          0 = Nothing
#          1 = Process info
#	   2 = SQL queries

debug_level=0



# DEBUG VERBOSITY
# This option determines how verbose the debug log out will be.
# Values: 0 = Brief output
#         1 = More detailed
#         2 = Very detailed

debug_verbosity=1



# DEBUG FILE
# This option determines where the daemon should write debugging information.

debug_file=/usr/local/nagios/var/log/ndo2db.debug



# MAX DEBUG FILE SIZE
# This option determines the maximum size (in bytes) of the debug file.  If
# the file grows larger than this size, it will be renamed with a .old
# extension.  If a file already exists with a .old extension it will
# automatically be deleted.  This helps ensure your disk space usage doesn't
# get out of control when debugging.

max_debug_file_size=1000000

EOF

    open OUTFILE, "> $configfilepath/ndo2db.cfg"
      or die "Can't open file $configfilepath/ndo2db.cfg: $!";
    print OUTFILE $ndo2db;
    close OUTFILE;
    chmod 0600, "$configfilepath/ndo2db.cfg";
    plog "Written ndo2db.cfg";
}

sub write_ndomodcfg {
    my $ndomod = <<"EOF";
#####################################################################
# NDOMOD CONFIG FILE
#####################################################################


# INSTANCE NAME
# This option identifies the "name" associated with this particular
# instance of Nagios and is used to seperate data coming from multiple
# instances.  Defaults to 'default' (without quotes).

instance_name=default



# OUTPUT TYPE
# This option determines what type of output sink the NDO NEB module
# should use for data output.  Valid options include:
#   file       = standard text file
#   tcpsocket  = TCP socket
#   unixsocket = UNIX domain socket (default)

output_type=file
#output_type=tcpsocket
#output_type=unixsocket



# OUTPUT
# This option determines the name and path of the file or UNIX domain
# socket to which output will be sent if the output type option specified
# above is "file" or "unixsocket", respectively.  If the output type
# option is "tcpsocket", this option is used to specify the IP address
# of fully qualified domain name of the host that the module should
# connect to for sending output.

output=%NDO_DAT_FILE%
#output=127.0.0.1
#output=/usr/local/nagios/var/ndo.sock



# TCP PORT
# This option determines what port the module will connect to in
# order to send output.  This option is only vlaid if the output type
# option specified above is "tcpsocket".

tcp_port=5668



# OUTPUT BUFFER
# This option determines the size of the output buffer, which will help
# prevent data from getting lost if there is a temporary disconnect from
# the data sink.  The number of items specified here is the number of
# lines (each of variable size) of output that will be buffered.

output_buffer_items=5000



# BUFFER FILE
# This option is used to specify a file which will be used to store the
# contents of buffered data which could not be sent to the NDO2DB daemon
# before Nagios shuts down.  Prior to shutting down, the NDO NEB module
# will write all buffered data to this file for later processing.  When
# Nagios (re)starts, the NDO NEB module will read the contents of this
# file and send it to the NDO2DB daemon for processing.

buffer_file=/usr/local/nagios/var/ndomod.tmp



# FILE ROTATION INTERVAL
# This option determines how often (in seconds) the output file is
# rotated by Nagios.  File rotation is handled by Nagios by executing
# the command defined by the file_rotation_command option.  This
# option has no effect if the output_type option is a socket.

file_rotation_interval=5



# FILE ROTATION COMMAND
# This option specified the command (as defined in Nagios) that is
# used to rotate the output file at the interval specified by the
# file_rotation_interval option.  This option has no effect if the
# output_type option is a socket.
#
# See the file 'misccommands.cfg' for an example command definition
# that you can use to rotate the log file.

file_rotation_command=rotate_ndo_log



# FILE ROTATION TIMEOUT
# This option specified the maximum number of seconds that the file
# rotation command should be allowed to run before being prematurely
# terminated.

file_rotation_timeout=10



# RECONNECT INTERVAL
# This option determines how often (in seconds) that the NDBXT NEB
# module will attempt to re-connect to the output file or socket if
# a connection to it is lost.

reconnect_interval=15



# RECONNECT WARNING INTERVAL
# This option determines how often (in seconds) a warning message will
# be logged to the Nagios log file if a connection to the output file
# or socket cannot be re-established.

reconnect_warning_interval=15
#reconnect_warning_interval=900



# DATA PROCESSING OPTION
# This option determines what data the NDBXT NEB module will process.
# Do not mess with this option unless you know what you're doing!!!!
# Read the source code (include/ndbxtmod.h) to determine what values
# to use here.  Values from source code should be OR'ed to get the
# value to use here.  A value of -1 will cause all data to be processed.

#data_processing_options=-1
# All except external commands. We still need it at broker level for altinity_distributed_commands
# See include/ndomod.h for how to calculate
data_processing_options=66977791



# CONFIG OUTPUT OPTION
# This option determines what types of configuration data the NDBXT
# NEB module will dump from Nagios.  Values can be OR'ed together.
# Values: 0 = Don't dump anything
#         1 = Dump original config (from config files)
#         2 = Dump config after retained information has been restored

config_output_options=1

EOF

    my $ndo_dat_file = Opsview::Config->ndo_dat_file;
    $ndomod =~ s/%NDO_DAT_FILE%/$ndo_dat_file/g;

    open OUTFILE, "> $configfilepath/ndomod.cfg"
      or die "Can't open file $configfilepath/ndomod.cfg: $!";
    print OUTFILE $ndomod;
    close OUTFILE;
    chmod 0600, "$configfilepath/ndomod.cfg";
    plog "Written ndomod.cfg";
}

sub distributed { scalar @all_monitoringservers > 1 }

sub load_snmp {
    unless ($load_snmp) {
        require SNMP;

        # Load all SNMP modules
        &SNMP::addMibDirs( "/usr/local/nagios/snmp/load" );
        &SNMP::loadModules( 'ALL' );
        $load_snmp++;
    }
}

sub create_keyword_lookup_list {

    # Get list of keywords with contacts associated
    # This was filtered by contacts with a keyword, but with the all_keywords flag, this may not be
    # possible. Just do for all
    my @keywords = $schema->resultset("Keywords")->search;

    # Get a lookup of hostname and servicename
    # This nested loop approach is best - using a full query takes about 100 times longer
    foreach my $keyword (@keywords) {

        my @hosts = map { $_->{name} } (
            $keyword->hosts(
                {},
                {
                    columns      => "name",
                    result_class => "DBIx::Class::ResultClass::HashRefInflator",
                }
            )
        );
        my @servicechecks = map { $_->{name} } (
            $keyword->servicechecks(
                {},
                {
                    columns      => "name",
                    result_class => "DBIx::Class::ResultClass::HashRefInflator"
                }
            )
        );
        push @hosts,         "*" if $keyword->all_hosts;
        push @servicechecks, "*" if $keyword->all_servicechecks;
        my $kid   = $keyword->id;
        my $kname = $keyword->name;
        foreach my $host (@hosts) {
            foreach my $sc (@servicechecks) {
                $keyword_host_service_lookup->{$host}->{services}->{$sc}
                  ->{"${kid}_${kname}"}++;
            }
        }
    }

    plog(
        "Created keyword lookup list for " . ( scalar @keywords ) . " keywords"
    );
}

sub print_contact_variables {
    my ( $contact_variables, $required_variables ) = @_;
    foreach my $var ( sort keys %$contact_variables ) {
        next unless exists $required_variables->{$var};
        my $varname = "_$var";

        # Special case as these variables already exist in Nagios stanza, so use those
        if ( $var =~ /^(EMAIL|PAGER)$/ ) {
            $varname = lc $1;
        }
        print OUTFILE "\t$varname\t" . $contact_variables->{$var} . "\n";
    }
}

sub notification_interval_warning {
    my ( $notification_interval, $check_interval ) = @_;
    ( $notification_interval == 0 || $notification_interval > $check_interval )
      ? $notification_interval
      : $check_interval;
}

my $attribute_name_cache = {};

sub get_attribute_name {
    my $aid = $_[0];
    if ( !$attribute_name_cache->{$aid} ) {
        $attribute_name_cache->{$aid} =
          $schema->resultset("Attributes")->find($aid)->name;
    }
    return $attribute_name_cache->{$aid};
}
