#!/usr/bin/perl
# Tests for Opsview::ResultSet::Monitoringservers

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Monitoringservers" );

my $lookup    = $rs->monitoringserverhosts_lookup;
my $num_hosts = 7;
is(
    scalar keys %$lookup,
    $num_hosts, "Got $num_hosts hosts acting as monitoringservers"
);
is( $lookup->{1}->name,  "Master Monitoring Server" );
is( $lookup->{19}->name, "Cluster" );
is( $lookup->{20}->name, "Cluster" );
is( $lookup->{21}->name, "Cluster" );
is( $lookup->{5}->name,  "ClusterA" );

my $hash;
my $expected;
my $obj = $rs->find(1);
isa_ok( $obj, "Opsview::Schema::Monitoringservers" );

is( $obj->host->name, "opsview",      "Got host name" );
is( $obj->host->ip,   "opsviewdev46", "Got host ip" );
$expected = {
    activated => 1,
    id        => 1,
    monitors  => [
        { name => "cisco" },
        { name => "cisco1" },
        { name => "cisco4" },
        { name => "doesnt_exist_1" },
        { name => "doesnt_exist_2" },
        { name => "fake_ipv6" },
        { name => "host_locally_monitored" },
        { name => "host_locally_monitored_v3" },
        { name => "opsview" },
        { name => "opsviewdev1" },
        { name => "opsviewdev46" },
        { name => "resolved_services" },
        { name => "singlehostgroup" },
        { name => "toclone" },
    ],
    name        => "Master Monitoring Server",
    nodes       => [ { host => { name => "opsview" } } ],
    roles       => [],
    passive     => 0,
    uncommitted => 0,
};
$hash = $obj->serialize_to_hash;
is_deeply( $hash, $expected, "Got serialization" )
  || diag( Data::Dump::dump($hash) );

$obj      = $rs->find(2);
$expected = {
    activated => 1,
    id        => 2,
    monitors  => [
        { name => "cisco3" },
        { name => "monitored_by_slave" },
        { name => "opslave" },
    ],
    passive => 0,
    name    => "ClusterA",
    nodes   => [ { host => { name => "opslave" } } ],
    roles       => [ { name => "View some, change some - somehosts" } ],
    uncommitted => 0,
};
$hash = $obj->serialize_to_hash;
is_deeply( $hash, $expected, "Got serialization for ClusterA" )
  || diag( Data::Dump::dump($hash) );

# Synchronise function is currently disabled. Will be enabled in 3.11 as requires DB changes

=begin comment

$obj = $rs->synchronise( {
    id => 1,
    nodes => [ { host => { name => "cisco3" } } ],
    name => "New Master Name",
} );
is( $obj->name, "New Master Name", "Master's name changed" );
is( $obj->host->name, "cisco3", "Host changed to cisco3" );
is( $obj->host->name->monitored_by->id, 1, "cisco3's monitored_by changed to master (was in ClusterA as tested above)");
is( $obj->uncommitted, 1, "Uncommitted flag set" );

$obj = $rs->synchronise( {
    name => "New slave",
    nodes => [ { host => { name => "doesnt_exist_1" } }, { host => { name => "doesnt_exist_2" } } ],
} );
is( $obj->activated, 1, "Is activated" );
is( $obj->nodes->count, 2, "Got two nodes" );
my @nodes = $obj->nodes;
isa_ok( $nodes[0], "Opsview::Schema::Monitoringclusternodes" );
is( $nodes[0]->host->name, "doesnt_exist_1" );
is( $nodes[1]->host->name, "doesnt_exist_2" );


eval { $rs->synchronise( { name => "bad::name" } ) };
is( $@, "name: Invalid\n" );

eval { $rs->synchronise( { name => "NewSlave", role => "Badone" } ) };
is( $@, "blah", "Bad role" );

=cut
