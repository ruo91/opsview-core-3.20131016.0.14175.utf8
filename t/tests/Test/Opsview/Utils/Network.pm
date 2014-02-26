
package Test::Opsview::Utils::Network;

use strict;
use warnings;

use base qw( Test::Opsview );

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;

use NetAddr::IP;

sub _setup_testing : Test(setup => no_plan) {
    my $self = shift;

    use_ok 'Opsview::Utils::Network'
      or die "Cannot load Opsview::Utils::Network";
}

sub count_ips : Test(2) {
    my $self = shift;

    my %tests = (
        "192.168.0.1-192.168.0.10"                    => 10,
        "192.168.0.1-192.168.7.254"                   => 2046,
        "192.168.0.0/24"                              => 256,
        "192.168.0.0/27"                              => 32,
        "192.168.0.0/8"                               => 16777216,
        "1234:5678:90AB:CDEF:0123:4567:890A:BCDE/127" => 2,
        "1234:5678:90AB:CDEF:0123:4567:890A:BCDE/64"  => '18446744073709551616',
    );

    subtest "Strings as input" => sub {
        plan tests => scalar keys %tests;

        while ( my ( $test, $count ) = each %tests ) {
            my ( $first, $last ) = split( /\-/, $test );

            is(
                Opsview::Utils::Network::count_ips( $first, $last ),
                $count, "$test has $count IPs"
            );
        }
    };
    subtest "NetAddr::IP objects as input" => sub {
        plan tests => scalar keys %tests;

        while ( my ( $test, $count ) = each %tests ) {
            my ( $first, $last ) =
              map { NetAddr::IP->new($_) } split( /\-/, $test );

            is(
                Opsview::Utils::Network::count_ips( $first, $last ),
                $count, "$test has $count IPs"
            );
        }
    };
}

sub anyip_to_ipv4 : Test(2) {
    my $self = shift;

    my %tests = (
        "127.0.0.1"                               => "127.0.0.1",
        "::ffff:127.0.0.1"                        => "127.0.0.1",
        "0.0.0.0"                                 => "0.0.0.0",
        "255.255.255.255"                         => "255.255.255.255",
        "1234:5678:90AB:CDEF:0123:4567:890A:BCDE" => "137.10.188.222",
        "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff" => "255.255.255.255",
    );

    while ( my ( $test, $expected ) = each %tests ) {
        is(
            Opsview::Utils::Network::ipanyto4($test),
            $expected, "Convert $test to $expected"
        );
    }
}

1;
