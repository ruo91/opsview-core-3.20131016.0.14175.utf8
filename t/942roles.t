#!/usr/bin/perl
# Tests for Opsview::Schema and the roles and access

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Config;
use Opsview::Test qw(opsview);
use utf8;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Contacts" );

my $tests;

$tests = {
    "admin" =>
      "ACTIONALL,ADMINACCESS,CONFIGURECONTACTS,CONFIGUREHOSTGROUPS,CONFIGUREHOSTS,CONFIGUREKEYWORDS,CONFIGUREPROFILES,CONFIGUREROLES,CONFIGURESAVE,CONFIGUREVIEW,DOWNTIMEALL,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RELOADACCESS,REPORTADMIN,REPORTUSER,RRDGRAPHS,TESTALL,TESTCHANGE,VIEWALL,VIEWPORTACCESS",
    "readonly" => "NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,VIEWALL",
    "nonadmin" =>
      "ACTIONSOME,CONFIGUREHOSTS,CONFIGURESAVE,DOWNTIMESOME,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,TESTSOME,VIEWSOME",
    "testviewallchangesome" =>
      "ACTIONSOME,DOWNTIMESOME,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,TESTSOME,VIEWALL",
    "testviewallchangenone" =>
      "NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,VIEWALL",
    "somehosts" =>
      "ACTIONSOME,CONFIGUREHOSTS,CONFIGURESAVE,DOWNTIMESOME,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,TESTSOME,VIEWSOME",
    "onlyunknowns" =>
      "ACTIONSOME,CONFIGUREHOSTS,CONFIGURESAVE,DOWNTIMESOME,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RRDGRAPHS,TESTSOME,VIEWSOME",
};

plan 'no_plan';

foreach my $username ( keys %$tests ) {
    my $u = $rs->search( { name => $username } )->first;
    is( $u->access_list, $tests->{$username},
        "$username with right access list"
    );
}

my $user = $rs->search( { name => "nonadmin" } )->first;
ok( $user->has_access("ACTIONSOME"), "Nonadmin user has ACTIONSOME" );
ok( $user->has_access("NOTIFYSOME"), "...and NOTIFYSOME" );
ok( !$user->has_access("ACTIONALL"), "...but not ACTIONALL" );
ok( !$user->has_access("VIEWALL"),   "...neither VIEWALL" );
ok( $user->has_access( "ACTIONALL",  "ACTIONSOME" ), "Okay here with OR" );
ok( $user->has_access( "ACTIONSOME", "ACTIONALL" ),  "and vice versa" );
ok( !$user->has_access( "ACTIONALL", "VIEWALL" ), "but fails if neither" );

my @a;
@a = sort map { $_->username } ( $rs->all_with_access("VIEWALL") );
is_deeply( \@a,
    [ "admin", "readonly", "testviewallchangenone", "testviewallchangesome" ]
);

@a = sort map { $_->username } ( $rs->all_with_access("ACTIONSOME") );
is_deeply( \@a,
    [ "nonadmin", "onlyunknowns", "somehosts", "testviewallchangesome" ] )
  || diag explain \@a;

my $roles = $schema->resultset( "Roles" );
my @actual_roles = map { $_->name } @{ $roles->actual_roles_arrayref };
is_deeply(
    \@actual_roles,
    [
        "Admin",
        "View all, change some",
        "View all, change none",
        "View some, change some",
        "View some, change some - somehosts",
        "View some, change none",
        "View some, change none - viewsomechangenone",
        'Admin no configurehosts',
        'demorole',
        'Keywordonly',
        'View some, change none, no notify',
        "View some, change none, no notify - viewsomechangenonewonotify",
    ],
    "Got non-system roles"
) || diag explain \@actual_roles;

# These tests make changes to test db
$schema->resultset("Access")->search( { name => "VIEWALL" } )->delete_all;
my $admin = $rs->search( { name => "admin" } )->first;
is(
    $admin->access_list,
    "ACTIONALL,ADMINACCESS,CONFIGURECONTACTS,CONFIGUREHOSTGROUPS,CONFIGUREHOSTS,CONFIGUREKEYWORDS,CONFIGUREPROFILES,CONFIGUREROLES,CONFIGURESAVE,CONFIGUREVIEW,DOWNTIMEALL,NAGVIS,NOTIFYSOME,PASSWORDSAVE,RELOADACCESS,REPORTADMIN,REPORTUSER,RRDGRAPHS,TESTALL,TESTCHANGE,VIEWPORTACCESS",
    "Removed access still works with role and contact"
);

# This doesn't make sense to do, as a contact has 1 role, so this delete will fail
#$schema->resultset("Roles")->search( { name => "Admininistrator" } )->delete;

#$tests = {
#	"admin" => "",
#	"readonly" => "NOTIFYSOME",
#	"nonadmin" => "ACTIONSOME,CONFIGUREHOSTS,NOTIFYSOME,VIEWSOME",
#	"testviewallchangesome" => "ACTIONSOME,NOTIFYSOME",
#	"testviewallchangenone" => "NOTIFYSOME",
#	"somehosts" => "ACTIONSOME,CONFIGUREHOSTS,NOTIFYSOME,VIEWSOME",
#	"onlyunknowns" => "ACTIONSOME,CONFIGUREHOSTS,NOTIFYSOME,VIEWSOME",
#};
#foreach my $username (keys %$tests) {
#	my $u = $rs->search( username => $username )->first;
#	is( $u->access_list, $tests->{$username}, "$username with right access list" );
#}

# Only 1 monitoringserver in Core
my $ms = $schema->resultset("Monitoringservers")->find(2);
is( $ms->roles->count, 1 );

eval { $ms->delete };
like(
    $@,
    qr/Cannot delete or update a parent row: a foreign key constraint fails/,
    "A delete of the monitoringserver is blocked"
);

my $roles_rs = $schema->resultset( "Roles" );
$roles_rs->synchronise(
    {
        id                => 1,
        name              => "roleupdate",
        description       => "Updated role",
        accesses          => [ 9, 10, 11, 7 ],
        monitoringservers => [2],
    }
);
my $role = $schema->resultset("Roles")->search( { id => 1 } )->first;
is( $role->name,        "roleupdate" );
is( $role->description, "Updated role" );
my @monitoringservers = map { $_->id } $role->monitoringservers;
is_deeply( \@monitoringservers, [2], "Monitoringservers set" );
my @accessids = sort { $a <=> $b } map { $_->id } $role->accesses;
is_deeply( \@accessids, [ 7, 9, 10, 11 ], "Access ids changed" );

$roles_rs->synchronise(
    {
        id       => 1,
        accesses => [],
    }
);
@accessids = $role->accesses;
is_deeply( \@accessids, [], "Access ids deleted" );

# Check can remove monitoringservers from the role
eval { $roles_rs->synchronise( { id => 1, monitoringservers => [], } ); };
is( $@,                       "", "No errors" );
is( $role->monitoringservers, 0,  "Zero monitoringservers okay" );

# Check that a monitoringserver delete will be constrained
eval { $ms->delete };
like(
    $@,
    qr/Cannot delete or update a parent row: a foreign key constraint fails/,
    "A delete of the monitoringserver is blocked"
);

my $new_role = $roles_rs->synchronise(
    {
        name              => "new role",
        description       => "Anything fancy",
        accesses          => [ 4, 2 ],
        monitoringservers => [2],
        hostgroups        => [ 4, 6 ],
    }
);
is( $new_role->name,        "new role" );
is( $new_role->description, "Anything fancy" );
@accessids = sort { $a <=> $b } map { $_->id } $new_role->accesses;
is_deeply( \@accessids, [ 2, 4 ] );
@monitoringservers = map { $_->id } $new_role->monitoringservers;
is_deeply( \@monitoringservers, [2], "Monitoringservers also saved" );
my @hostgroups = map { $_->id } $new_role->hostgroups;
is_deeply( \@hostgroups, [ 4, 6 ], "Hostgroups created" );
my @matpaths = map { $_->matpath } $new_role->hostgroups;
is_deeply(
    \@matpaths,
    [ "Opsview,UK,Leaf,", "Opsview,UK2," ],
    "Got materialized paths"
);

eval { $roles_rs->synchronise( { id => $new_role->id, name => "bad: name" } ) };
like( $@, qr/Failed constraint on name for /, "name constraint is triggered" );

$new_role = $roles_rs->synchronise(
    {
        name        => "another new role",
        description => "Anything fancy"
    }
);
is( $new_role->name,        "another new role" );
is( $new_role->description, "Anything fancy" );
@accessids = map { $_->id } $new_role->accesses;
is_deeply( \@accessids, [], "Empty accesses works as expected" );

$new_role->delete;
$new_role =
  $schema->resultset("Roles")->search( { name => "another new role" } )->first;
is( $new_role, undef );

my $uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
$uncommitted_flag->update( { value => 0 } );
is( $uncommitted_flag->value, 0, "Uncommitted" );

# Check can set monitoringservers
$new_role = $roles_rs->synchronise(
    {
        name              => "another new role",
        accesses          => [ 4, 2, 7 ],
        monitoringservers => 2,
    }
);
is( $new_role->name, "another new role" );
@monitoringservers = map { $_->id } $new_role->monitoringservers;
is_deeply( \@monitoringservers, [2], "Monitoringservers set correctly" );

undef $uncommitted_flag;
$uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
is( $uncommitted_flag->value, 1, "Uncommitted flag changed" );

$uncommitted_flag->update( { value => 0 } );

$uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
is( $uncommitted_flag->value, 0, "Uncommitted flag reset again" );

$new_role->delete;

$uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
is( $uncommitted_flag->value, 1, "Uncommitted flag changed due to deletion" );

my $validation = $schema->resultset("Roles")->validation_regexp;
my $v_expected = {
    name       => '/^[\\w ,-]+$/',
    name_error => undef,
};
is_deeply( $validation, $v_expected, "Validation as expected" );
