#!/usr/bin/perl

use Test::More tests => 16;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview;
use Opsview::Hostgroup;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

# This retrieves a leaf
my ($hg) = Opsview::Hostgroup->retrieve_all;
my $name = $hg->name;
my $new;

eval '$new = Opsview::Hostgroup->create({})';
ok( $@, "Failed create correctly because no name specified" );

eval '$new = Opsview::Hostgroup->create( { name => "rubbish !%*" } ) ';
ok( $@, "Errored for bad characters" );

eval '$new = Opsview::Hostgroup->create( { name => $name } ) ';
ok( $@, "Duplicated leaf name" );

$new = Opsview::Hostgroup->create( { name => "temp$$" } );
isa_ok( $new, "Opsview::Hostgroup" );
is( $new->my_type_is, "hostgroup", "Checking my_type_is" );

is(
    $dbh->selectrow_array(
        "SELECT parentid FROM hostgroups WHERE id=" . $new->id
    ),
    1,
    "Set default parentid to top"
);

my $saved_name = $new->name;
$new->name( $hg->name );
eval '$new->update';

ok( $@, "Duplicated leaf name on update" );
is(
    $dbh->selectrow_array( "SELECT name FROM hostgroups WHERE id=" . $new->id ),
    $saved_name,
    "Name not changed to same as another leaf"
);
$new->discard_changes;

$new = Opsview::Hostgroup->create(
    {
        name     => "child$$",
        parentid => $hg->id
    }
);
isa_ok( $new, "Opsview::Hostgroup" );
is(
    $dbh->selectrow_array(
        "SELECT parentid FROM hostgroups WHERE id=" . $new->id
    ),
    $hg->id,
    "Set parentid to " . $hg->id
);

$new->parentid(1);
$new->update;

is(
    $dbh->selectrow_array(
        "SELECT parentid FROM hostgroups WHERE id=" . $new->id
    ),
    1,
    "Parentid changed without complaint re: same leaf name"
);

$hg->parentid( $hg->id );
$hg->update;

is(
    $dbh->selectrow_array(
        "SELECT parentid FROM hostgroups WHERE id=" . $hg->id
    ),
    1,
    "Not allowed parentid to be same as self - set to 1"
);

my $top = Opsview::Hostgroup->retrieve(1);
$top->parentid(1);
$top->update;

is(
    $dbh->selectrow_array("SELECT parentid FROM hostgroups WHERE id=1"),
    undef, "Root is always set to NULL"
);

$hg->information( "Some hostgroup information" );
$hg->update;
is(
    $hg->information,
    "Some hostgroup information",
    "hostgroup information set"
);
$hg->information( "Some changed hostgroup information" );
$hg->update;
is(
    $hg->information,
    "Some changed hostgroup information",
    "hostgroup information updated"
);
