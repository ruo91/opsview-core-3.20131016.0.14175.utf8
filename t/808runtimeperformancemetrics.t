#!/usr/bin/perl
# Tests for runtime performance metrics

use Test::More qw(no_plan);

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Opsview::Test;
use Runtime::Schema;

my $schema = Runtime::Schema->my_connect;

my $rs = $schema->resultset( "OpsviewPerformanceMetrics" );

my $perfmetric = $rs->search(
    {
        hostname    => "opsview",
        servicename => "Nagios Stats",
        metricname  => "avgactsvclatency",
    }
)->first;
is( $perfmetric->uom,               "s" );
is( $perfmetric->service_object_id, 563 );

my @list =
  $rs->search( { "contacts.contactid" => 4 }, { join => "contacts" } );
is( scalar @list, 6 );

@list = $rs->search(
    { "keywords.keyword" => "cisco" },
    {
        join     => "keywords",
        distinct => 1,
        order_by => "id"
    }
);
is( scalar @list, 3 );

# Faked performance metrics (linked to keywords, but hostname and servicename do not match)
# to test join with keywords
is( $list[0]->id, 449, "Got first metric" );
is( $list[0]->metricname, "size" );
is( $list[1]->id,         450, "Got 2nd metric" );
is( $list[1]->metricname, "rta" );
is( $list[2]->id,         451, "Got 3rd metric" );
is( $list[2]->metricname, "time" );
