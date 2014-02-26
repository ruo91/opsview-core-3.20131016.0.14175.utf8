#!/usr/bin/perl

use Test::More tests => 15;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Servicecheck;
use utf8;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

my ( $sc, $sc2, $sc3 ) = Opsview::Servicecheck->retrieve_all;
my @empty = ();
$sc->set_dependencies_to(); # Reset dependencies
my @d = $sc->dependencies;

is_deeply( \@empty, \@d, "dependencies empty" );

my @set_to = ( $sc2, $sc3 );
$sc->set_dependencies_to( $sc2, $sc3 );
@d = $sc->dependencies;

# Convert to hashes because order not important
my ( $a, $b );
map { $a->{$_}++ } @set_to;
map { $b->{$_}++ } @d;

is_deeply( $a, $b, "Set to two correctly" );
my $r = $dbh->selectcol_arrayref(
    "SELECT dependencyid FROM servicecheckdependencies WHERE servicecheckid = "
      . $sc->id );
$b = {};
map { $b->{$_}++ } @$r;
is_deeply( $a, $b, "And correct in db" );

$sc->set_dependencies_to( $sc2, $sc3, $sc );
@d = $sc->dependencies;
$b = {};
map { $b->{$_}++ } @d;

is_deeply( $a, $b, "Correctly ignored self" );
$r = $dbh->selectcol_arrayref(
    "SELECT dependencyid FROM servicecheckdependencies WHERE servicecheckid = "
      . $sc->id );
$b = {};
map { $b->{$_}++ } @$r;
is_deeply( $a, $b, "And correct in db" );

eval { $sc2->delete; };
is( $@, "", "No error in delete" );
$a = {};
map { $a->{$_}++ } ( $sc->dependencies );
$b = {};
map { $b->{$_}++ } ($sc3);
is_deeply( $a, $b, "Updated in db correctly" );

# Create a utf8 service check name and delete afterwards
$sc = Opsview::Servicecheck->find_or_create(
    {
        name         => "àëòõĉĕ",
        servicegroup => 1
    }
);
isa_ok( $sc, "Opsview::Servicecheck" );
$sc->delete;

# Check that can find an interface servicecheck correctly
my $obj = Opsview::Servicecheck->find( "DNS" );
isa_ok( $obj, "Opsview::Servicecheck" );
is( $obj->name, "DNS" );

$obj = Opsview::Servicecheck->find( "Interface: bob" );
isa_ok( $obj, "Opsview::Servicecheck" );
is( $obj->name, "Interface" );

$obj = Opsview::Servicecheck->find( "Slave-node: bob" );
isa_ok( $obj, "Opsview::Servicecheck" );
is( $obj->name, "Slave-node" );
