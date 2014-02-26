#!/usr/bin/perl

package Test::Perldump::File;
use strict;
use warnings;

use Data::Dump qw(dump);
use Exporter;
use base "Exporter";

our @EXPORT = qw(&is_perldump_file &perldump_file);

use Test::More;
use Test::Deep;

my $resetperldumps = 0;

sub resetperldumps { shift; $@ ? $resetperldumps : $resetperldumps = shift }

sub perldump_file {
    my ($file) = @_;
    my $file_contents;
    {
        local $/ = undef;
        open F, $file or die "Cannot read $file: $!";
        $file_contents = <F>;
        close F;
    }
    my $expected;
    eval '$expected = ' . $file_contents;
    return $expected;
}

sub is_perldump_file {
    my ( $object, $file, $help ) = @_;
    if ( !$resetperldumps && !$ENV{OPSVIEW_RESET_JSON} ) {
        my $expected = perldump_file($file);
        cmp_deeply( $object, noclass($expected), "$file: $help" );
    }
    else {
        open F, ">", $file or die "Cannot write to $file: $!";
        print F dump($object);
        close F;
        pass( "NOT REALLY TESTING!!!! Resetting $file" );
    }
}

1;
