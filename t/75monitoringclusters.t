#!/usr/bin/perl

use Test::More "no_plan";

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Monitoringserver;
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

is( Opsview::Monitoringserver->count_all, 5, "All monitoringservers here" );

my $ms;
eval { $ms = Opsview::Monitoringserver->create( { name => "stuff/here" } ) };
like( $@, "/fails 'regexp' constraint/", "Correctly fails regexp" );

eval { $ms = Opsview::Monitoringserver->create( {} ) };
like( $@, "/Must specify a name to create a new monitoringserver/",
    "Name not set" );

$ms = Opsview::Monitoringserver->create( { name => "createme" } );
isa_ok( $ms, "Opsview::Monitoringserver" );

# Check a host with its monitoring server
my $cisco3 = $schema->resultset("Hosts")->find( { name => "cisco3" } );
is( $cisco3->monitored_by->id, 2, "Currently belongs to slave" );

my $master = Opsview::Monitoringserver->retrieve(1);
is( $master->host->name, "opsview", "Not same as host on slave" );

# Set master monitoring server to be this host
$master->host( $cisco3->id );
$master->update;

# check master cannot be set as passive
$master->passive(1);
$master->update;
is( $master->passive, 0, 'Master cannot be set as passive' );

# Check host has monitoring server changed to the monitoring server
$cisco3->discard_changes;
is( $cisco3->monitored_by->id, 1,
    "Monitoringserver on cisco3 now changed to master"
);

my $slavenode1 = $schema->resultset("Monitoringclusternodes")->find(3);
is( $slavenode1->id,         3,  "Got id" );
is( "$slavenode1",           3,  "And stringifies to id number" );
is( $slavenode1->slave_port, 22, "Got slave port" );
$Settings::slave_initiated = 1;
is( $slavenode1->slave_port, 25803, "Got slave port for reverse ssh tunnels" );

$slavenode1 =
  $schema->resultset("Monitoringclusternodes")
  ->search( { "host.name" => "opslaveclusterC" }, { join => "host" } )->first;
is( $slavenode1->host->id,              21, "Got host id" );
is( $slavenode1->id,                    4,  "Got node id" );
is( $slavenode1->monitoringcluster->id, 3,  "Got monitoring cluster id" );

my $passiveslave =
  $schema->resultset("Monitoringservers")
  ->search( { "name" => "PassiveSlave" } )->first;
is( $passiveslave->passive,    1, "PassiveSlave currently passive" );
is( $passiveslave->passive(0), 0, "PassiveSlave set to not passive" );
is( $passiveslave->passive(1), 1, "PassiveSlave now passive again" );
