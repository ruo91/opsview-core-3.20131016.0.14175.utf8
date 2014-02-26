#!/usr/bin/perl

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$FindBin::Bin/lib", "$FindBin::Bin/../lib",
  "$FindBin::Bin/../etc";
use Test::More 'no_plan';
use Opsview::Test;

my $rc;

my $output = `$Bin/../nagios-plugins/check_opsview_keyword --keyword=cisco`;
is( $? >> 8, 3, "Got unknown error for cisco keyword" );
is(
    $output, qq{cisco UNKNOWN (unknown=15)
cisco (errors=15):
 UNKNOWN cisco::Another exception
 UNKNOWN cisco::Coldstart
 UNKNOWN cisco::Test exceptions
 ...
}, "Output as expected"
);

$output = `$Bin/../nagios-plugins/check_opsview_keyword --keyword=cisco_gp2`;
is( $? >> 8, 3, "Got unknown error for cisco_gp2 keyword" );
is(
    $output, qq{cisco_gp2 UNKNOWN (unknown=9)
cisco_gp2 (errors=9):
 UNKNOWN cisco2::Another exception
 UNKNOWN cisco2::Coldstart
 UNKNOWN cisco2::Test exceptions
 ...
}, "Output as expected"
);
