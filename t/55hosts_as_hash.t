#!/usr/bin/perl

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test;
use Opsview;
use Opsview::Host;

my $it = Opsview::Host->retrieve_all;
plan tests => $it->count;

while ( my $host = $it->next ) {
    my $h = $host->as_hash;
    is( ref $h, "HASH", "Got a hash back" );
}
