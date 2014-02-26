#!/usr/bin/perl

use Test::More tests => 1;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use strict;
use Opsview;

my $rc = system( "$Bin/../bin/populate_db.pl" );
ok( $rc == 0, "Repopulated" );
