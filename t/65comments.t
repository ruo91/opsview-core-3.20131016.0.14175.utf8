#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";

use Test::More tests => 2;
use Test::Deep;

use Opsview::Test;

BEGIN {
    use_ok( 'Runtime::Searches' );
}

my ( $list, $expected );
$expected = {
    115 => 1,
    116 => 1,
    117 => 1,
    148 => 1,
    151 => 1,
    214 => 1,
    216 => 3
};

$list = Runtime::Searches->list_comments();

is_deeply( $list, $expected, "Comments as expected" );
