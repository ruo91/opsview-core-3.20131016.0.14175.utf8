#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";

use Opsview;
use Opsview::Host;
use Opsview::Hostgroup;
use Opsview::Schema;
use Opsview::Test;

sub witter {
    diag(@_) if ( $ENV{TEST_VERBOSE} );
}

plan tests => 34;

my $schema = Opsview::Schema->my_connect;

my $admin =
  $schema->resultset("Contacts")->search( { name => "admin" } )->first;
my $non_admin =
  $schema->resultset("Contacts")->search( { name => "nonadmin" } )->first;
my $somehosts =
  $schema->resultset("Contacts")->search( { name => "somehosts" } )->first;
my $readonly =
  $schema->resultset("Contacts")->search( { name => "readonly" } )->first;

isa_ok( $admin,     "Opsview::Schema::Contacts", "admin contact found" );
isa_ok( $non_admin, "Opsview::Schema::Contacts", "non_admin contact found" );
isa_ok( $somehosts, "Opsview::Schema::Contacts", "somehosts contact found" );
isa_ok( $readonly,  "Opsview::Schema::Contacts", "readonly contact found" );

witter( 'Checking host access' );
my $accessible_host =
  Opsview::Host->search( { name => 'monitored_by_slave' } )->first;
my $restricted_host = Opsview::Host->search( { name => 'cisco' } )->first;

my ( $expected, $got );

isa_ok( $accessible_host, 'Opsview::Host', 'Accessible host found' );
isa_ok( $restricted_host, 'Opsview::Host', 'Restricted host found' );

$got = $accessible_host->can_be_changed_by($admin);
isa_ok( $got, 'Opsview::Host', 'Correct object type' );
is( $got->id, $accessible_host->id, 'Correct object id for ' . $admin->name );

$got = $accessible_host->can_be_changed_by($non_admin);
isa_ok( $got, 'Opsview::Host', 'Correct object type for ' . $non_admin->name );
is( $got, $accessible_host, 'Correct object id' );

$got = $accessible_host->can_be_changed_by($somehosts);
isa_ok( $got, 'Opsview::Host', 'Correct object type for ' . $somehosts->name );
is( $got, $accessible_host, 'Correct object id' );

$got = $accessible_host->can_be_changed_by($readonly);
is( $got, undef, 'No access provided for ' . $readonly->name );

$got = $restricted_host->can_be_changed_by($admin);
isa_ok( $got, 'Opsview::Host', 'Correct object type' );
is( $got, $restricted_host, 'Correct object id for ' . $admin->name );

$got = $restricted_host->can_be_changed_by($non_admin);
isa_ok( $got, 'Opsview::Host', 'Correct object type for ' . $non_admin->name );
is( $got, $restricted_host, 'Correct object id' );

$got = $restricted_host->can_be_changed_by($somehosts);
is( $got, undef, 'No access provided for ' . $somehosts->name );

$got = $restricted_host->can_be_changed_by($readonly);
is( $got, undef, 'No access provided for ' . $readonly->name );

my $accessible_hostgroup =
  Opsview::Hostgroup->search( { name => 'Leaf2', } )->first;
my $restricted_hostgroup =
  Opsview::Hostgroup->search( { name => 'Leaf', } )->first;

isa_ok( $accessible_hostgroup, 'Opsview::Hostgroup',
    'Accessible hostgroup found'
);
isa_ok( $restricted_hostgroup, 'Opsview::Hostgroup',
    'Restricted hostgroup found'
);

$got = $accessible_hostgroup->can_be_changed_by($admin);
isa_ok( $got, 'Opsview::Hostgroup', 'Correct object type' );
is( $got, $accessible_hostgroup, 'Correct object id for ' . $admin->name );

{
    local $TODO = 'Apply correct access restrictions on hostgroups';
    $got = $accessible_hostgroup->can_be_changed_by($non_admin);
    isa_ok( $got, 'Opsview::Hostgroup', 'Correct object type' );
    is( $got, $accessible_hostgroup,
        'Correct object id for ' . $non_admin->name );
}

{
    local $TODO = 'Apply correct access restrictions on hostgroups';
    $got = $accessible_hostgroup->can_be_changed_by($somehosts);
    isa_ok( $got, 'Opsview::Hostgroup', 'Correct object type' );
    is( $got, $accessible_hostgroup,
        'Correct object id for ' . $somehosts->name );
}

$got = $accessible_hostgroup->can_be_changed_by($readonly);
is( $got, undef, 'No access provided for ' . $readonly->name );

$got = $restricted_hostgroup->can_be_changed_by($admin);
isa_ok( $got, 'Opsview::Hostgroup', 'Correct object type' );
is( $got, $restricted_hostgroup, 'Correct object id for ' . $admin->name );

{
    local $TODO = 'Apply correct access restrictions on hostgroups';
    $got = $restricted_hostgroup->can_be_changed_by($non_admin);
    isa_ok( $got, 'Opsview::Hostgroup', 'Correct object type' );
    is( $got, $restricted_hostgroup,
        'Correct object id for ' . $non_admin->name );
}

$got = $restricted_hostgroup->can_be_changed_by($somehosts);
is( $got, undef, 'No access provided for ' . $somehosts->name );

$got = $restricted_hostgroup->can_be_changed_by($readonly);
is( $got, undef, 'No access provided for ' . $readonly->name );
