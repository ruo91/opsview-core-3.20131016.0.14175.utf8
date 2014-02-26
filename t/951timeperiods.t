#!/usr/bin/perl
# Tests for Opsview::ResultSet::Timeperiods

use Test::More qw(no_plan);

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);

my $schema = Opsview::Schema->my_connect;

my $obj;
my $expected;
my $h;
my $rs = $schema->resultset( "Timeperiods" );

$obj = $rs->find(3);
isa_ok( $obj, "Opsview::Schema::Timeperiods" );

is( $obj->host_check_periods->count,                2, );
is( $obj->host_notification_periods->count,         1, );
is( $obj->servicecheck_check_periods->count,        1, );
is( $obj->servicecheck_notification_periods->count, 2, );
is( $obj->host_timed_exceptions->count,             1, );
is( $obj->hosttemplate_timed_exceptions->count,     1, );

$expected = {
    alias       => "Non-work Hours",
    id          => 3,
    name        => "nonworkhours",
    uncommitted => 0,
    monday      => "00:00-09:00,17:00-24:00",
    tuesday     => "00:00-09:00,17:00-24:00",
    wednesday   => "00:00-09:00,17:00-24:00",
    thursday    => "00:00-09:00,17:00-24:00",
    friday      => "00:00-09:00,17:00-24:00",
    saturday    => "00:00-24:00",
    sunday      => "00:00-24:00",
    host_check_periods =>
      [ { name => "monitored_by_cluster" }, { name => "monitored_by_slave" }, ],
    host_notification_periods  => [ { name => "toclone" }, ],
    servicecheck_check_periods => [ { name => "Whois" }, ],
    servicecheck_notification_periods =>
      [ { name => "TFTP" }, { name => "Whois" }, ],
};
$h = $obj->serialize_to_hash;
is_deeply( $h, $expected, "Got serialization" )
  || diag( Data::Dump::dump($h) );

is( $rs->search( { name => "NewTP" } )->count, 0 );

$rs->synchronise( { name => "NewTP" } );

is( $rs->search( { name => "NewTP" } )->count, 1 );

$obj = $rs->find( { name => "NewTP" } );
is( $obj->uncommitted, 1, "Check uncommitted flag set" );

# Have non-existent host to check that if the synchronise
# ignores do not bother trying to do a lookup
$rs->synchronise(
    {
        name                      => "NewTP",
        alias                     => "Normal new working practice",
        monday                    => "10:00-16:00",
        tuesday                   => "09:00-17:00,18:00-21:30",
        sunday                    => "",
        host_notification_periods => [ { name => "hostdoesnotexist" }, ],
    }
);
$obj = $rs->find( { name => "NewTP" } );
is( $obj->alias,   "Normal new working practice" );
is( $obj->monday,  "10:00-16:00", );
is( $obj->tuesday, "09:00-17:00,18:00-21:30", );
is( $obj->sunday,  "" );

$expected = {
    alias                             => "Normal new working practice",
    monday                            => "10:00-16:00",
    tuesday                           => "09:00-17:00,18:00-21:30",
    sunday                            => "",
    id                                => 5,
    name                              => "NewTP",
    uncommitted                       => 1,
    wednesday                         => "",
    thursday                          => "",
    friday                            => "",
    saturday                          => "",
    sunday                            => "",
    host_check_periods                => [],
    host_notification_periods         => [],
    servicecheck_check_periods        => [],
    servicecheck_notification_periods => [],
};
$h = $obj->serialize_to_hash;
is_deeply( $h, $expected, "Got serialization" )
  || diag( Data::Dump::dump($h) );

eval { $rs->synchronise( { name => "bad::name" } ) };
is( $@, "name: Invalid\n" );

eval { $rs->synchronise( { name => "NewTP", alias => 'bad\\alias' } ) };
is( $@, "alias: Invalid\n" );

eval { $rs->synchronise( { name => "NewTP", monday => 'funnytime' } ) };
is( $@, "monday: Invalid\n" );

eval { $rs->synchronise( { name => "24x7", monday => "" } ) };
is( $@, "Cannot change this timeperiod\n" );

$obj = $rs->find( { name => "24x7" } );
isnt( $obj->monday, "", "Confirmed no change" );

1;
