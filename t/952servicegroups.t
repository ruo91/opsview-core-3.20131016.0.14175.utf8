#!/usr/bin/perl
# Tests for Opsview::ResultSet::Servicegroups

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
my $rs = $schema->resultset( "Servicegroups" );

$obj = $rs->find(2);
isa_ok( $obj, "Opsview::Schema::Servicegroups" );

is( $obj->servicechecks->count, 6, );

$expected = {
    name          => "freshness checks",
    id            => 2,
    servicechecks => [
        { name => "Passive no freshness" },
        { name => "Passive renotify" },
        { name => "Passive set_stale" },
        { name => "snmptrap no freshness" },
        { name => "snmptrap renotify" },
        { name => "snmptrap set_stale" },
    ],
    uncommitted => 0,
};
$h = $obj->serialize_to_hash;
is_deeply( $h, $expected, "Got serialization" )
  || diag( Data::Dump::dump($h) );

$rs->synchronise( { name => "to delete" } );
$obj = $rs->find( { name => "to delete" } );
isa_ok( $obj, "Opsview::Schema::Servicegroups" );

$obj->delete;

is( $rs->find( { name => "to delete" } ), undef, "servicegroup gone" );
