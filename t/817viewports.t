#!/usr/bin/perl

use Test::More qw(no_plan);

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Opsview::Test;
use Runtime::Schema;

use Test::Perldump::File;

my $schema = Runtime::Schema->my_connect;

my $rs = $schema->resultset( "OpsviewViewports" );
is( $rs->count, 48, "Found viewports" );

my $search =
  $rs->search( { object_id => 217 }, { join => "opsview_keyword" } );
is( $search->count,          1,            "Found single object" );
is( $search->first->keyword, "allhandled", "Got keyword name" );
is(
    $search->first->opsview_keyword->description,
    "All services handled",
    "Got keyword description, crossing the opsview db divide"
);

my $hash =
  $schema->resultset("OpsviewViewports")
  ->list_summary( { keyword => [qw(cisco cisco_gp1 cisco_gp2)] } );
is_perldump_file(
    $hash,
    "$Bin/var/perldumps-status/summarised_keywords",
    "Got ordered by keyword"
) || diag explain $hash;

$hash =
  $schema->resultset("OpsviewViewports")
  ->list_summary( { keyword => [qw(cisco_gp1 cisco)] } );
is_perldump_file(
    $hash,
    "$Bin/var/perldumps-status/summarised_keywords_two",
    "Only show two keywords"
) || diag explain $hash;
