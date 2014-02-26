#!/usr/bin/perl

use Test::More tests => 2;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Host;

# This host has some interesting uses of exceptions, hosttemplates and timed exceptions
my $host = Opsview::Host->search( name => "resolved_services" )->first;
isa_ok( $host, "Opsview::Host", "host defined" );

my $array_ref = $host->resolved_servicechecks;

my $expected = [
    {
        args      => '-H $HOSTADDRESS$ -c check_disk -a \'-w 5% -c 2% -p /\'',
        exception => 0,
        hosttemplate        => 1,
        hosttemplate_name   => 'Base Unix',
        priority            => 1,
        servicecheck        => 47,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args                => '-H $HOSTADDRESS$ -p 548',
        exception           => 0,
        hosttemplate        => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        timedoverride       => 0,
        servicecheck        => 1,
        event_handler       => "done-for-afs",
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args      => '-H $HOSTADDRESS$ -c check_load -a \'-w 5,5,5 -c 9,9,9\'',
        exception => 0,
        hosttemplate             => 0,
        hosttemplate_name        => 'Custom',
        priority                 => 0,
        servicecheck             => 45,
        timedoverride            => 1,
        timedoverride_args       => '--timed',
        timedoverride_timeperiod => '24x7',
        event_handler            => undef,
        servicegroup_name        => "Operations",
        remove_servicecheck      => 0,
        attribute                => undef,
    },
    {
        args              => '--exception --and',
        exception         => 1,
        hosttemplate      => 0,
        hosttemplate_name => 'Custom',
        priority          => 0,
        servicecheck      => 44,
        timedoverride     => 1,
        timedoverride_args =>
          '--timed --too --port %NRPE_PORT% --creds %MYSQL_CREDENTIALS%',
        timedoverride_timeperiod => 'workhours',
        event_handler            => undef,
        servicegroup_name        => "Operations",
        remove_servicecheck      => 0,
        attribute                => undef,
    },
    {
        args                => '-H $HOSTADDRESS$ -p 8080',
        exception           => 0,
        hosttemplate        => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        servicecheck        => 34,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 1,
        removed_templates   => [
            {
                hosttemplate      => 5,
                hosttemplate_name => "Template to get removed 1st",
                id                => 5,
            },
            {
                hosttemplate      => 6,
                hosttemplate_name => "Template to get removed 2nd",
                id                => 6,
            }
        ],
        attribute => undef,
    },
    {
        args =>
          '-H $HOSTADDRESS$ -p 3306 -u %MYSQL_CREDENTIALS:1% -p %MYSQL_CREDENTIALS:2%',
        exception           => 0,
        hosttemplate        => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        servicecheck        => 14,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 1,
        removed_templates   => [],
        attribute           => undef,
    },
    {
        args                => '-H $HOSTADDRESS$ -c win_service_nrpe',
        exception           => 0,
        hosttemplate        => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        servicecheck        => 60,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args         => '-H $HOSTADDRESS$ -c win_check_sysinfo -p %NRPE_PORT%',
        exception    => 0,
        hosttemplate => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        servicecheck        => 62,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 1,
        removed_templates   => [],
        attribute           => undef,
    },
    {
        args         => '-H $HOSTADDRESS$ -c win_service_server -p %NRPE_PORT%',
        exception    => 0,
        hosttemplate => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        servicecheck        => 61,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args                => '-H $HOSTADDRESS$ -p 22',
        exception           => 0,
        hosttemplate        => 1,
        hosttemplate_name   => 'Base Unix',
        priority            => 1,
        servicecheck        => 22,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args                => '--exception',
        exception           => 1,
        hosttemplate        => 0,
        hosttemplate_name   => 'Custom',
        priority            => 0,
        timedoverride       => 0,
        servicecheck        => 29,
        event_handler       => "run_for_tcpip",
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
    {
        args                => '-H $HOSTADDRESS$ -p 5900',
        exception           => 0,
        hosttemplate        => 1,
        hosttemplate_name   => 'Base Unix',
        priority            => 1,
        servicecheck        => 27,
        timedoverride       => 0,
        event_handler       => undef,
        servicegroup_name   => "Operations",
        remove_servicecheck => 0,
        attribute           => undef,
    },
];

is_deeply( $array_ref, $expected, "As expected" );
