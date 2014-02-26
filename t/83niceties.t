#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview::Utils::Niceties qw(nice_values);

my $tests = {
    "1.500"     => "1.5",
    "0"         => "0",
    "0.000"     => "0",
    "3.1415926" => "3.142",
    "1.501"     => "1.501",
    "100.678"   => "100.678",
    "100.600"   => "100.6",
    "-62.0"     => "-62",
    "5.9999"    => "6",
    "5.9994"    => "5.999",
};

is( nice_values($_), $tests->{$_}, "$_ => " . $tests->{$_} )
  for sort keys %$tests;

is(
    nice_values( "67.869", 1 ),
    "67.9", "Rounding on different precisions also works"
);
