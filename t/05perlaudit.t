#!/usr/bin/perl

use warnings;
use strict;
use FindBin qw($Bin);
use Test::More qw(no_plan);

# Only check files in lib/
chdir( "$Bin/../lib" );
my $output = `/usr/local/nagios/utils/perl_audit`;
is( $?, 0, "Audit is okay" ) || diag $output;
