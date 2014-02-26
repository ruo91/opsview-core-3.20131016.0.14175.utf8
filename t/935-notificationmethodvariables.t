#!/usr/bin/perl
# Tests for Opsview::Schema notificationmethods

use Test::More qw(no_plan);
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Config::Notifications;

is(
    $Opsview::Config::Notifications::configfile,
    "/usr/local/nagios/etc/notificationmethodvariables.cfg"
);

$Opsview::Config::Notifications::configfile =
  "$Bin/var/configs/Master Monitoring Server/notificationmethodvariables.cfg";
my $vars = Opsview::Config::Notifications->notification_variables(
    'com.opsview.notificationmethods.aql'
);
isa_ok( $vars, "HASH" );
my $expected = {
    'AQL_USERNAME'     => 'aqluser',
    'AQL_PASSWORD'     => 'aqlpass',
    'AQL_PROXY_SERVER' => 'http://proxy.example.com'
};
is_deeply( $vars, $expected, "Got expected value" );

my $config = Opsview::Config::Notifications->config_variables;
is_deeply(
    $config->{hostgroups}->{Leaf2},
    { matpath => "Opsview,UK2,Leaf2" },
    "Data for hostgroup Leaf2 as expected"
);

$Opsview::Config::Notifications::configfile = "/tmp/nosuchfile";
eval { $vars = Opsview::Config::Notifications->config };
like( $@, qr/Can't locate/ );
