#!/usr/bin/perl

use warnings;
use strict;
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Hostgroups" );

my $top = $rs->find(1);

my $identifier = shift @ARGV || "name";

sub return_newick_format {
    my $hg       = shift;
    my @children = $hg->children;
    my $prefix   = "";
    if (@children) {
        my @childnames;
        foreach my $child (@children) {
            push @childnames, return_newick_format($child);
        }
        $prefix = "(" . join( ",", @childnames ) . ")";
    }
    return $prefix . $hg->$identifier;
}

print return_newick_format($top) . $/;
