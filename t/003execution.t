#!/usr/bin/perl

use warnings;
use strict;

use FindBin qw($Bin);

use Test::More;

chdir( "$Bin/.." );

my @perl_exes;
my @files = <bin/*>;

foreach my $f (@files) {
    open F, $f or die "Cannot read $f";
    my $firstline = <F>;
    close F;
    if ( $firstline =~ /perl/ ) {
        push @perl_exes, $f;
    }
}

plan tests => scalar(@perl_exes);

foreach my $exe (@perl_exes) {
    my $output = qx/ $^X -c $exe 2>&1 /;
    chomp($output);
    is( $?, 0, "Compile $exe:" . $output );
}
