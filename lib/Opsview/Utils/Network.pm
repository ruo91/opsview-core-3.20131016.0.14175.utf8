
package Opsview::Utils::Network;

use strict;
use warnings;

use Sub::Exporter -setup => { exports => [qw( count_ips ipanyto4 )], };

use Math::BigInt;
use NetAddr::IP;
use NetAddr::IP::Util qw(inet_ntoa ipv6to4 ipanyto6 inet_any2n);

sub count_ips {
    my ( $first, $last ) = @_;

    unless ( ref $first eq 'NetAddr::IP' ) {
        $first = NetAddr::IP->new($first);
    }

    my $count = Math::BigInt->new(0);

    if ($last) {
        unless ( ref $last eq 'NetAddr::IP' ) {
            $last = NetAddr::IP->new($last);
        }

        my ( $start, $end ) = (
            NetAddr::IP->new( $first->addr, 0 ),
            NetAddr::IP->new( $last->addr,  0 )
        );

        $count++;
        $count++ while ( $start++ < $end );
    }
    else {
        my ( $addr, $mask ) = map { Math::BigInt->new($_) } $first->numeric;
        my $broadcast = Math::BigInt->new( $first->broadcast->numeric );

        $count = $broadcast - ( $addr & $mask ) + 1;
    }

    return $count->bstr;
}

sub ipanyto4 {
    return inet_ntoa( ipv6to4( ipanyto6( inet_any2n( $_[0] ) ) ) );
}

1;

