#!/usr/bin/perl
# Test that the structure changes work as expected

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Utils::Nagiosgraph;

use Test::More qw(no_plan);

my $input;
my $expected;
my $generated;

$input = [ [ "ping", [ "losspct", "GAUGE", 0 ], [ "rta", "GAUGE", "8e-05" ] ] ];
$expected = {
    dbname => "ping",
    list   => [
        {
            metric => "losspct",
            dstype => "GAUGE",
            value  => 0
        },
        {
            metric => "rta",
            dstype => "GAUGE",
            value  => "8e-05"
        },
    ]
};
$generated = convert_map($input);
is_deeply( $generated, $expected );

$input = [
    [
        '',
        [ "packetsin",   "DERIVE", 4 ],
        [ "packetserr",  "DERIVE", 100 ],
        [ "packetslost", "DERIVE", 150 ]
    ]
];
$expected = {
    dbname => "",
    list   => [
        {
            metric => "packetsin",
            dstype => "DERIVE",
            value  => 4
        },
        {
            metric => "packetserr",
            dstype => "DERIVE",
            value  => 100
        },
        {
            metric => "packetslost",
            dstype => "DERIVE",
            value  => 150
        },
    ]
};
$generated = convert_map($input);
is_deeply( $generated, $expected );

$input = [ [ "procs", [ "procs", "GAUGE", 11 ] ] ];
$expected = {
    dbname => "procs",
    list   => [
        {
            metric => "procs",
            dstype => "GAUGE",
            value  => 11
        }
    ],
};
$generated = convert_map($input);
is_deeply( $generated, $expected );

$input = "A string with some - funny/unfunny chars in";
my $initial = $input;
$expected = "A%20string%20with%20some%20%2D%20funny%2Funfunny%20chars%20in";
is( urlencode($input),              $expected, "urlencode()" );
is( urldecode( urlencode($input) ), $input,    "Also decoded" );
is( $input,                         $initial,  "string not altered" );
