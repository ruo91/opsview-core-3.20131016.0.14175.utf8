#!/usr/bin/perl
# Tests for timeperiods

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Timeperiods" );

plan tests => 2;

my $tp = $rs->find(1);
is( $tp->name, "24x7" );
is( $tp, "24x7", "Checking stringification" );
