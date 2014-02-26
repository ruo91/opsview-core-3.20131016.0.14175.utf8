#!/usr/bin/env perl
# Tests for Opsview::ResultSet::Hosts

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use utf8;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Hosts" );

is( $rs->search( { name => "opsview1" } )->count, 0 );

$rs->synchronise( { name => "opsview1" } );

is( $rs->search( { name => "opsview1" } )->count, 1 );

eval { $rs->synchronise( { name => "opsview1" }, { create_only => 1 } ) };
like(
    $@,
    qr/execute failed: Duplicate entry 'opsview1' for key/,
    "Create fails because already exists"
);

my $host = $rs->find( { name => "opsview1" } );
is( $host->uncommitted, 1, "Check uncommitted flag set" );
is( $host->ip, "opsview1" );

$rs->synchronise(
    {
        name         => "opsview1",
        ip           => "opsview1.opsera.com",
        check_period => { name => "24x7" }
    }
);
$host = $rs->find( { name => "opsview1" } );

# Check default values
is( $host->check_period,     "24x7" );
is( $host->hostgroup->id,    9 );
is( $host->icon->name,       "LOGO - Opsview" );
is( $host->monitored_by->id, 1 );
is( $host->ip,               "opsview1.opsera.com" );

$rs->synchronise(
    {
        name                => "opsview1",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" },
        hostgroup           => { name => "middling" },
        delete              => 1
    }
);
$host = $rs->find( { name => "opsview1" } );
isa_ok( $host, "Opsview::Schema::Hosts",
    "Host exists and not deleted by errant delete attribute"
);
is( $host->check_period,        "workhours" );
is( $host->notification_period, "nonworkhours" );
is( $host->hostgroup->name,     "middling" );

$rs->synchronise(
    {
        name                => "opsview1",
        snmp_community      => "public4",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" }
    }
);
$host = $rs->find( { name => "opsview1" } );
is( $host->snmp_community, "public4" );
is( $host->hostgroup->name, "middling", "Confirm host group hasn't changed" );

my $router = $rs->synchronise( { name => "router" } );
isnt( $rs->find( { name => "router" } ), undef, "Router created" );

$rs->synchronise(
    {
        name                  => "opsview1",
        alias                 => "Opsview test install",
        check_attempts        => 3,
        check_interval        => 0,
        ip                    => "192.168.101.42",
        snmp_community        => "public44",
        check_period          => { id => 2 },
        notification_period   => { name => "nonworkhours" },
        notification_interval => 60,
        retry_check_interval  => 1,
        snmp_version          => "2c",
        icon                  => "LOGO - Debian Linux",
        notification_options  => "u,d",
        hostgroup             => [ 4, "" ],
        parents               => [ $router->id, $host->id ],
        snmpinterfaces        => [
            {
                name                => "eth1",
                indexid             => 7,
                active              => 0,
                throughput_warning  => "",
                throughput_critical => ""
            },
            {
                name                => "eth0",
                indexid             => 5,
                active              => 1,
                throughput_warning  => "",
                throughput_critical => "10%"
            },
            {
                name                => "lo",
                indexid             => 9,
                active              => 1,
                throughput_warning  => "55%",
                throughput_critical => "70%"
            },
        ],
    }
);
$host = $rs->find( { name => "opsview1" } );
is( $host->ip,                   "192.168.101.42" );
is( $host->snmp_community,       "public44" );
is( $host->snmp_version,         "2c" );
is( $host->alias,                "Opsview test install" );
is( $host->check_attempts,       3 );
is( $host->retry_check_interval, 1 );
is( $host->icon->name,           "LOGO - Debian Linux" );
is( $host->notification_options, "u,d" );
is( $host->hostgroup->id, 4, "Able to expand a single digit value" );
is( $host->parents->first->id, $router->id, "Got router" );
is( $host->parents->count,     1,           "And only one, so ignored self" );

my @snmpinterfaces = $host->snmpinterfaces;
is( scalar @snmpinterfaces, 3, "Got 3 snmp interfaces" );
my $int;
$int = $snmpinterfaces[0];
is( $int->interfacename,       "eth0", "Got name" );
is( $int->indexid,             5,      "Got indexid" );
is( $int->active,              1,      "Active" );
is( $int->throughput_warning,  "",     "No warning" );
is( $int->throughput_critical, "10%",  "No critical" );

$int = $snmpinterfaces[1];
is( $int->interfacename,       "eth1", "Got name" );
is( $int->indexid,             7,      "Got indexid" );
is( $int->active,              0,      "Active" );
is( $int->throughput_warning,  "",     "No warning" );
is( $int->throughput_critical, "",     "No critical" );

$int = $snmpinterfaces[2];
is( $int->interfacename,       "lo",  "Got name" );
is( $int->indexid,             9,     "Got indexid" );
is( $int->active,              1,     "Active" );
is( $int->throughput_warning,  "55%", "No warning" );
is( $int->throughput_critical, "70%", "No warning" );

my $child = $rs->synchronise(
    {
        name    => "childofopsview1",
        parents => [ $host->id ]
    }
);
is( $child->parents->first->name, "opsview1", "Added a child" );

is( $host->children->first->id, $child->id, "Got child" );

$router->delete;
is( $rs->find( { name => "router" } ), undef, "Router deleted" );
$host->discard_changes;
is( $host->parents->first, undef, "No parent for host now" );

$child->delete;
is( $rs->find( { name => "childofopsview1" } ), undef, "Child removed" );
##test for evenhandler validation field
eval {
    $rs->synchronise(
        {
            name                  => "opsview1",
            other_addresses       => "10.10.10.10,11.11.11.11",
            alias                 => "Opsview test install24",
            check_attempts        => 5,
            check_interval        => 20,
            ip                    => undef,
            hostgroup             => { name => "singlehost" },
            snmp_community        => "public",
            check_period          => { id => 2 },
            check_command         => { name => "slow ping" },
            notification_period   => { name => "nonworkhours" },
            notification_interval => 60,
            retry_check_interval  => 2,
            snmp_version          => "1",
            icon                  => "LOGO - Ubuntu Linux",
            notification_options  => "s,d,u,r,f",
            hosttemplates         => [
                { name => "Network - Base" },
                { id   => 3 },
                { id   => 2 },
                { name => "Network - Base" },
                { name => "Template to get removed 1st" },
                { name => "Blank" },
                { name => "Cisco Mgt" },
            ],
            servicechecks => [
                29, # = TCP/IP - to prove primary key is okay
                { id => 4 }, # = DNS
                {
                    name            => "IRC",
                    timed_exception => {
                        timeperiod => 3,
                        args       => "--timedexception"
                    },
                    event_handler => "eventscript go ! $ `` / & ^",
                },
                {
                    name            => "Kerberos",
                    timed_exception => {
                        args       => "--kerbey",
                        timeperiod => { name => "none" },
                    },
                },
                {
                    name                => "DHCP",
                    exception           => "--exception",
                    remove_servicecheck => 1
                },
                {
                    name                => "Events",
                    remove_servicecheck => 1
                },
            ],

        }
    );
};
like(
    $@,
    qr/Failed constraint on event_handler for/,
    "Checking constraints for the eventhandler"
);

# TODO: I'm not sure this test is valid. If a hostgroup does not exist, that should give an error? But it depends
# if the column allows a NULL value or not, so proper fix will require interrogation of column information
#$host = $rs->synchronise( { name => "opsview1", hostgroup => [ "", 7 ] } );
#is( $host->hostgroup->id, 9, "Host group set to undef, so therefore reverted by model to the 1st alphabetically" );

$rs->synchronise(
    {
        name                  => "opsview1",
        other_addresses       => "10.10.10.10,11.11.11.11",
        alias                 => "Opsview test install24",
        check_attempts        => 5,
        check_interval        => 20,
        ip                    => undef,
        hostgroup             => { name => "singlehost" },
        snmp_community        => "public",
        check_period          => { id => 2 },
        check_command         => { name => "slow ping" },
        notification_period   => { name => "nonworkhours" },
        notification_interval => 60,
        retry_check_interval  => 2,
        snmp_version          => "1",
        icon                  => "LOGO - Ubuntu Linux",
        notification_options  => "s,d,u,r,f",
        hosttemplates         => [
            { name => "Network - Base" },
            { id   => 3 },
            { id   => 2 },
            { name => "Network - Base" },
            { name => "Template to get removed 1st" },
            { name => "Blank" },
            { name => "Cisco Mgt" },
        ],
        servicechecks => [
            29, # = TCP/IP - to prove primary key is okay
            { id => 4 }, # = DNS
            {
                name            => "IRC",
                timed_exception => {
                    timeperiod => 3,
                    args       => "--timedexception"
                },
                event_handler => "eventscript go",
            },
            {
                name            => "Kerberos",
                timed_exception => {
                    args       => "--kerbey",
                    timeperiod => { name => "none" },
                },
            },
            {
                name                => "DHCP",
                exception           => "--exception",
                remove_servicecheck => 1
            },
            {
                name                => "Events",
                remove_servicecheck => 1
            },
        ],

        monitored_by => { name => "ClusterA" },
        parents  => [ { name => "opsview" }, { name => "opslave" } ],
        keywords => [ { name => "newone" },  { name => "cisco" }, { id => 5 } ],
        use_nmis       => 1,
        nmis_node_type => "server",
        hostattributes => [
            {
                name  => "DISK",
                value => "/u02   ",
                arg1  => "-p /u02 -c 9%",
                arg2  => "arg2",
                arg3  => "arg3",
                arg4  => "arg4"
            },
            {
                name  => "disk",
                value => "/u01",
                arg1  => "-p /u01 -c 5%",
                arg2  => "u01-arg2",
                arg3  => "u01-arg3",
                arg4  => "u01-arg4"
            },
            {
                name  => "URL",
                value => "/about",
                arg1  => "super",
                arg2  => "url arg2",
                arg3  => "url arg3",
                arg4  => "url arg4"
            },
            {
                name  => "INTERFACE",
                value => "ent1",
                arg1  => ""
            },
        ],
    }
);
$host = $rs->find( { name => "opsview1" } );
is( $host->ip,                       "opsview1" );
is( $host->snmp_community,           "public" );
is( $host->snmp_version,             "1" );
is( $host->alias,                    "Opsview test install24" );
is( $host->check_attempts,           5 );
is( $host->retry_check_interval,     2 );
is( $host->icon->name,               "LOGO - Ubuntu Linux" );
is( $host->check_command->name,      "slow ping" );
is( $host->hostgroup->name,          "singlehost" );
is( $host->notification_options,     "s,d,u,r,f" );
is( $host->monitored_by->name,       "ClusterA" );
is( $host->monitored_by->host->id,   5 );
is( $host->monitored_by->host->name, "opslave" );
is( $host->other_addresses,          "10.10.10.10,11.11.11.11" );
is( $host->use_nmis,                 1 );
is( $host->nmis_node_type,           "server" );
my @hosttemplates = $host->hosttemplates;
is( scalar @hosttemplates,   4 );
is( $hosttemplates[0]->name, "Network - Base" );
is( $hosttemplates[1]->name, "Cisco Mgt" );
is( $hosttemplates[2]->name, "Template to get removed 1st" );
is( $hosttemplates[3]->name, "Blank" );
my @scs = $host->servicechecks( {}, { order_by => "name" } );
is( scalar @scs, 6 );
my @names = map { $_->name } @scs;
is_deeply( \@names, [qw(DHCP DNS Events IRC Kerberos TCP/IP)] );

my $expected = {
    name                  => "opsview1",
    other_addresses       => "10.10.10.10,11.11.11.11",
    alias                 => "Opsview test install24",
    id                    => 25,
    check_attempts        => 5,
    check_interval        => 20,
    ip                    => "opsview1",
    hostgroup             => { name => "singlehost" },
    snmp_community        => "public",
    check_period          => { name => "workhours" },
    check_command         => { name => "slow ping" },
    enable_snmp           => 0,
    event_handler         => '',
    notification_period   => { name => "nonworkhours" },
    notification_interval => 60,
    rancid_vendor         => undef,
    retry_check_interval  => 2,
    snmp_version          => "1",
    snmp_port             => 161,
    snmpv3_authpassword   => "",
    snmpv3_authprotocol   => undef,
    snmpv3_privpassword   => "",
    snmpv3_privprotocol   => undef,
    snmpv3_username       => "",
    icon                  => {
        "path" => "/images/logos/ubuntu_small.png",
        name   => "LOGO - Ubuntu Linux"
    },
    notification_options => "s,d,u,r,f",
    hosttemplates        => [
        { name => "Network - Base" },
        { name => "Cisco Mgt" },
        { name => "Template to get removed 1st" },
        { name => "Blank" },
    ],
    servicechecks => [
        {
            name                => "DHCP",
            remove_servicecheck => 1,
            event_handler       => undef,
            exception           => "--exception",
            timed_exception     => undef,
        },
        {
            name                => "DNS",
            remove_servicecheck => 0,
            event_handler       => undef,
            exception           => undef,
            timed_exception     => undef,
        },
        {
            name                => "Events",
            remove_servicecheck => 1,
            event_handler       => undef,
            exception           => undef,
            timed_exception     => undef,
        },
        {
            name                => "IRC",
            remove_servicecheck => 0,
            event_handler       => "eventscript go",
            exception           => undef,
            timed_exception     => {
                args       => "--timedexception",
                timeperiod => { name => "nonworkhours" }
            },
        },
        {
            name                => "Kerberos",
            remove_servicecheck => 0,
            event_handler       => undef,
            exception           => undef,
            timed_exception     => {
                args       => "--kerbey",
                timeperiod => { name => "none" }
            },
        },
        {
            name                => "TCP/IP",
            remove_servicecheck => 0,
            event_handler       => undef,
            exception           => undef,
            timed_exception     => undef,
        },
    ],

    monitored_by => { name => "ClusterA" },

    # Order different here from input - default of hosts to order by name
    parents => [ { name => "opslave" }, { name => "opsview" } ],
    keywords =>
      [ { name => "cisco" }, { name => "disabled" }, { name => "newone" }, ],
    rancid_connection_type        => "ssh",
    rancid_username               => undef,
    rancid_password               => undef,
    rancid_vendor                 => undef,
    tidy_ifdescr_level            => 0,
    snmp_max_msg_size             => 0,
    snmp_extended_throughput_data => 0,
    uncommitted                   => 1,
    use_rancid                    => 0,
    use_nmis                      => 1,
    use_mrtg                      => 0,
    flap_detection_enabled        => 1,
    nmis_node_type                => "server",
    hostattributes                => [
        {
            name  => "DISK",
            value => "/u01",
            arg1  => "-p /u01 -c 5%",
            arg2  => "u01-arg2",
            arg3  => "u01-arg3",
            arg4  => "u01-arg4",
        },
        {
            name  => "DISK",
            value => "/u02",
            arg1  => "-p /u02 -c 9%",
            arg2  => "arg2",
            arg3  => "arg3",
            arg4  => "arg4",
        },
        {
            name  => "INTERFACE",
            value => "ent1",
            arg1  => "",
            arg2  => undef,
            arg3  => undef,
            arg4  => undef,
        },
        {
            name  => "URL",
            value => "/about",
            arg1  => "super",
            arg2  => "url arg2",
            arg3  => "url arg3",
            arg4  => "url arg4",
        },
    ],
};

my $hash = $host->serialize_to_hash;
is_deeply( $hash, $expected, "Got same data back again in serialization" )
  || diag( Data::Dump::dump($hash) );

my $exception = $host->exceptions->first;
is( $exception->servicecheck->name, "DHCP", "Got servicecheck exception" );
is( $exception->args, "--exception", "With args" );
my $exceptions_dhcp_id = $exception->id;
my @timedexceptions    = $host->timed_exceptions;
my $timedexception     = $timedexceptions[0];
is(
    $timedexception->servicecheck->name,
    "IRC", "Got servicecheck with timed exception"
);
is( $timedexception->args, "--timedexception", "With timed args" );
is( $timedexception->timeperiod->name, "nonworkhours", "And timeperiod too" );
my $timedexceptions_irc_id = $timedexception->id;
$timedexception = $timedexceptions[1];
is(
    $timedexception->servicecheck->name,
    "Kerberos", "Got servicecheck with timed exception"
);
is( $timedexception->args,             "--kerbey", "With timed args" );
is( $timedexception->timeperiod->name, "none",     "And timeperiod too" );
my $event_handler = $host->event_handlers->first;
is( $event_handler->servicecheck->name, "IRC", "Got servicecheck" );
is( $event_handler->event_handler, "eventscript go" );
my $event_handler_irc_id = $event_handler->id;

diag(
    "Rerun again to confirm that primary key doesn't increment unnecessarily for exceptions"
) if ( $ENV{TEST_VERBOSE} );
$host = $rs->synchronise(
    {
        name          => "opsview1",
        servicechecks => [
            {
                name                => "DHCP",
                remove_servicecheck => 1,
                event_handler       => undef,
                exception           => "--exception",
                timed_exception     => undef,
            },
            {
                name                => "DNS",
                remove_servicecheck => 0,
                event_handler       => undef,
                exception           => undef,
                timed_exception     => undef,
            },
            {
                name                => "IRC",
                remove_servicecheck => 0,
                event_handler       => "eventscript go",
                exception           => undef,
                timed_exception     => {
                    args       => "--timedexception",
                    timeperiod => { name => "nonworkhours" }
                },
            },
            {
                name                => "Kerberos",
                remove_servicecheck => 0,
                event_handler       => undef,
                exception           => undef,
                timed_exception     => {
                    args       => "--kerbey",
                    timeperiod => { name => "none" }
                },
            },
            {
                name                => "Events",
                remove_servicecheck => 1,
                event_handler       => undef,
                exception           => undef,
                timed_exception     => undef,
            },
        ],
    }
);
is( $host->servicechecks->count, 5, "Only 5 servicechecks now" );
$exception = $host->exceptions->first;
is( $exception->servicecheck->name, "DHCP", "Got servicecheck exception" );
is( $exception->args, "--exception", "With args" );
is( $exception->id, $exceptions_dhcp_id, "Same exception id after 2nd change"
);
$timedexception = $host->timed_exceptions->first;
is(
    $timedexception->servicecheck->name,
    "IRC", "Got servicecheck with timed exception"
);
is( $timedexception->args, "--timedexception", "With timed args" );
is( $timedexception->timeperiod->name, "nonworkhours", "And timeperiod too" );
is( $timedexception->id, $timedexceptions_irc_id, "Same timedexceptions id" );
$event_handler = $host->event_handlers->first;
is( $event_handler->servicecheck->name, "IRC", "Got servicecheck" );
is( $event_handler->id, $event_handler_irc_id, "Same eventhandler id" );

my @vars = $host->hostattributes;
is( scalar @vars, 4, "Got all 4 attributes" );
my $var;
$var = $vars[0];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u01" );
is( $var->arg1,            "-p /u01 -c 5%" );
is( $var->arg2,            "u01-arg2" );
is( $var->arg3,            "u01-arg3" );
is( $var->arg4,            "u01-arg4" );
my $serialisation     = $var->serialize_to_hash;
my $hostattr_expected = {
    name  => "DISK",
    value => "/u01",
    arg1  => "-p /u01 -c 5%",
    arg2  => "u01-arg2",
    arg3  => "u01-arg3",
    arg4  => "u01-arg4",
};
is_deeply( $serialisation, $hostattr_expected,
    "Got expected serialisation of host attribute" )
  || diag( Data::Dump::dump($serialisation) );
$var = $vars[1];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u02" );
is( $var->arg1,            "-p /u02 -c 9%" );
is( $var->arg2,            "arg2" );
is( $var->arg3,            "arg3" );
is( $var->arg4,            "arg4" );
$var = $vars[2];
is( $var->attribute->name, "INTERFACE", "Ordered by name!" );
is( $var->value,           "ent1" );
is( $var->arg1,            "" );
$var = $vars[3];
is( $var->attribute->name, "URL" );
is( $var->value,           "/about" );
is( $var->arg1,            "super" );
is( $var->arg2,            "url arg2" );
is( $var->arg3,            "url arg3" );
is( $var->arg4,            "url arg4" );

@vars = $host->hostattributes(
    { "attribute.name" => "DISK" },
    { join             => "attribute" }
);
is( scalar @vars, 2, "Only two" );
$var = $vars[0];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u01" );
$var = $vars[1];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u02" );

@vars = $host->host_attributes_for_name( "DISK" );
is( scalar @vars, 2, "Only two" );
$var = $vars[0];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u01" );
$var = $vars[1];
is( $var->attribute->name, "DISK" );
is( $var->value,           "/u02" );

@vars = $host->host_attributes_for_name( "SLAVENODE" );
is( scalar @vars, 0, "No slave node variables for this host" );

my $opsview = $rs->find( { name => "opsview" } );
@vars = $opsview->host_attributes_for_name( "SLAVENODE" );
is( scalar @vars,    5,         "Found 1 slave node" );
is( $vars[0]->value, "opslave", "Got name of master host" );
is( $vars[0]->arg1,  undef,     "No other value returned" );

my $disk_override = {
    DISK     => "-w 10% -c 5% /boot",
    "DISK:1" => "diskoverridearg1",
    "DISK:2" => "override2",
    "DISK:3" => "override3"
};
my $url_override = { URL => '-u /about -u /login' };
my $withdefault_override = {
    WITHDEFAULT     => "different",
    "WITHDEFAULT:1" => "otherarg1"
};
my $host_attribute_checks = [
    {
        commandline   => 'check_http!-H $HOSTADDRESS$ -u %URL% -w 5 -c 8',
        no_override   => 'check_http!-H $HOSTADDRESS$ -u /about -w 5 -c 8',
        disk_override => 'check_http!-H $HOSTADDRESS$ -u /about -w 5 -c 8',
        url_override =>
          'check_http!-H $HOSTADDRESS$ -u -u /about -u /login -w 5 -c 8',
        withdefault_override =>
          'check_http!-H $HOSTADDRESS$ -u /about -w 5 -c 8',
    },
    {
        commandline          => 'check_ftp!Nothing needs changing',
        no_override          => 'check_ftp!Nothing needs changing',
        disk_override        => 'check_ftp!Nothing needs changing',
        url_override         => 'check_ftp!Nothing needs changing',
        withdefault_override => 'check_ftp!Nothing needs changing',
    },
    {
        commandline => 'check_http_wierdly!-H %INTERFACE% -u %URL% -d %DISK%',
        no_override => 'check_http_wierdly!-H ent1 -u /about -d /u01',
        disk_override =>
          'check_http_wierdly!-H ent1 -u /about -d -w 10% -c 5% /boot',
        url_override =>
          'check_http_wierdly!-H ent1 -u -u /about -u /login -d /u01',
        withdefault_override => 'check_http_wierdly!-H ent1 -u /about -d /u01',
    },

    # NOTE missing attribute names (ones that don't exisst) should be passed
    # through untouched
    {
        commandline =>
          'check_http_wierdly!-H %MISSING% -u %DISK% --missing %MISSING% %WITH123NUMBERS%',
        no_override =>
          'check_http_wierdly!-H %MISSING% -u /u01 --missing %MISSING% ',
        disk_override =>
          'check_http_wierdly!-H %MISSING% -u -w 10% -c 5% /boot --missing %MISSING% ',
        url_override =>
          'check_http_wierdly!-H %MISSING% -u /u01 --missing %MISSING% ',
        withdefault_override =>
          'check_http_wierdly!-H %MISSING% -u /u01 --missing %MISSING% ',
    },
    {
        commandline => 'check_repeatedly!-H %DISK% -1 %DISK% -2 %DISK%',
        no_override => 'check_repeatedly!-H /u01 -1 /u01 -2 /u01',
        disk_override =>
          'check_repeatedly!-H -w 10% -c 5% /boot -1 -w 10% -c 5% /boot -2 -w 10% -c 5% /boot',
        url_override         => 'check_repeatedly!-H /u01 -1 /u01 -2 /u01',
        withdefault_override => 'check_repeatedly!-H /u01 -1 /u01 -2 /u01',
    },
    {
        commandline   => 'check_disk!-w 15% -c 10% -p %DISK%',
        no_override   => 'check_disk!-w 15% -c 10% -p /u01',
        disk_override => 'check_disk!-w 15% -c 10% -p -w 10% -c 5% /boot',
        url_override  => 'check_disk!-w 15% -c 10% -p /u01',
        withdefault_override => 'check_disk!-w 15% -c 10% -p /u01',
    },
    {
        commandline =>
          'check_closeness!%DISK%%URL%%URL%%BLANK%%WITHDEFAULT%%%TYPO%',
        no_override =>
          'check_closeness!/u01/about/aboutsomeverylongdefaultvalueforblankattribute%%TYPO%',
        disk_override =>
          'check_closeness!-w 10% -c 5% /boot/about/aboutsomeverylongdefaultvalueforblankattribute%%TYPO%',
        url_override =>
          'check_closeness!/u01-u /about -u /login-u /about -u /loginsomeverylongdefaultvalueforblankattribute%%TYPO%',
        withdefault_override =>
          'check_closeness!/u01/about/aboutdifferent%%TYPO%',
    },
    {
        commandline          => 'check_ignore_lowercase!%disk% -u %%',
        no_override          => 'check_ignore_lowercase!%disk% -u %%',
        disk_override        => 'check_ignore_lowercase!%disk% -u %%',
        url_override         => 'check_ignore_lowercase!%disk% -u %%',
        withdefault_override => 'check_ignore_lowercase!%disk% -u %%',
    },
    {
        commandline   => 'check_disk_arg!-w 15% -c 10% -p %DISK:1%',
        no_override   => 'check_disk_arg!-w 15% -c 10% -p -p /u01 -c 5%',
        disk_override => 'check_disk_arg!-w 15% -c 10% -p diskoverridearg1',
        url_override  => 'check_disk_arg!-w 15% -c 10% -p -p /u01 -c 5%',
        withdefault_override => 'check_disk_arg!-w 15% -c 10% -p -p /u01 -c 5%',
    },
    {
        commandline          => 'check_url_arg!-w 15% -c 10% -p %URL:1%',
        no_override          => 'check_url_arg!-w 15% -c 10% -p super',
        disk_override        => 'check_url_arg!-w 15% -c 10% -p super',
        url_override         => 'check_url_arg!-w 15% -c 10% -p super',
        withdefault_override => 'check_url_arg!-w 15% -c 10% -p super',
    },
    {
        commandline =>
          'check_nrpe_port!-H $HOSTADDRESS$ -p %NRPE_PORT% %WITHDEFAULT:1%',
        no_override   => 'check_nrpe_port!-H $HOSTADDRESS$ -p  withdefaultarg1',
        disk_override => 'check_nrpe_port!-H $HOSTADDRESS$ -p  withdefaultarg1',
        url_override  => 'check_nrpe_port!-H $HOSTADDRESS$ -p  withdefaultarg1',
        withdefault_override =>
          'check_nrpe_port!-H $HOSTADDRESS$ -p  otherarg1',
    },
    {
        commandline =>
          'check_multiargs!-H $HOSTADDRESS$ -p %DISK% %DISK:1% %DISK:2% %DISK:3% %DISK:4%',
        no_override =>
          'check_multiargs!-H $HOSTADDRESS$ -p /u01 -p /u01 -c 5% u01-arg2 u01-arg3 u01-arg4',
        disk_override =>
          'check_multiargs!-H $HOSTADDRESS$ -p -w 10% -c 5% /boot diskoverridearg1 override2 override3 u01-arg4',
        url_override =>
          'check_multiargs!-H $HOSTADDRESS$ -p /u01 -p /u01 -c 5% u01-arg2 u01-arg3 u01-arg4',
        withdefault_override =>
          'check_multiargs!-H $HOSTADDRESS$ -p /u01 -p /u01 -c 5% u01-arg2 u01-arg3 u01-arg4',
    },

    # check to ensure attribute-type date formatters are not changed
    {
        commandline =>
          'check_nrpe|-H $HOSTADDRESS$ -c check_file_name -a 21600 21600 /path/to/%Y/%Y%m/%Y%m%d/%Y%m%d-%H.log.bz2',
        no_override =>
          'check_nrpe|-H $HOSTADDRESS$ -c check_file_name -a 21600 21600 /path/to/%Y/%Y%m/%Y%m%d/%Y%m%d-%H.log.bz2',
        disk_override =>
          'check_nrpe|-H $HOSTADDRESS$ -c check_file_name -a 21600 21600 /path/to/%Y/%Y%m/%Y%m%d/%Y%m%d-%H.log.bz2',
        url_override =>
          'check_nrpe|-H $HOSTADDRESS$ -c check_file_name -a 21600 21600 /path/to/%Y/%Y%m/%Y%m%d/%Y%m%d-%H.log.bz2',
        withdefault_override =>
          'check_nrpe|-H $HOSTADDRESS$ -c check_file_name -a 21600 21600 /path/to/%Y/%Y%m/%Y%m%d/%Y%m%d-%H.log.bz2',
    },
];

foreach my $check (@$host_attribute_checks) {
    my $commandline = $check->{commandline};
    is(
        $host->substitute_host_attributes($commandline),
        $check->{no_override}, "No override: $commandline"
    );
    is(
        $host->substitute_host_attributes( $commandline, $disk_override ),
        $check->{disk_override},
        "Disk override: $commandline"
    );
    is(
        $host->substitute_host_attributes( $commandline, $url_override ),
        $check->{url_override},
        "URL override: $commandline"
    );
    is(
        $host->substitute_host_attributes(
            $commandline, $withdefault_override
        ),
        $check->{withdefault_override},
        "URL override: $commandline"
    );
}

my $disk_attribute =
  $schema->resultset("Attributes")->find( { name => "DISK" } );
is(
    $host->substitute_host_attributes_with_possible_attribute(
        {
            commandline =>
              "check_disk -p %DISK% %DISK:1% --args2 %DISK:2% --args3 %DISK:3% --random %URL%",
            attribute => $disk_attribute,
            value     => "/u02",
        }
    ),
    "check_disk -p /u02 -p /u02 -c 9% --args2 arg2 --args3 arg3 --random /about",
    "Got expected substitution in other direction for multi-service",
);

my $interface_attribute =
  $schema->resultset("Attributes")->find( { name => "INTERFACE" } );
my $host_with_interfaces =
  $schema->resultset("Hosts")->find( { name => "host_locally_monitored" } );
is(
    $host_with_interfaces->substitute_host_attributes_with_possible_attribute(
        {
            commandline =>
              "check_snmp_interface_cascade %INTERFACE% %INTERFACE:1% %INTERFACE:2%",
            attribute => $interface_attribute,
            value     => "Interface with quotes in",
        }
    ),
    q{check_snmp_interface_cascade Interface with quotes in -v 2c -C 'public' -p 161 -I 'Interface with '"'"'quotes'"'"' in' -w 20% -c 30%},
    "Got expected substitution for INTERFACES",
);

my $slavenode_attribute =
  $schema->resultset("Attributes")->find( { name => "SLAVENODE" } );
is(
    $opsview->substitute_host_attributes_with_possible_attribute(
        {
            commandline => "check_opsview_slave_node -r %SLAVENODE%",
            attribute   => $slavenode_attribute,
            value       => "opslaveclusterA",
        }
    ),
    "check_opsview_slave_node -r opslaveclusterA",
    "Got expected substitution for SLAVENODE",
);

my $clusternode_attribute =
  $schema->resultset("Attributes")->find( { name => "CLUSTERNODE" } );
my $host_opslaveclusterB =
  $schema->resultset("Hosts")->find( { name => "opslaveclusterB" } );
is(
    $host_opslaveclusterB->substitute_host_attributes_with_possible_attribute(
        {
            commandline =>
              "check_opsview_cluster_node --name %CLUSTERNODE% --ip %CLUSTERNODE:1%",
            attribute => $clusternode_attribute,
            value     => "opslaveclusterC",
        }
    ),
    "check_opsview_cluster_node --name opslaveclusterC --ip opslaveclusterCip",
    "Got expected substitution for CLUSTERNODE",
);

@scs =
  $host->servicechecks( { remove_servicecheck => 1 }, { order_by => "name" } );
is( scalar @scs, 2 );
is_deeply( [ $scs[0]->name, $scs[1]->name ], [qw(DHCP Events)] );

@names = map { $_->name } ( $host->parents( {}, { order_by => "name" } ) );
is( scalar @names, 2 );
is_deeply( \@names, [qw(opslave opsview)] );

@names = map { $_->name } ( $host->keywords( {}, { order_by => "name" } ) );
is( scalar @names, 3 );
is_deeply( \@names, [qw(cisco disabled newone)] );
is( $host->list_keywords, "cisco,disabled,newone", "Keywords for web view" );

# Test we get default icon, so it can not be set with no icon name
$host = $rs->synchronise(
    {
        name => "opsview1",
        icon => ""
    }
);
is( $host->icon->name, "LOGO - Opsview" );

my $validation = $rs->validation_regexp;
my $v_expected = {
    ip                   => "/^[^\\[\\]`~!\\\$%^&*|'\"<>?,()= ]{1,254}\$/",
    name                 => "/^[\\w\\.-]{1,63}\$/",
    nmis_node_type       => "/^(router|switch|server)\$/",
    notification_options => "/^([udrfsn])(,[udrfs])*\$/",
    other_addresses      => "/^ *(?:(?:[\\w\\.:-]+)?(?: *, *)?)* *\$/",
    rancid_password      => "/^[^{}]*\$/",
    snmp_version         => "/^(1|2c|3)\$/",
    snmpv3_authpassword  => "/^\$|^.{8,}\$/",
    snmpv3_privpassword  => "/^\$|^.{8,}\$/",
    event_handler        => '/^(?:[\w\.\$ -]+)?$/',
};
is_deeply( $validation, $v_expected, "Validation as expected" );

my $parents_lookup = $rs->calculate_parents();
is_deeply( $parents_lookup->{1}, [], "No parents for opsview master" );
is_deeply( $parents_lookup->{7}, [qw(opsview)],
    "cisco has parent of opsview master server"
);

is_deeply( $parents_lookup->{10}, [qw(opslave)],
    "cisco3 has parent of slave server, because none defined explicitly"
);

is_deeply(
    $parents_lookup->{22},
    [qw(opslaveclusterA opslaveclusterB opslaveclusterC)],
    "monitored_by_cluster has parents of slave cluster, because none defined explicitly"
);

is_deeply( $parents_lookup->{11}, [qw(cisco)], "cisco4 has parent of cisco" );

is_deeply( $parents_lookup->{4}, [qw(cisco cisco3)],
    "monitored_by_slave has parent of cisco and cisco3"
);

is_deeply( $parents_lookup->{5}, [qw(opsview)], "opslave has parent of master"
);

is_deeply( $parents_lookup->{19}, [qw(opsview)],
    "... and so does opslaveclusterA"
);

is_deeply( $parents_lookup->{20}, [qw(cisco)],
    "But opslaveclusterB has one specifically defined"
);

my $slave = $schema->resultset("Monitoringservers")->find(2);
$parents_lookup =
  $rs->calculate_parents( { filter_by_monitoringserver => $slave } );
is( $parents_lookup->{1},  undef, "master not listed" );
is( $parents_lookup->{19}, undef, "Neither is opslaveclusterA" );

is_deeply( $parents_lookup->{10}, [qw(opslave)],
    "cisco3 has parent of slave server, because none defined explicitly"
);

is_deeply(
    $parents_lookup->{4},
    [qw(cisco3)],
    "monitored_by_slave only has parent of cisco3 as cisco is not in this system"
);

is_deeply( $parents_lookup->{5}, [],
    "opslave has no parent since master is not visible"
);

# Test error scenarios - ignores unknown attributes
$_ = $rs->synchronise(
    {
        bum                 => "lovely",
        name                => "opsview1",
        snmp_community      => "public4",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" }
    }
);
isa_ok( $_, "Opsview::Schema::Hosts" );

eval { $rs->synchronise( { name1 => "opsview1" } ) };
is( $@, "name: Missing\n", "No name specified" );

eval {
    $rs->synchronise(
        {
            name      => "opsview1",
            hostgroup => { name => "Opsview" }
        }
    );
};
is( $@, "Host group is not a leaf\n" );

eval {
    $rs->synchronise(
        {
            name                => "opsview1",
            check_period        => { name => "invalid" },
            notification_period => { name => "BOB" }
        }
    );
};
is(
    $@,
    "No related object for check_period 'name=invalid'; No related object for notification_period 'name=BOB'\n",
    "check period foreign key check"
);

eval {
    $rs->synchronise(
        {
            name          => "opsview1",
            servicechecks => [ { name => "invalid" } ],
            hosttemplates => [ { id => 1 }, { id => 555 } ]
        }
    );
};
is(
    $@,
    "No related object for hosttemplates 'id=555'; No related object for servicechecks 'name=invalid'\n"
);

eval {
    $rs->synchronise(
        {
            name    => "opsview1",
            parents => [ { name => "invalid" } ]
        }
    );
};
is(
    $@,
    "No related object for parents 'name=invalid'\n",
    "parents foreign key check"
);

eval {
    $rs->synchronise(
        {
            name                => "opsview1",
            snmpv3_authpassword => "short"
        }
    );
};
is( $@, "snmpv3_authpassword: Invalid\n" );

eval { $rs->synchronise( { name => "bad::name" } ) };
is( $@, "name: Invalid\n" );

eval {
    $rs->synchronise(
        {
            name =>
              "1234567890123456789012345678901234567890123456789012345678901234"
        }
    );
};
is( $@, "name: Invalid\n", "name too long" );

eval {
    $rs->synchronise(
        {
            name =>
              "123456789012345678901234567890123456789012345678901234567890123"
        }
    );
};
is( $@, '', "name just right" );

eval {
    $rs->synchronise(
        {
            name     => "opsview1",
            keywords => [ { id => 444 } ]
        }
    );
};
is( $@, "keywords: name: Missing\n", "Missing keyword information" );

eval {
    $rs->synchronise(
        {
            name                 => "opsview1",
            notification_options => "tonnie"
        }
    );
};
is( $@, "notification_options: Invalid\n" );

eval { $rs->synchronise( { name => "opsview1", snmp_version => "4" } ) };
is( $@, "snmp_version: Invalid\n" );

eval {
    $rs->synchronise(
        {
            name      => "opsview1",
            hostgroup => { name => "unknown" }
        }
    );
};
is( $@, "No related object for hostgroup 'name=unknown'\n" );

eval {
    $rs->synchronise(
        {
            name => "opsview1",
            icon => { name => "LOGO - Debian" }
        }
    );
};
is( $@, "No related object for icon 'name=LOGO - Debian'\n" );

# Special test of this. Seems using related_resultset sets some join conditions
eval {
    $rs->synchronise(
        {
            name => "opsview1",
            icon => { name => "LOGO - Debian Linux" }
        }
    );
};
is( $@, '', "Found logo correctly" );

eval {
    $rs->synchronise(
        {
            name           => "opsview1",
            nmis_node_type => "jokingme"
        }
    );
};
is( $@, "nmis_node_type: Invalid\n" );

eval { $rs->synchronise( { name => "opsview1", icon => { name => "" } } ) };
is( $@, "No related object for icon 'name='\n" );

eval { $rs->synchronise( { name => "opsview1", ip => "invalid%char" } ) };
is( $@, "ip: Invalid\n" );

eval { $rs->synchronise( { name => "opsview1", ip => "invalid[char" } ) };
is( $@, "ip: Invalid\n" );

eval { $rs->synchronise( { name => "opsview1", ip => 'invalid$char' } ) };
is( $@, "ip: Invalid\n" );

eval {
    $rs->synchronise(
        {
            name          => "opsview1",
            servicechecks => [
                {
                    name            => "DHCP",
                    timed_exception => {
                        timeperiod => 999,
                        args       => "--fail"
                    },
                }
            ]
        }
    );
};
is( $@, "No related object for timeperiod '999'\n" );

eval {
    $rs->synchronise(
        {
            name          => "opsview1",
            servicechecks => [
                {
                    name            => "DHCP",
                    timed_exception => {
                        timeperiod => { name => "notimeisbesttime" },
                        args       => "--fail"
                    },
                }
            ]
        }
    );
};
is( $@, "No related object for timeperiod 'name=notimeisbesttime'\n" );

eval {
    $rs->synchronise(
        {
            name           => "opsview1",
            hostattributes => [
                {
                    name  => "DISK",
                    value => "/u01",
                    args1 => "-p /u02 -c 9%"
                },
                {
                    name  => "DISK",
                    value => "/u01",
                    args1 => "-p /u01 -c 5%"
                },
            ]
        }
    );
};
is( $@, "attributes duplicated for name 'DISK', value '/u01'\n" );

eval {
    $rs->synchronise(
        {
            name           => "opsview1",
            hostattributes => [
                {
                    name  => "Bad^%&Chars",
                    value => "/u01",
                    args  => "-p /u02 -c 9%"
                },
                {
                    name  => "DISK",
                    value => "Bad!)(robots",
                    args  => "-p /u01 -c 5%"
                },
            ]
        }
    );
};

#TODO: Should we get two errors? Only one at moment because the eval stops others
is(
    $@,
    "No related object for hostattributes 'value=/u01,args=-p /u02 -c 9%,name=Bad^%&Chars'\n"
);

eval {
    $rs->synchronise(
        {
            name           => "opsview1",
            hostattributes => [
                {
                    name  => "DISK",
                    value => "%"
                }
            ]
        }
    );
};
is( $@, "value: Invalid\n" );

# Check use of enable_snmp
$host = $rs->find( { name => "cisco" } );
@vars = $host->host_attributes_for_name( "INTERFACE" );
is( scalar @vars, 0, "No interfaces listed" );
is(
    $host->snmpinterfaces->count,
    2, "Even though one actually listed (+1 for default)"
);
is( $host->enable_snmp, 0, "...because enable_snmp unset" );

# Check INTERFACE:1 macro expansion
$host = $rs->find( { name => "cisco4" } );
@vars = $host->host_attributes_for_name( "INTERFACE" );
is( scalar @vars,                 4,  "4 interfaces listed" );
is( $host->snmpinterfaces->count, 10, "Though 9 (+1 default) listed" );

is( $vars[0]->value, "Ethernet0-01" );
is( $vars[0]->arg1,  "-v 2c -C 'public' -p 161 -I 'Ethernet0' -n 1" );
is( $vars[0]->arg2,  "-c 2%" );
is( $vars[0]->arg3,  "-w 5 -c 10" );
is( $vars[0]->arg4,  "-w 4 -c 7" );
is( $vars[1]->value, "Ethernet0-12" );
is( $vars[1]->arg1,  "-v 2c -C 'public' -p 161 -I 'Ethernet0' -n 12" );
is( $vars[1]->arg2,  "-w 12% -c 24%" );
is( $vars[1]->arg3,  "-w 4 -c 11" );
is( $vars[1]->arg4,  "-w 2 -c 7" );
is( $vars[2]->value, "Ethernet0-20" );
is( $vars[2]->arg1,  "-v 2c -C 'public' -p 161 -I 'Ethernet0' -n 20" );
is( $vars[2]->arg2,  "-w 20%" );
is( $vars[2]->arg3,  "-w 5 -c 13" );
is( $vars[2]->arg4,  "" );
is( $vars[3]->value, "EthernetWithAVeryLongAndSillyNameForPeopleToDiscu 2" );
is(
    $vars[3]->arg1,
    "-v 2c -C 'public' -p 161 -I 'EthernetWithAVeryLongAndSillyNameForPeopleToDiscussAboutUntilARipeOldAgeOf75AndAHalf0' -n 6"
);
is( $vars[3]->arg2, "-w 6%" );
is( $vars[3]->arg3, "-w 5" );
is( $vars[3]->arg4, "-w 1 -c 7" );

$schema->resultset("Metadata")->find("uncommitted")->update( { value => 0 } );
is(
    $schema->resultset("Metadata")->find("uncommitted")->value,
    0, "Uncommitted flag reset"
);

$rs->find( { name => "cisco4" } )->delete;
is(
    $schema->resultset("Metadata")->find("uncommitted")->value,
    1, "Uncommitted flag changed to 1 due to deletion"
);

# Test wiki method works
$host = $rs->find(10);
is( $host->name,        "cisco3" );
is( $host->information, "Some information in wiki" );

$host = $rs->find(6);
is( $host->name, "resolved_services" );
is( $host->hosttemplates->count, 4, "Got all host templates" );
my @htnames = map { $_->name } ( $host->hosttemplates );
is_deeply(
    \@htnames,
    [
        "Base Unix",
        "Template to get removed 1st",
        "Template to get removed 2nd",
        "Cisco Mgt"
    ],
    "Right host templates"
);
is(
    $host->servicechecks( { name => "Check Loadavg" } )->count,
    1, "Got Check Loadavg host defined"
);
is(
    $host->servicechecks( { name => "Check Memory" } )->count,
    1, "Got Check Memory too"
);

$schema->resultset("Systempreferences")->find(1)
  ->update( { smart_hosttemplate_removal => 1 } );
$host = $rs->synchronise(
    {
        name          => "resolved_services",
        hosttemplates => [
            { name => "Template to get removed 1st" },
            { name => "Template to get removed 2nd" },
            { name => "Cisco Mgt" },
        ]
    }
);
is( $host->hosttemplates->count, 3, "Got 3 host templates now" );
@htnames = map { $_->name } ( $host->hosttemplates );
is_deeply(
    \@htnames,
    [
        "Template to get removed 1st",
        "Template to get removed 2nd",
        "Cisco Mgt"
    ],
    "Right host templates"
);
is(
    $host->servicechecks( { name => "Check Loadavg" } )->count,
    0, "Check Loadavg has been removed"
);
is(
    $host->servicechecks( { name => "Check Memory" } )->count,
    1, "But Check Memory remains due to reference in Cisco Mgt template"
);

$schema->resultset("Systempreferences")->find(1)
  ->update( { smart_hosttemplate_removal => 0 } );
$host = $rs->synchronise(
    {
        name          => "resolved_services",
        hosttemplates => [
            { name => "Template to get removed 1st" },
            { name => "Template to get removed 2nd" },
        ]
    }
);
is( $host->hosttemplates->count, 2, "Got 2 host templates now" );
@htnames = map { $_->name } ( $host->hosttemplates );
is_deeply(
    \@htnames,
    [ "Template to get removed 1st", "Template to get removed 2nd" ],
    "Right host templates"
);
is(
    $host->servicechecks( { name => "Check Memory" } )->count,
    1, "Check Memory remains due to no smart host template removal"
);

done_testing;
