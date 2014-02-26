#!/usr/bin/perl

package Test::JSON::File;
use strict;
use warnings;

use JSON;
use Test::More;
use Test::JSON;
use Exporter;
use base "Exporter";

our @EXPORT = qw(&is_json_file &is_csv_file);

sub is_json_file {
    my ( $json, $file, $help ) = @_;
    my $file_contents;
    if ( $ENV{OPSVIEW_RESET_JSON} ) {
        my $j    = JSON->new();
        my $perl = $j->decode($json);
        open F, ">", $file or die "Cannot write $file: $!";
        print F $j->pretty(1)->canonical(1)->encode($perl);
        close F;
        pass( "RESET JSON contents!!!!" );
    }
    else {
        local $/ = undef;
        open F, $file or die "Cannot read $file: $!";
        $file_contents = <F>;
        close F;
        is_json $json, $file_contents, $help;
    }
}

sub is_csv_file {
    my ( $csv, $file, $help ) = @_;
    my $file_contents;
    {
        local $/ = undef;
        open F, $file or die "Cannot read $file: $!";
        $file_contents = <F>;
        close F;
    }
    is( $csv, $file_contents, $help );
}

1;
