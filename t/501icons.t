#!/usr/bin/perl

use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use strict;
use Opsview;

my %icons;

open ICONS, "$Bin/../import/hosticons.db" or die "Cannot open hosticons.db";
while (<ICONS>) {
    chop;
    my ( $name, $filename ) = split( ":", $_ );
    die "Incorrect syntax for $name" unless $filename;
    $icons{$name} = $filename;
}
close ICONS;

plan tests => ( keys %icons ) * 1 + 1;

my %allpng;
chdir("$Bin/../share/images/logos") or die "Cannot chdir";
opendir( DIR, "." );
map { $allpng{$_}++ if ( /\.png$/ && !/_small/ && !/^\.\.?$/ ) }
  ( readdir DIR );
closedir DIR;
foreach my $name ( keys %icons ) {
    my $f = $icons{$name};
    ok( -e "$f.png", "Got png: $f" );
    $allpng{"$f.png"}--;

    # We don't bother testing for gd2 and gif anymore as these are not used
    # by the front end
    #ok( -e "$f.gd2", "Got gd2: $f" );
    #ok( -e "$f.gif", "Got gif: $f" );
}

{
    local $TODO = "Needs fixing";
    cmp_ok(
        join( " ", grep { $allpng{$_} == 1 } ( keys %allpng ) ),
        'eq', '', 'On disk, but not in hosticons.db'
    );
}
