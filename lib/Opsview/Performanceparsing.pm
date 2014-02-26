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

# This package is to do the performance parsing
# duplicating logic in Nagiosgraph
# Portions: Copyright Soren Dossing

package Opsview::Performanceparsing;
use strict;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors( qw(uom label value) );

use Nagios::Plugin::Performance;

=item Opsview::Performanceparsing->init

Initialise this package. Reads in the map file

=cut

sub init {
    my $class = shift;
    my $rules;
    {
        local $/ = undef;
        open FH, "/usr/local/nagios/etc/map";
        $rules = <FH>;
        close FH;

        # also check for and load in a map.local override file
        if ( -f "/usr/local/nagios/etc/map.local" ) {
            open my $fh, "/usr/local/nagios/etc/map.local";
            $rules .= <$fh>;
            close $fh;
        }
    }
    $rules =
        'sub evalrules { $_=$_[0]; my @s; no strict "subs"; '
      . $rules
      . ' use strict "subs"; return \@s }';
    eval $rules;
    die "Map file eval error: $@" if $@;
    return 1;
}

=item $obj->parseperfdata( servicename => $name, output => $output, perfdata => $perfdata )

Parses the data based on rules, using nagiosgraph's map file.

Will return a list ref of objects where you can access the label, value and uom.

=cut

sub parseperfdata {
    my ( $self, %P ) = @_;
    my $s = evalrules(
        "servicedescr:$P{servicename}\noutput:$P{output}\nperfdata:$P{perfdata}"
    );
    if (@$s) {
        my @result;
        my $perfs = shift @$s;
        shift @$perfs; # Ignore first field

        foreach my $p (@$perfs) {
            push @result,
              __PACKAGE__->new(
                {
                    label => $p->[0],
                    value => $p->[2],
                    uom   => ""
                }
              );
        }
        return \@result;
    }
    else {
        my @a = Nagios::Plugin::Performance->parse_perfstring( $P{perfdata} );
        my @list;
        foreach my $p (@a) {
            my $label = $p->clean_label;
            push @list,
              __PACKAGE__->new(
                {
                    label => $label,
                    value => $p->value,
                    uom   => $p->uom
                }
              );
        }
        return \@list;
    }
}

1;
