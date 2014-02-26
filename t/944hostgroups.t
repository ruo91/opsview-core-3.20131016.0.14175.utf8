#!/usr/bin/perl
# Tests for Opsview::Schema hostgroups

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use utf8;

use Data::Dump qw(dump);

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Hostgroups" );

my $tests;
my $expected;

is( $rs->count, 10 );

is(
    $rs->search_leaves_without_hosts->first->id,
    9,
    "Finds the first host group without any hosts in, for adding a new host group into"
);

# Count number of hosts
is(
    $rs->find( { name => "leaf" } )->count_related("hosts"),
    10, "Found all related hosts"
);

# This checks that the somehosts contact gets the appropriate list of host groups
# This is used in events view
my $filtered = $rs->search(
    { "role_access_hostgroups.roleid" => 18 },
    { join                            => "role_access_hostgroups" }
);

is( $filtered->count,       1 );
is( $filtered->first->name, "Leaf2" );

my @default_order_hgs =
  map { $_->name } ( $rs->search( {}, { columns => "name" } ) );
$expected = [
    "alphaearly",         "Leaf",    "Leaf2",              "middling",
    "Monitoring Servers", "Opsview", "Passive Monitoring", "singlehost",
    "UK",                 "UK2"
];
is_deeply( \@default_order_hgs, $expected, "Got default order" )
  || diag( dump( \@default_order_hgs ) );

my @ordered_by_dependencies_hgs = map { $_->name } (
    $rs->search(
        {},
        {
            order_by => \"LENGTH(matpath)",
            columns  => "name"
        }
    )
);
$expected = [
    "Opsview", "UK", "UK2", "Leaf", "Leaf2", "singlehost", "alphaearly",
    "middling",
    "Passive Monitoring",
    "Monitoring Servers"
];
is_deeply( \@ordered_by_dependencies_hgs,
    $expected, "Got order by dependencies" )
  || diag( dump( \@ordered_by_dependencies_hgs ) );

my $admin =
  $schema->resultset("Contacts")->search( { name => "admin" } )->first;
my $somehosts =
  $schema->resultset("Contacts")->search( { name => "somehosts" } )->first;

# Use middling as a hostgroup that will be in the middle of the list
$rs->user($admin);
my @hgs = map { $_->name } @{ $rs->restricted_leaves_arrayref };
is_deeply(
    \@hgs,
    [
        "alphaearly",         "Leaf",
        "Leaf2",              "middling",
        "Monitoring Servers", "Passive Monitoring",
        "singlehost"
    ],
    "Got hostgroup leaves for admin"
);

$rs->user($somehosts);
@hgs = map { $_->name } @{ $rs->restricted_leaves_arrayref };
is_deeply(
    \@hgs,
    [ "Leaf2", "middling", "singlehost" ],
    "Got hostgroup leaves for somehosts"
);

my @results = $rs->search_by_tree;
my $listref = \@results;
isa_ok( $listref->[0], "Opsview::Schema::Hostgroups" );
is( $listref->[0]->name, "> Opsview" );
is( $listref->[0]->id,   1 );

is( $listref->[1]->name, "-> alphaearly" );
is( $listref->[1]->id,   9 );

is( $listref->[2]->name, "-> Passive Monitoring" );
is( $listref->[2]->id,   10 );

is( $listref->[3]->name, "-> singlehost" );
is( $listref->[3]->id,   7 );

is( $listref->[4]->name, "-> UK" );
is( $listref->[4]->id,   3 );

is( $listref->[5]->name, "--> Leaf" );
is( $listref->[5]->id,   4 );

is( $listref->[6]->name, "--> Monitoring Servers" );
is( $listref->[6]->id,   2 );

is( $listref->[7]->name, "-> UK2" );
is( $listref->[7]->id,   6 );

is( $listref->[8]->name, "--> Leaf2" );
is( $listref->[8]->id,   5 );

my $obj;
my $hash;
$obj      = $rs->find(5);
$expected = {
    hosts => [
        { name => "monitored_by_cluster" },
        { name => "monitored_by_slave" },
        { name => "resolved_services" },
        { name => "toclone" },
    ],
    id      => 5,
    is_leaf => 1,
    name    => "Leaf2",
    parent  => {
        name    => "UK2",
        matpath => "Opsview,UK2,"
    },
    children    => [],
    matpath     => "Opsview,UK2,Leaf2,",
    uncommitted => 0,
};
$hash = $obj->serialize_to_hash;
is_deeply( $hash, $expected, "Got hostgroup leaf" )
  || diag( Data::Dump::dump($hash) );

$obj      = $rs->find(6);
$expected = {
    hosts  => [],
    id     => 6,
    name   => "UK2",
    parent => {
        name    => "Opsview",
        matpath => "Opsview,"
    },
    children    => [ { name => "Leaf2" }, { name => "middling" }, ],
    is_leaf     => 0,
    matpath     => "Opsview,UK2,",
    uncommitted => 0,
};
$hash = $obj->serialize_to_hash;
is_deeply( $hash, $expected, "Got host group for something in the middle" )
  || diag( Data::Dump::dump($hash) );

is( $rs->search( { name => "NewHG" } )->count, 0 );
$rs->synchronise( { name => "NewHG" } );

is(
    $rs->search( { name => "NewHG" } )->count,
    1, "Got newly created host group"
);

$obj = $rs->find( { name => "NewHG" } );
is( $obj->uncommitted, 1, "Uncommitted" );
is( $obj->parent->id,  1, "Default parent is top level" );
is( $obj->lft,         4, "lft generated" );
is( $obj->rgt,         5, "rgt generated" );
is( $obj->matpath,     "Opsview,NewHG," );

# Check for wiki info
$obj = $rs->find(9);
is(
    $obj->information,
    "= Host group info =\r\nLeisure &gt; Business",
    "Found wiki info"
);

# Can set new parent
$obj = $rs->synchronise(
    {
        name   => "NewChild",
        parent => { name => "NewHG" },
        hosts  => [ { name => "monitored_by_cluster" }, ],
    }
);
is( $obj->name,         "NewChild", "Got new host group child" );
is( $obj->parent->name, "NewHG",    "Got parent as specified" );
is( $obj->parent->lft,  4 );
is( $obj->parent->rgt,  7 );
is( $obj->hosts->count, 0,          "No hosts created" );
is( $obj->lft,          5,          "lft generated" );
is( $obj->rgt,          6,          "rgt generated" );
is( $obj->matpath, "Opsview,NewHG,NewChild," );

$rs->find( { name => "NewHG" } )->delete;
$obj->discard_changes;
is( $obj->parent->id, 1, "Deleted hostgroup's children inherit parent" );
is( $obj->lft,        4, "lft changed" );
is( $obj->rgt,        5, "rgt changed" );
is( $obj->matpath, "Opsview,NewChild," );

eval {
    $rs->synchronise(
        {
            id     => $obj->id,
            parent => { name => "NewChild" }
        }
    );
};
like(
    $@,
    qr/Cannot have parent id same as id/,
    "Can't set parent id to be self"
);

eval { $rs->synchronise( { id => $obj->id, parent => { name => "Leaf" } } ) };
like(
    $@,
    qr/Cannot set parent if parent already has hosts associated/,
    "Can't set parent if parent already has hosts associated"
);

# Can't delete hostgroup id 1
eval { $rs->find(1)->delete };
like(
    $@,
    qr/Cannot delete top level hostgroup/,
    "Cannot delete top level host group"
);

eval { $obj->update( { name => "Leaf" } ) };
like(
    $@,
    qr/Host group name Leaf has already been used for a leaf/,
    "Cannot rename to same as other leaf name"
);

my $uk2 = $rs->find( { name => "UK2" } );
eval { $uk2->update( { name => "UK" } ) };
like(
    $@,
    qr/Same host group name 'UK' used with same parent - this is invalid/,
    "Cannot rename a host to same as other host group at same level"
);

$uk2->update( { name => "UK2" } );
is( $uk2->name, "UK2", "Still UK2 and no error" );

eval { $rs->synchronise( { id => 6, name => "UK" } ) };
like(
    $@,
    qr/Same host group name 'UK' used with same parent - this is invalid/,
    "Cannot set host group name to same as another with same parent"
);

eval { $rs->synchronise( { id => 1, name => "bad,chars" } ) };
is( $@, "name: Invalid\n", "Validation error" );

# Check that deletion of host group with a comment is okay
my $with_comment = $rs->find( { name => "alphaearly" } );
is( $with_comment->id, 9, "Got hostgroup id 9" );
like(
    $with_comment->info->information,
    qr/= Host group info =/,
    "Got wiki comments"
);
$with_comment->delete;

is( $rs->find(9), undef, "Host group deleted" );

done_testing;
