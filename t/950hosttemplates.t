#!/usr/bin/perl
# Tests for Opsview::ResultSet::Hosttemplates

use Test::More qw(no_plan);

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);

my $schema = Opsview::Schema->my_connect;

my $obj;
my $rs = $schema->resultset( "Hosttemplates" );

$obj = $rs->find(1);
isa_ok( $obj, "Opsview::Schema::Hosttemplates" );

is( $obj->hosts->count,         9, );
is( $obj->servicechecks->count, 5 );

@_ = $obj->managementurls;
is( $_[0]->name, "SSH",                    "Got name" );
is( $_[0]->url,  'ssh://$HOSTADDRESS$',    "Got url" );
is( $_[1]->name, "Telnet",                 "Got name" );
is( $_[1]->url,  'telnet://$HOSTADDRESS$', "Got url" );

is( $rs->search( { name => "NewHT" } )->count, 0 );

$rs->synchronise( { name => "NewHT" } );

is( $rs->search( { name => "NewHT" } )->count, 1 );

$obj = $rs->find( { name => "NewHT" } );
is( $obj->uncommitted, 1, "Check uncommitted flag set" );

$rs->synchronise(
    {
        name        => "NewHT",
        description => "New host template",
        hosts       => [
            { name => "cisco" },
            { name => "doesnt_exist_1" },
            { name => "fake_ipv6" },
        ],
        servicechecks => [
            { name => "AFS" },
            {
                name      => "IRC",
                exception => "--except IRC"
            },
            { name => "C Drive" },
            {
                name      => "DHCP",
                exception => "--except"
            },
            { name => "Disk Queue" },
            {
                name            => "CORBA",
                timed_exception => {
                    args       => "--timed CORBA",
                    timeperiod => 1
                }
            },
            {
                name            => "Events",
                timed_exception => {
                    args       => "-t events",
                    timeperiod => { name => "none" }
                }
            },
            {
                name          => "G Drive",
                event_handler => "event g drive"
            },
        ],
        managementurls => [
            {
                name => "SSH",
                url  => "ssh://127.0.0.1"
            },
            {
                name => "web",
                url  => "http://127.0.0.1:80"
            },
        ],
    }
);
$obj = $rs->find( { name => "NewHT" } );
is( $obj->description, "New host template" );
@_ = $obj->managementurls;
is( scalar @_, 2 );
is( $_[0]->name, "SSH",                 "Got name" );
is( $_[0]->url,  'ssh://127.0.0.1',     "Got url" );
is( $_[1]->name, "web",                 "Got name" );
is( $_[1]->url,  'http://127.0.0.1:80', "Got url" );
my $old_url_id = $_[1]->id;

$obj = $rs->synchronise(
    {
        name           => "NewHT",
        managementurls => [
            {
                name => "web",
                url  => "http://127.0.0.1:80"
            },
        ],
    }
);
@_ = $obj->managementurls;
is( scalar @_, 1 );
is( $_[0]->name, "web",                 "Got name" );
is( $_[0]->url,  'http://127.0.0.1:80', "Got url" );
is( $_[0]->id,   $old_url_id, );

my $expected = {
    description => "New host template",
    hosts       => [
        { name => "cisco" },
        { name => "doesnt_exist_1" },
        { name => "fake_ipv6" },
    ],
    id             => 9,
    managementurls => [
        {
            name => "web",
            url  => "http://127.0.0.1:80"
        }
    ],
    name          => "NewHT",
    servicechecks => [
        {
            name            => "AFS",
            exception       => undef,
            timed_exception => undef
        },
        {
            name            => "C Drive",
            exception       => undef,
            timed_exception => undef
        },
        {
            name            => "CORBA",
            exception       => undef,
            timed_exception => {
                args       => "--timed CORBA",
                timeperiod => { name => "24x7" }
            }
        },
        {
            name            => "DHCP",
            exception       => "--except",
            timed_exception => undef
        },
        {
            name            => "Disk Queue",
            exception       => undef,
            timed_exception => undef
        },
        {
            name            => "Events",
            exception       => undef,
            timed_exception => {
                args       => "-t events",
                timeperiod => { name => "none" }
            }
        },
        {
            name            => "G Drive",
            exception       => undef,
            timed_exception => undef
        },
        {
            name            => "IRC",
            exception       => "--except IRC",
            timed_exception => undef
        },
    ],
    uncommitted => 1,
};
my $h = $obj->serialize_to_hash;
is_deeply( $h, $expected, "Got serialization" )
  || diag( Data::Dump::dump($h) );

# Test the smart_hosttemplate_removal flag
my $host_opsview = $schema->resultset("Hosts")->find(1);
is( $host_opsview->name,                 "opsview", "Got opsview host" );
is( $host_opsview->hosttemplates->count, 1,         "Got one host template" );
is( $host_opsview->hosttemplates->first->name, "Blank", "Called blank" );

my $host_resolved_services = $schema->resultset("Hosts")->find(6);
is(
    $host_resolved_services->name,
    "resolved_services", "Got resolved_services host"
);
is(
    $host_resolved_services->hosttemplates->search( { name => "Base Unix" } )
      ->count,
    1,
    "Does have base unix host template"
);
my @hosttemplate_names_in_order =
  map { $_->name } $host_resolved_services->hosttemplates;
my $expected_hosttemplates = [
    "Base Unix",
    "Template to get removed 1st",
    "Template to get removed 2nd",
    "Cisco Mgt",
];
is_deeply(
    \@hosttemplate_names_in_order,
    $expected_hosttemplates, "Got templates in order"
);

$obj = $rs->synchronise(
    {
        name  => "Base Unix",
        hosts => [
            { name => "resolved_services" },
            { name => "monitored_by_cluster" },
            { name => "monitored_by_slave" },
            { name => "opslave" },
            { name => "opsview" },             # This is an addition
        ],
    }
);
@hosttemplate_names_in_order =
  map { $_->name } $host_resolved_services->hosttemplates;
is_deeply( \@hosttemplate_names_in_order,
    $expected_hosttemplates,
    "Checking that the order hasn't changed after a save" )
  || diag explain \@hosttemplate_names_in_order;

# Host opsview is an addition
# Host resolved_services is a removal. Check that AFS, Check Loadavg are removed, but Check Memory isn't (because also in "Cisco Mgt")
$schema->resultset("Systempreferences")->find(1)
  ->update( { smart_hosttemplate_removal => 1 } );
$obj = $rs->synchronise(
    {
        name  => "Base Unix",
        hosts => [
            { name => "monitored_by_cluster" },
            { name => "monitored_by_slave" },
            { name => "opslave" },
            { name => "opsview" },             # This is an addition
        ],
    }
);

is(
    $obj->hosts->search( { name => "opsview" } )->count,
    1, "Does have opsview host now"
);
is( $host_opsview->hosttemplates->count, 2, "..and same other way" );
is(
    $host_opsview->hosttemplates->first->name,
    "Blank", "First one still called blank"
);

is(
    $obj->hosts->search( { name => "resolved_services" } )->count,
    0, "No resolved_services"
);
is(
    $host_resolved_services->hosttemplates->search( { name => "Base Unix" } )
      ->count,
    0,
    "...And same other way around"
);
is(
    $host_resolved_services->servicechecks->search( { name => "AFS" } )->count,
    1,
    "AFS should not be removed as wasn't on host template"
);
is(
    $host_resolved_services->servicechecks->search(
        { name => "Check Loadavg" }
      )->count,
    0,
    "As should Check Loadavg"
);
is(
    $host_resolved_services->servicechecks->search(
        { name => "Check Memory" }
      )->count,
    1,
    "But Check Memory should stay"
);

$schema->resultset("Systempreferences")->find(1)
  ->update( { smart_hosttemplate_removal => 0 } );
my $host_monitored_by_slave = $schema->resultset("Hosts")->find(4);
is( $host_monitored_by_slave->name, "monitored_by_slave" );
is(
    $host_monitored_by_slave->servicechecks( { name => "Check Loadavg" } )
      ->count,
    1,
    "Has Check Loadavg"
);
$obj = $rs->synchronise(
    {
        name  => "Base Unix",
        hosts => [
            { name => "monitored_by_cluster" },
            { name => "opslave" },
            { name => "opsview" },
        ],
    }
);
is(
    $host_monitored_by_slave->servicechecks( { name => "Check Loadavg" } )
      ->count,
    1,
    "Still has it after a host template change"
);

eval { $rs->synchronise( { name => "bad::name" } ) };
is( $@, "name: Invalid\n" );

1;
