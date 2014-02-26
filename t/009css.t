#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw($Bin);

use Test::More qw/no_plan/;

my $errors = 0;
open F, "$Bin/../share/stylesheets/opsview2.css" or die "Cannot open css file";
while (<F>) {
    if (m%\(['"]?/images%) {
        diag( "Found absolute /images link at line $.: $_" );
        $errors++;
    }
}
close F;

if ($errors) {
    fail( "Found $errors error with absolute /images links" );
}
else {
    ok( "All relative /images links" );
}
