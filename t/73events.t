#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";

use Opsview::Test;
use Runtime::Schema;
use DateTime::Format::Strptime;

my $schema = Runtime::Schema->my_connect;

my $rs    = $schema->resultset( "NagiosStatehistory" );
my $total = $rs->count;
is( $total, 9373, "Got all events" );

my $formatter = DateTime::Format::Strptime->new( pattern => "%F %T", );

sub formatter {
    my $dt = shift;
    $dt->set_formatter($formatter);
    $dt->set_time_zone( "America/Chicago" );
    "$dt";
}

my $first = $rs->first;
is( $first->statehistory_id, 1 );
isa_ok( $first->state_time, "DateTime" );
is( $first->state_time,              '2009-07-08T12:31:47' );
is( formatter( $first->state_time ), '2009-07-08 07:31:47' );
is( $first->state_time_usec,         102124 );
is( $first->state_change,            1 );
is( $first->state,                   1 );
is( $first->state_type,              0 );
is( $first->output, "WARNING - load average: 3.03, 1.86, 0.83" );

my $object = $first->object;
isa_ok( $object, "Runtime::Schema::NagiosObjects" );
is( $object->objecttype_id, 2 );
is( $object->name1,         "monitored_by_slave" );
is( $object->name2,         "Check Loadavg" );

#$total = $rs->search( { "hostgroup.matpath"" => { "-like" => { "matpath" => "blah%" } } } )->count;
#is( $total, 54, "Got filter by hostgroup" );

$total =
  $rs->search( { "keywords.keyword" => "cisco" }, { join => "keywords" } )
  ->count;
is( $total, 261, "Got filter by keyword" );

$total =
  $rs->search( { "contacts.contactid" => 1 }, { join => "contacts" } )->count;
is( $total, 832, "Got filter by contact" );

$total =
  $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } )->count;
is( $total, 262, "Got filter by different contact" );

my $max_event_id = $rs->get_column("statehistory_id")->max;
is( $max_event_id, 9373, "Got max statehistory id" );

# Check relationship from hostgroup to events
my $expected = 2529;
my $count;
$count =
  $schema->resultset("Runtime::Schema::OpsviewHostgroups")
  ->search( {},
    { join => { "hostgroup_hosts" => { "host_objects" => "events" } } } )
  ->count;
is( $count, $expected, "Have $expected hostgroups with events" );

# Check relationship from events to hostgroups
$count =
  $schema->resultset("Runtime::Schema::NagiosStatehistory")
  ->search( {}, { join => { "object_hosts" => "hostgroups" } } )->count;
is( $count, $expected,
    "Have $expected events with hostgroups, same the other way"
);

$expected = 843;
$count    = $schema->resultset("Runtime::Schema::NagiosStatehistory")->search(
    { "hostgroups.hostgroup_id" => 1 },
    { join                      => { "object_hosts" => "hostgroups" } },
)->count;
is( $count, $expected, "All events under Opsview hostgroup" );

# Get a different list here due to looking at a different part of hierarchy
$expected = 531;
$count    = $schema->resultset("Runtime::Schema::NagiosStatehistory")->search(
    {
        "hostgroup.matpath" => { "-like" => "Opsview,UK,%" },
        "hostgroup.rgt"     => \"= hostgroup.lft+1",
    },
    { join => { "object_hosts" => { "hostgroups" => "hostgroup" } } },
)->count;
is( $count, $expected, "All events under Opsview,UK, hostgroup" );

my $hostgroup_search =
  $schema->resultset("Runtime::Schema::NagiosStatehistory")->search(
    {
        "hostgroup.matpath" => { "-like" => "Opsview,UK2,Leaf2,%" },
        "hostgroup.rgt"     => \"= hostgroup.lft+1",
    },
    {
        join     => { "object_hosts" => { "hostgroups" => "hostgroup" } },
        order_by => "state_time DESC",
        +select => [ "state_time", "hostgroup.matpath" ],
        +as     => [ "state_time", "matpath" ],
    },
  );
$first = $hostgroup_search->first;
is( $first->state_time,            "2009-07-29T09:05:48" );
is( $first->get_column("matpath"), "Opsview,UK2,Leaf2," );

$count = $hostgroup_search->count;
is( $count, 312, "All events under Opsview,UK2,Leaf2, only hostgroup" );

# This search avoids hostgroups_hosts table
$hostgroup_search =
  $schema->resultset("Runtime::Schema::NagiosStatehistory")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview,UK2,Leaf2,%" }, },
    {
        join     => { "object_hosts" => { "host" => "hostgroup" } },
        order_by => "state_time DESC",
        +select => [ "state_time", "hostgroup.matpath" ],
        +as     => [ "state_time", "matpath" ],
    },
  );

$count = $hostgroup_search->count;
is( $count, 312,
    "All events under Opsview,UK2,Leaf2, hostgroup via a different route"
);

is(
    $schema->resultset("Runtime::Schema::OpsviewHostgroups")->find(1)->matpath,
    "Opsview,"
);

1;
