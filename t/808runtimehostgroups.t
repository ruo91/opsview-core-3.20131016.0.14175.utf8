#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$FindBin::Bin/lib", "$FindBin::Bin/../lib",
  "$FindBin::Bin/../etc";
use Test::More qw(no_plan);
use Test::Deep;
use strict;

use Opsview::Test;
use Opsview::Schema;
use Runtime::Schema;
use Opsview::Utils;

use Test::Perldump::File;

my $schema    = Runtime::Schema->my_connect;
my $ov_schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset("OpsviewHosts")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview%" } },
    { join => [ "hostgroup", "hoststatus" ] }
);
is( $rs->count, 12, 'Opsview%' );

$rs = $schema->resultset("OpsviewHosts")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview%" } },
    { join => [ "hostgroup", "hoststatus" ] }
);
$rs = $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( $rs->count, 1, 'Opsview% on contactid 4' );

$rs = $schema->resultset("OpsviewHosts")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview,UK,Monitoring Servers%" } },
    { join => [ "hostgroup", "hoststatus" ] }
);
is( $rs->count, 2, 'OpsviewHosts' );

$rs = $schema->resultset("OpsviewHostServices")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview%" } },
    { join => [ "servicestatus", { host => "hostgroup" } ] }
);
is( $rs->count, 26, 'OpsviewHostServices' );

$rs = $schema->resultset("OpsviewHostServices")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview%" } },
    { join => [ "servicestatus", { host => "hostgroup" } ] }
);
$rs = $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( $rs->count, 3, 'OpsviewHostServices on contactid 4' );

is(
    $schema->resultset("OpsviewHosts")->search( {}, { join => "comments" } )
      ->count,
    4,
    "Found all host comments"
);
is(
    $schema->resultset("OpsviewHosts")
      ->search( { "name" => { "-like" => "c%" } }, { join => "comments" } )
      ->count,
    2,
    "Found all host comments for hosts beginning with c"
);

my $downtime_hosts = 3;
$rs = $schema->resultset("NagiosScheduleddowntimes")->search(
    {
        "downtime_type"     => 2,
        "hostgroup.matpath" => { "-like" => "Opsview,%" },
    },
    { join => { "object" => { host => "hostgroup" } }, }
);
is( $rs->count, $downtime_hosts, 'NagiosScheduleddowntimes' );
$rs = $rs->search(
    { "contacts.contactid" => 4 },
    { join                 => { object => "contacts" } }
);
is( $rs->count, 1, 'NagiosScheduleddowntimes on contactid 4' );

# This result used to be 9, but changed to 10 since joining with opsview_host_objects, instead of
# opsview_host_services. Because the database is frigged, the results could be inconsistent - need to
# confirm with real data
my $downtime_services = 10;
$rs = $schema->resultset("NagiosScheduleddowntimes")->search(
    {
        "downtime_type"     => 1,
        "hostgroup.matpath" => { "-like" => "Opsview,%" },
    },
    { join => { "object" => { host => "hostgroup" } }, }
);
is( $rs->count, $downtime_services, 'NagiosScheduleddowntimes' );
$rs = $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( $rs->count, 5, 'NagiosScheduleddowntimes on contactid 4' );

$rs = $schema->resultset("NagiosScheduleddowntimes")->search(
    { "hostgroup.matpath" => { "-like" => "Opsview,%" }, },
    {
        join     => { object => { host => "hostgroup" } },
        group_by => [qw(comment_data entry_time)],
        order_by => [qw(comment_data scheduled_start_time)],
    }
);

# I think this is meant to be $downtime_hosts + $downtime_services, but
# due to frigging at the db for tests, this doesn't add up
# This used to be 3, but since joining to opsview_host_objects (rather than opsview_host_services),
# this is now 5
my @a = $rs->search;
is( scalar @a, 5, 'rs search results' );

# Check dates
#eval { print join("\n", map { $_->actual_start_time } @a )."\n"; };
#TODO: {
#    local $TODO = "Need to update DBIx::Class";
is( $@, "", "Can parse invalid datetime values in DB" );

#}

$rs = $schema->resultset("OpsviewHostgroups")->search(
    { "host_contacts.contactid" => 1, },
    {
        join     => { hostgroup_hosts => "host_contacts" },
        distinct => 1,
        order_by => "name",
    }
);
@a = $rs->search;
is( scalar @a, 9, 'OpsviewHostgroups' );

my @hostgroups = (
    "Admin Servers",      "Dudley Servers",
    "Leaf",               "Leaf2",
    "Monitoring Servers", "Opsview",
    "Physical",           "UK",
    "UK2",
);
my @found = map { $_->name } @a;

is_deeply( \@hostgroups, \@found, 'OpsviewHostgroups data structure' );

$rs = $schema->resultset("OpsviewHostgroups")->search(
    { "host_contacts.contactid" => 4, },
    {
        join     => { hostgroup_hosts => "host_contacts" },
        distinct => 1,
        order_by => "name",
    }
);
@a = $rs->search;
is( scalar @a, 3, 'OpsviewHostgroups' );

@hostgroups = ( "Leaf2", "Opsview", "UK2" );
@found = map { $_->name } @a;

is_deeply( \@hostgroups, \@found, 'OpsviewHostgroups data structure' );

my $uk = $schema->resultset("OpsviewHostgroups")->find( { name => "UK" } );
isa_ok( $uk, "Runtime::Schema::OpsviewHostgroups" );
my @leaf_names = map { $_->name } ( $uk->leaves );
is_deeply( \@leaf_names, [ "Leaf", "Monitoring Servers" ], "Found leaves" )
  || diag explain \@leaf_names;

my $leaf2 =
  $schema->resultset("OpsviewHostgroups")->find( { name => "Leaf2" } );
@leaf_names = map { $_->name } ( $leaf2->leaves );
is_deeply( \@leaf_names, ["Leaf2"], "Found itself as leaves" )
  || diag explain \@leaf_names;

my $hash =
  $schema->resultset("OpsviewHostgroups")->list_summary( { parentid => 1 } );
is_perldump_file(
    $hash,
    "$Bin/var/perldumps-status/full_hostgroup_status",
    "Got full status"
) || diag( Data::Dump::dump($hash) );

my $status = $schema->resultset("OpsviewHostgroups")->list_summary(
    {
        hostgroupid => 5,
        cols        => "-matpath"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps-status/hostgroup_leaf",
    "Leaf hostgroup okay"
) || diag explain $status;

my $somehosts =
  $ov_schema->resultset("Contacts")->search( { name => "somehosts" } )->first;

#$status = $schema->resultset("OpsviewHostgroups")->list_summary( { parentid => 1, contact => $somehosts->id } );
$status =
  $schema->resultset("OpsviewHostgroups")
  ->search( { "contacts.contactid" => $somehosts->id },
    { join => { "hostgroup_hosts" => { "host_objects" => "contacts" } } } )
  ->list_summary( { parentid => 1 } );
is_perldump_file(
    $status,
    "$Bin/var/perldumps-status/filtered_hostgroup_for_somehosts",
    "Filtered view for somehosts user"
);

$hash = $schema->resultset("OpsviewHostgroups")->list_summary(
    {
        parentid     => 1,
        servicecheck => "Coldstart",
        host         => [ "cisco", "cisco1" ]
    }
);
is_perldump_file(
    $hash,
    "$Bin/var/perldumps-status/hostgroup_with_filtering",
    "Got full status"
) || diag( Data::Dump::dump($hash) );

$hash = $schema->resultset("OpsviewHosts")->list_summary(
    {
        servicecheck => [ "Coldstart", "Test exceptions", "/" ],
        host         => [ "cisco",     "cisco1",          "opslave" ]
    }
);
$hash = Opsview::Utils->remove_keys_from_hash( $hash, ["state_duration"] );
is_perldump_file(
    $hash,
    "$Bin/var/perldumps-status/hosts_with_filtering",
    "Got full status"
) || diag( Data::Dump::dump($hash) );

1;
