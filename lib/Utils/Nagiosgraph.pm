#
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

package Utils::Nagiosgraph;

use warnings;
use strict;
use Exporter;
use base qw/Exporter/;

our @EXPORT = qw(convert_map urlencode urldecode);

=head1 NAME

Utils::Nagiosgraph - Opsview routines for nagiosgraph

=head1 DESCRIPTION

Routines for nagiosgraph for testing

=head1 METHODS

=over 4

=item convert_map

Converts a Nagiosgraph map result into a list of hashes for Opsview to process

=cut

sub convert_map {
    my $arrayref = shift;
    my @metrics  = ();
    my $result   = {
        list   => \@metrics,
        dbname => ""
    };
    foreach my $m (@$arrayref) {
        $result->{dbname} = shift @$m;
        foreach my $datapoint (@$m) {
            push @metrics,
              {
                metric => $datapoint->[0],
                dstype => $datapoint->[1],
                value  => $datapoint->[2]
              };
        }
    }
    return $result;
}

=item urlencode($string)

Returns a $string after urlencoding. Credit to Soren Dossing as this is from the original Nagiosgraph

=cut

sub urlencode {
    my $s = shift;
    $s =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
    return $s;
}

sub urldecode {
    my $s = shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    return $s;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
