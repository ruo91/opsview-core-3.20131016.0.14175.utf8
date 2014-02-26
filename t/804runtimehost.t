#!/usr/bin/perl

use Test::More qw(no_plan);

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Host;
use Runtime::Hostgroup;
use Opsview::Test;
use Runtime::Schema;

my $schema = Runtime::Schema->my_connect;
my $dbh    = Runtime->db_Main;

my $opsview = Runtime::Host->search( name => "opsview" )->first;
isa_ok( $opsview, "Runtime::Host", "Found opsview host" );

my $hostgroup = $opsview->hostgroup;
isa_ok( $hostgroup, "Runtime::Hostgroup", "Found opsview's hostgroup" );
is( $hostgroup->name, "Monitoring Servers", "And is the right one" );

is( $opsview->hostgroup->name, "Monitoring Servers", "Same from object" );

my $config_object = $opsview->configuration_host_object;
isa_ok( $config_object, "Opsview::Schema::Hosts" );
is( $config_object->name,         "opsview" );
is( $config_object->snmp_version, "2c" );

my $deleted_opsview_host =
  Runtime::Host->search( name => "missing_from_configuration" )->first;
isa_ok( $deleted_opsview_host, "Runtime::Host" );
$config_object = $deleted_opsview_host->configuration_host_object;
is( $config_object, undef, "Host does not exist in configuration table" );

my $dbix_host =
  $schema->resultset("OpsviewHosts")->find( { name => "doesnt_exist_1" } );

is( $dbix_host->hoststatus->output,        "", "Empty output in test db" );
is( $dbix_host->hoststatus->current_state, 1,  "Right state" );

my @services = $dbix_host->host_services( {}, { order_by => "servicename" } );
is( scalar @services, 2, "All services" );
is( $services[0]->servicename,           "faked ok service" );
is( $services[1]->servicename,           "TCP/IP" );
is( $services[0]->servicestatus->output, "faked ok result" );
is( $services[1]->servicestatus->output, "forced result" );

@services = $schema->resultset("OpsviewHostServices")->search(
    { servicename => "TCP/IP", },
    {
        order_by => "hostname",
        prefetch => "servicestatus",
    }
);
is( scalar @services, 3, "All TCP/IP services" );
is( $services[0]->hostname, "cloned2" );
is( $services[1]->hostname, "doesnt_exist_1" );
is( $services[2]->hostname, "doesnt_exist_2" );

is(
    $services[0]->servicestatus->output,
    "check_ping: Invalid hostname/address - hostname1"
);

@services = $schema->resultset("OpsviewHostServices")->search(
    {
        host_object_id => 120,
        servicename    => { "-like" => "%r exce%" },
    },
    { prefetch => "servicestatus", }
);
is( scalar @services, 1, "One service" );
is( $services[0]->hostname,    "cisco4" );
is( $services[0]->servicename, "Another exception" );
is( $services[0]->servicestatus->current_state, 3, "Unknown" );
is( $services[0]->servicestatus->output, "forced result" );

my $rs = $schema->resultset("OpsviewHosts")->search(
    {},
    {
        order_by => "name",
        columns  => ["name"],
    }
);
$rs = $rs->search( { "contacts.contactid" => 1 }, { join => "contacts" } );
is( $rs->first->name, "cisco" );
is( $rs->count, 13, "Got all host objects for admin" );

$rs = $schema->resultset("OpsviewHosts")->search(
    {},
    {
        order_by => "name",
        columns  => ["name"],
    }
);
$rs = $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( $rs->first->name, "monitored_by_cluster" );
is( $rs->count, 2, "Got all host objects for somehosts" );

$rs =
  $schema->resultset("OpsviewHostServices")
  ->search( {}, { group_by => "servicename" } );
is( $rs->count, 21 );
$rs = $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( $rs->count, 5 );

$rs =
  $schema->resultset("OpsviewHosts")->related_resultset("configuration_host")
  ->search(
    {
        enable_snmp => 1,
        use_mrtg    => 1
    },
  );
is( $rs->count, 4, "Can get objects, joined with opsview.hosts" );
my @names = map { $_->name } ( $rs->all );
is_deeply(
    \@names,
    [qw(monitored_by_cluster monitored_by_slave opsviewdev1 opsviewdev46)],
    "Got all hosts"
) || diag explain \@names;
is( $rs->first->monitored_by->name, "Cluster" );
