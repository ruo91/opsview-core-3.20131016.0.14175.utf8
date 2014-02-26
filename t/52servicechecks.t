#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Servicecheck;
use utf8;

my $sc;
my $expected;
my $got;

$sc = undef;

# check that constraint starts on 64 characters
my $longname_invalid = "A" x 64;
eval { $sc = Opsview::Servicecheck->create( { name => $longname_invalid } ) };
is( $sc, undef, "Service check not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$sc = undef;
my $longname_valid = "A" x 63;
eval {
    $sc = Opsview::Servicecheck->create(
        {
            name         => $longname_valid,
            servicegroup => 1
        }
    );
};
is( $sc->name, $longname_valid, "Servicecheck created with 63 chars" );
is( $@, "", "No create error" );

$sc = undef;
eval { $sc = Opsview::Servicecheck->create( { name => 'bad$%^"£%' } ) };
is( $sc, undef, "Host not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$sc = undef;
eval { $sc = Opsview::Servicecheck->create( { name => 'Lotsof,,,inname' } ) };
is( $sc, undef, "Servicecheck not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$sc = undef;
eval { $sc = Opsview::Servicecheck->create( { name => 'disallow:in here' } ) };
is( $sc, undef, "Servicecheck not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$sc = undef;
eval { $sc = Opsview::Servicecheck->create( { name => 'disallow:in here' } ) };
is( $sc, undef, "Servicecheck not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$sc = Opsview::Servicecheck->retrieve(29);
is( $sc->name, "TCP/IP", "Got TCP/IP" );
$expected = [
    qw(
      doesnt_exist_1
      doesnt_exist_2
      fake_ipv6
      host_locally_monitored
      host_locally_monitored_v3
      monitored_by_cluster
      monitored_by_slave
      opsview
      opsviewdev1
      opsviewdev46
      resolved_services
      toclone
      )
];
$got = [ map { $_->name } @{ $sc->all_hosts } ];
is_deeply( $got, $expected, "Got list of all hosts" );

is( $sc->count_all_hosts, scalar @$expected );

foreach my $s ( Opsview::Servicecheck->retrieve_all ) {
    my $list = $s->all_hosts;
    is( scalar @$list, $s->count_all_hosts, "Same number for " . $s->name );
}

my @results = Opsview::Servicecheck->retrieve_all_exceptions_by_service(44);
is( scalar @results,             6, "Got 6 exceptions" );
is( $results[0]->{t_ex_checked}, 1, "Is hosttemplate timed exception" );
is( $results[0]->{t_id}->name, "Cisco Mgt", "Got right hosttemplate name" );
is( $results[0]->{t_ex_args}, '--except' );
is( $results[1]->{t_to_checked}, 1, "Is hosttemplate timed exception" );
is( $results[1]->{t_id}->name, "Cisco Mgt", "Got right hosttemplate name" );
is( $results[1]->{t_to_timeperiod}->name, "nonworkhours", "Got timeperiod" );
is( $results[1]->{t_to_args}, '--timed --nonworkhours' );
is( $results[2]->{h_to_checked}, 1, "Is host timed exception" );
is( $results[2]->{h_id}->name, "monitored_by_slave", "Got right host" );
is( $results[2]->{h_to_timeperiod}->name, "nonworkhours", "Got timeperiod" );
is(
    $results[2]->{h_to_args},
    '-H $HOSTADDRESS$ -c check_memory -a \'-w 70 -c 78\'',
    "Got right args for timed override"
);
is( $results[3]->{h_ex_checked}, 1, "Is host exception" );
is( $results[3]->{h_id}->name, "resolved_services", "Got resolved_services" );
is( $results[3]->{h_ex_args},  '--exception --and', "Got host exception" );
is(
    $results[4]->{h_to_checked},
    1, "Is host timed exception on same host as a host exception"
);
is(
    $results[4]->{h_to_timeperiod}->name,
    "workhours", "Got timeperiod override"
);
is(
    $results[4]->{h_to_args},
    '--timed --too --port %NRPE_PORT% --creds %MYSQL_CREDENTIALS%',
    "Got args for timedoverride"
);
is( $results[5]->{remove_servicecheck}, 1, "Is a host removed service check" );
is( $results[5]->{h_id}->name, "cisco3", "Got hostname for removed check" );
