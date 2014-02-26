#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Servicecheck;

# This host has some interesting uses of exceptions, hosttemplates and timed exceptions
my $sc = Opsview::Servicecheck->search( name => "Check Loadavg" )->first;
isa_ok( $sc, "Opsview::Servicecheck", "Found servicecheck" );

my @results = $sc->retrieve_all_exceptions_by_service( $sc->id );

my $expected = [
    {
        h_ex_args =>
          '-H $HOSTADDRESS$ -c check_load -a \'-w 15,15,15 -c 19,19,19\'',
        h_ex_checked => 1,
        h_id         => bless(
            {
                __triggers => {},
                id         => 4
            },
            "Opsview::Host"
        ),
    },
    {
        h_id => bless(
            {
                __triggers => {},
                id         => 6
            },
            "Opsview::Host"
        ),
        h_to_args       => "--timed",
        h_to_checked    => 1,
        h_to_timeperiod => bless(
            {
                __triggers => {},
                id         => 1
            },
            "Opsview::Timeperiod"
        ),
    },
    {
        h_id => bless(
            {
                __triggers => {},
                id         => 12
            },
            "Opsview::Host"
        ),
        remove_servicecheck => 1,
    },
];
is_deeply( \@results, $expected, "As expected" );

isa_ok( $results[1]->{h_id}, "Opsview::Host" );
isa_ok( $results[2]->{h_id}, "Opsview::Host" );
