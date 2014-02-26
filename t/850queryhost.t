#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Test::More;

BEGIN { use_ok( 'Opsview::Utils::QueryHost' ); }

my @level_0_tests = (
    'Unchanged text',
    '     start spaces test',
    'mid    spaces     test',
    'end spaces test       ',
    'Nortel Ethernet Routing Switch 5510-48T Module - Unit 1 Port 1',
);

# level 0 tests - text is all unchanged
my %level_0_tests = map { $_ => $_; } @level_0_tests;

# nasty chatrs are removed no matter the level so add this one in by hand
$level_0_tests{ 'nasty_' . chr(0) . '_chars' } = 'nasty__chars';

my %level_1_tests = (
    'Unchanged text' => 'Unchanged text',
    '     start spaces test', 'start spaces test',
    'mid    spaces     test', 'mid spaces test',

    # end spaces test test as functionality could be destructive
    #    'end spaces test       ', 'end spaces test',
    'Nortel Ethernet Routing Switch 5510-48T Module - Unit 1 Port 1' =>
      'Switch 5510-48T - Unit 1 Port 1',
    'nasty_' . chr(0) . '_chars' => 'nasty__chars',
);

my %level_3_tests =
  ( 'HP NC375T PCI Express Quad Port Gigabit Server Adapter' =>
      'HP NC375T Adapter', );

my %level_4_tests =
  ( 'Corrigent systems, , Ethernet 10 Gigabit interface-1376796672' =>
      'Ethernet 10 interface-1376796672', );

run_tests( 0, %level_0_tests );
run_tests( 1, %level_1_tests );
run_tests( 3, %level_3_tests );
run_tests( 4, %level_4_tests );

done_testing();

sub run_tests {
    my ( $level, %hash ) = @_;

    while ( my ( $original, $amended ) = each %hash ) {
        is(
            Opsview::Utils::QueryHost->tidy_interface_ifdescr(
                $level, $original
            ),
            $amended,
            "Checking level $level string: $amended"
        );
    }
}
