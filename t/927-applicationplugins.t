#!/usr/bin/perl

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview::Applicationplugin;
use utf8;

plan tests => 16;

Opsview::Applicationplugin->retrieve_all->delete_all;

my $plugin =
  Opsview::Applicationplugin->find_or_create( { name => "rancid" } );
my $ctime = time;
isa_ok( $plugin, "Opsview::Applicationplugin" );
is( $plugin->created, $ctime, "Has set created time" );
is( $plugin->updated, $ctime, "Has set updated time" );
is( $plugin->version, undef,  "Version not set" );

is(
    $plugin->is_lower("1.0.0"),
    1, "Correctly identifies a newer version when blank before"
);
is( $plugin->new_version, "1.0.0", "And saves for later use" );
is( $plugin->version,     undef,   "But not set here" );

sleep 1;
$plugin->db_updated;
my $utime = time;
is( $plugin->version, "1.0.0", "Version updated" );
cmp_ok(
    ( $utime - $plugin->updated ),
    "<=", 2, "Update time updated within 2 seconds"
);
is( $plugin->created, $ctime, "And created time not touched" );

is( $plugin->is_lower("1.0.0"), 0, "Version does not need updating" );
is( $plugin->is_lower("0.4.5"), 0, "And not to 0.4.5 either" );

is( $plugin->is_lower("1.0.1"), 1, "But 1.0.1 does need it" );
$plugin->db_updated;
is( $plugin->version, "1.0.1", "Version updated again" );

is( $plugin->is_lower("2.3.1"), 1, "And try for 2.3.1" );
$plugin->db_updated;
is( $plugin->version, "2.3.1", "Version updated again" );
