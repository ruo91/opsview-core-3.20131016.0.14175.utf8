#
# Opsview::XML
# Inspired from Catalyst::Action::(Des|S)erialize::XML::Simple.pm by Adam Jacob, Marchex, <adam@marchex.com>
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

package Opsview::Utils::XMLSerialisation;

use strict;
use warnings;

=head1 NAME

Opsview::Utils::XMLSerialisation - Converts to and from XML

=cut

use base qw(Class::Accessor::Fast);

use XML::Simple;

__PACKAGE__->mk_accessors(
    qw(body error data object authentication action list)
);

sub is_error { shift->error ? 1 : 0 }

=head1 $hash = $self->deserialise( $data )

Takes the data and converts to the resultant hash. Dies on error

=cut

sub deserialise {
    my ( $self, $data ) = @_;

    my $xs = XML::Simple->new(
        KeyAttr       => [],
        SuppressEmpty => ""
    );
    my $rdata;

    # Could die if bad data
    $rdata = $xs->XMLin($data);

    remove_extraneous_hashes($rdata);

    return $rdata;
}

# WARNING: Will change contents of the hash. Take a clone copy of it
# beforehand if you need to keep a pristine copy
sub serialise {
    my ( $self, $h ) = @_;
    my $xs = XML::Simple->new(
        AttrIndent => 1,
        RootName   => "opsview"
    );

    convert_for_serialisation($h);

    my $output;
    eval { $output = $xs->XMLout($h); };
    if ($@) {
        die($@);
    }
    return $output;
}

# Expand arrays so that the resultant XML is more friendly
# eg: servicechecks => [ { id => 3 }, { id => 5 } ]
# becomes: servicechecks => { list => [ { id => 3 }, { id => 5 } ] }
# which serialises to: <servicechecks><list><item><id>3</id></item><item><id>5</id></item></list></servicechecks>
# Also converts empty lists so:
#  servicechecks => []
# becomes
#  <servicechecks isEmpty=1/>
# Also converts to null, so:
#  check_period == null
# becomes
#  <check_period isNull="1"/>
sub convert_for_serialisation {
    my $h = shift;
    foreach my $key ( keys %$h ) {
        if ( ref( $h->{$key} ) eq "ARRAY" ) {
            if ( @{ $h->{$key} } ) {
                foreach my $hash ( @{ $h->{$key} } ) {
                    convert_for_serialisation($hash);
                }
                $h->{$key} = { "item" => $h->{$key} };
            }
            else {
                $h->{$key} = { isEmpty => 1 };
            }
        }
        elsif ( ref( $h->{$key} ) eq "HASH" ) {
            convert_for_serialisation( $h->{$key} );
        }
        elsif ( !defined $h->{$key} ) {
            $h->{$key} = { isNull => 1 };
        }
    }
}

sub remove_extraneous_hashes {
    my $rdata = shift;

    foreach my $key ( keys %$rdata ) {
        if ( ref $rdata->{$key} eq "HASH" ) {
            if ( exists $rdata->{$key}->{isNull} ) {
                $rdata->{$key} = undef;
            }
            elsif ( exists $rdata->{$key}->{isEmpty} ) {
                $rdata->{$key} = [];
            }

            # Remove extraneous hashes
            # eg: servicechecks => { item => [ { id => 6 }, { id => 22 }, { id => 29 } ] }
            # to: servicechecks => [ { id => 6 }, { id => 22 }, { id => 29 } ]
            elsif ( $rdata->{$key}->{item} ) {
                $rdata->{$key} = $rdata->{$key}->{item};

                # Needed for case of a single element
                if ( ref $rdata->{$key} eq "HASH" ) {
                    $rdata->{$key} = [ $rdata->{$key} ];
                }
            }
        }
        if ( ref $rdata->{$key} eq "ARRAY" ) {
            foreach my $h ( @{ $rdata->{$key} } ) {
                remove_extraneous_hashes($h);
            }
        }
    }
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
