#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../etc", "$Bin/../lib";
use Test::DatabaseRow;
use_ok( "Opsview" );
use_ok( "Opsview::Test", "opsview" );
use_ok( "Utils::DBVersion" );

chdir( "$Bin/.." );

my $db;

eval { $db = Utils::DBVersion->new() };
like( $@, "/Need a dbh to be set/", "Need dbh" );

eval { $db = Utils::DBVersion->new( { dbh => Opsview->db_Main } ) };
like( $@, "/Name must be set/", "Need name" );

$db = Utils::DBVersion->new(
    {
        dbh  => Opsview->db_Main,
        name => "test"
    }
);
isa_ok( $db, "Utils::DBVersion", "Created okay" );

local $Test::DatabaseRow::dbh = Opsview->db_Main;

Opsview->db_Main->do( "DELETE FROM schema_version" );
row_ok(
    sql   => "SELECT count(*) as count FROM schema_version",
    tests => [ count => 0 ],
    label => "No rows",
);

row_ok(
    sql =>
      "SELECT count(*) as count from schema_version where major_release='5.78'",
    tests => [ count => 0 ],
    label => "Should be no major version of 5.78",
);
is(
    $db->is_lower("5.78.4"),
    1, "Some way off version number, so this should be true"
);
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.78" ],
    results => 1,
    tests   => [ version => "0" ],
    label   => "Created a new branch number",
);
ok( !$db->changed, "No changed value" );
$db->updated;
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.78" ],
    results => 1,
    tests   => [ version => "4" ],
    label   => "Set new version number correctly",
);
is( $db->changed, 1, "Has changed now" );

is( $db->is_lower("5.78.5"), 1, "New update" );
$db->updated;
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.78" ],
    results => 1,
    tests   => [ version => "5" ],
    label   => "Set new version number correctly",
);

is( $db->is_lower("5.78.2"), 0, "No update required for this version" );

row_ok(
    sql =>
      "SELECT count(*) as count from schema_version where major_release='5.79'",
    tests => [ count => 0 ],
    label => "Should be no major version of 5.79",
);
is( $db->is_lower("5.79.1"), 1, "New update for a different major release" );
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.79" ],
    results => 1,
    tests   => [ version => "0" ],
    label   => "Created a new branch number for 5.79",
);
$db->updated;
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.79" ],
    results => 1,
    tests   => [ version => "1" ],
    label   => "Set new version number",
);
row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.78" ],
    results => 1,
    tests   => [ version => "5" ],
    label   => "Make sure 5.78 branch not touched",
);

is(
    $db->is_lower("5.63.1"),
    0,
    "Expect this to fail because is a lower major_release than is currently in DB"
);
is(
    $db->is_lower("5.77.1"),
    0,
    "Expect this to fail because is a lower major_release than is currently in DB"
);

is(
    system("rm -rf /tmp/opsview_upgrade_override"),
    0, "Remove of directory okay"
);
is( $db->is_lower("5.85.1"), 1, "Expect this to pass because higher number" );

row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.85" ],
    results => 1,
    tests   => [ version => "0" ],
    label   => "Make sure 5.85 branch not touched",
);

mkdir "/tmp/opsview_upgrade_override";
open F, "> /tmp/opsview_upgrade_override/test-5.85.1"
  or die "Cannot create file";
close F;

is( $db->is_lower("5.85.1"), 0, "This should now fail due to override flag" );

row_ok(
    table   => "schema_version",
    where   => [ major_release => "5.85" ],
    results => 1,
    tests   => [ version => "1" ],
    label   => "Ensure update automatically applied",
);

row_ok(
    table   => "auditlogs",
    where   => [ notice => 1 ],
    results => 0,
    label   => "No notices in auditlogs",
);

$db->add_notice( "Test message into auditlogs" );

row_ok(
    table   => "auditlogs",
    where   => [ notice => 1 ],
    results => 1,
    tests   => [
        text     => 'Test message into auditlogs',
        username => ''
    ],
    label => "Got notice in auditlog now",
);

is(
    $db->is_installed( "20120906test", "some explanation", "commercial" ),
    0, "This should not exist"
);
row_ok(
    table   => "schema_version",
    where   => [ major_release => "20120906test" ],
    results => 0,
    label   => "Test update doesn't exist",
);
sleep 1;
$db->updated;
row_ok(
    table   => "schema_version",
    where   => [ major_release => "20120906test" ],
    results => 1,
    tests   => [
        version  => 'commercial',
        reason   => "some explanation",
        duration => 1,
    ],
    label => "Test update entry added",
);

eval { $db->is_installed("badtext") };
like(
    $@,
    qr/Version of form YYYYMMDDtext/,
    "Got error due to missing version"
);
eval { $db->is_installed("20120906text") };
like( $@, qr/Reason not set/, "Reason not set" );
eval { $db->is_installed( "20120906text", "Example upgrade" ) };
like( $@, qr/Product not set/, "Product not set" );
eval { $db->is_installed( "20120906text", "Example upgrade", "bad" ) };
like( $@, qr/Bad product: bad/, "Bad product" );

is(
    $db->is_lower("5.87.1"),
    1,
    "This should be required - had problem where new style numbering caused issues"
);
