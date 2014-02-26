#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview;
use Opsview::Reloadtime;
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Reloadtimes" );

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

my $start_config = 1169730399;
my $end_config   = 1169730422;
my $timing = Opsview::Reloadtime->create( { start_config => $start_config } );
$timing->end_config($end_config);
$timing->update;
my $id = $timing->id;

my $last_row = Opsview::Reloadtime->last_row;
is( $id, $last_row->id, "last_row correct" );

is( $last_row->duration, 23, "Duration set correctly" );

$timing = Opsview::Reloadtime->create( { start_config => $start_config } );
$timing->end_config($start_config);
$timing->update;

is( $timing->duration, 0, "Time taken correct when duration=0" );

$timing = Opsview::Reloadtime->create( { start_config => $start_config } );
my $start = Opsview::Reloadtime->in_progress;
is( $start_config, $start->epoch, "Running time ok" );
$timing->end_config( $start_config + 15 );
$timing->update;
is( $timing->duration, 15, "Duration set correctly" );

$start = Opsview::Reloadtime->in_progress;
is( $start, undef, "undef returned when no reload running" );

my $last_reload = $rs->search( { duration => \"IS NOT NULL" },
    { order_by => { -desc => "id" } } )->first;
my $last_reload_duration;
if ($last_reload) {
    $last_reload_duration = $last_reload->duration;
}
is( $last_reload_duration, 15, "Got last reload duration" );

my $reloads =
  $rs->search( { end_config => { -between => [ 1188559654, 1188564644 ] } } )
  ->count;
is( $reloads, 3, "Got right count of reloads" );
