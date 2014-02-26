#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

#use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib", "t/lib";

use_ok( "Nagios::States" );
use Nagios::States;

my $expected;

diag("Creating and configuring object") if ( $ENV{TEST_VERBOSE} );

$expected = {
    0 => "OK",
    1 => "WARNING",
    2 => "CRITICAL",
    3 => "UNKNOWN",
};

is_deeply( \%states_by_id, $expected, "States by id as expected" );

$expected = {
    OK       => 0,
    WARNING  => 1,
    CRITICAL => 2,
    UNKNOWN  => 3,
};

is_deeply( \%states_by_name, $expected, "States by name as expected" );
