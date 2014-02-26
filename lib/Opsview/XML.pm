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

package Opsview::XML;

use strict;
use warnings;

use Class::Accessor::Fast;
use base qw(Class::Accessor::Fast);

use XML::Simple;

__PACKAGE__->mk_accessors(
    qw(body error data object authentication action list)
);

sub is_error { shift->error ? 1 : 0 }

# Takes the body in $self->body and puts the resultant hash into $self->data
# If failure, will set $self->error
sub deserialize {
    my ($self) = @_;

    if ( $self->body ) {
        my $xs = XML::Simple->new(
            KeyAttr       => [],
            SuppressEmpty => ""
        );
        my $rdata;
        eval { $rdata = $xs->XMLin( $self->body ); };
        if ($@) {
            return $self->error($@);
        }

        if ( exists $rdata->{authentication} ) {
            $self->authentication(
                {
                    username => $rdata->{authentication}->{username},
                    password => $rdata->{authentication}->{password}
                }
            );
            delete $rdata->{authentication};
        }

        # Should be only one key
        my ($type) = keys %$rdata;
        $rdata = $rdata->{$type};

        if ( exists $rdata->{action} ) {
            $self->action( $rdata->{action} );
            delete $rdata->{action};
        }

        my $class;
        if ( $self->action ) {
            if ( $self->action eq "reload" ) {

                # This class doesn't actually exist
                # The eval will fail below, but is not being trapped
                # Special treatment dished out at Opsview::Web::Controller::Api.pm for this case
                $class = "Opsview::System";
            }
            elsif ( $self->action eq "change" ) {
                $class = "Runtime::" . ucfirst($type);
            }
        }
        $class = "Opsview::CRUD::" . ucfirst($type) unless $class;
        eval "require $class";

        if ( exists $rdata->{by_id} ) {
            my $o = $class->retrieve( $rdata->{by_id} );
            unless ($o) {
                return $self->error(
                    "Cannot find $type (in $class) with id " . $rdata->{by_id}
                );
            }
            delete $rdata->{by_id};
            $self->object($o);
        }
        elsif ( exists $rdata->{by_name} ) {
            my @list = $class->search( { name => $rdata->{by_name} } );
            my $o = $list[0];
            unless ($o) {
                return $self->error(
                    "Cannot find $type with name " . $rdata->{by_name}
                );
            }
            delete $rdata->{by_name};
            $self->object($o);
            $self->list( \@list );
        }
        else {
            $self->object($class);
        }

        if ( $class =~ /^Opsview::CRUD::/ ) {

            # Remove extraneous hashes
            # eg: servicechecks => { servicecheck => [ { id => 6 }, { id => 22 }, { id => 29 } ] }
            # to: servicechecks => [ { id => 6 }, { id => 22 }, { id => 29 } ]
            foreach my $key ( @{ $class->has_many_fields } ) {
                if ( exists $rdata->{$key} ) {
                    if ( $rdata->{$key} eq "" ) {
                        $rdata->{$key} = [];
                    }
                    else {
                        ($_) =
                          keys %{ $rdata->{$key}
                          }; # Should only ever have 1 key at most
                        $rdata->{$key} = $rdata->{$key}->{$_};

                        # Needed for case of a single element
                        if ( ref $rdata->{$key} eq "HASH" ) {
                            $rdata->{$key} = [ $rdata->{$key} ];
                        }
                    }
                }
            }
        }

        $self->data($rdata);
    }
    else {
        $self->error( "No data in body to deserialize" );
    }
    return 1;
}

sub serialize {
    my $self = shift;
    my $xs   = XML::Simple->new(
        NoAttr   => 1,
        RootName => "opsview"
    );

    my $h = $self->data;

    # Expand arrays so that the resultant XML is more friendly
    # eg: servicechecks => [ { id => 3 }, { id => 5 } ]
    # becomes: servicechecks => { servicecheck => [ { id => 3 }, { id => 5 } ] }
    # which serialises to: <servicechecks><servicecheck><id>3</id><servicecheck><id>5</id></servicechecks>
    foreach my $key ( keys %$h ) {
        if ( $h->{$key} && ref( $h->{$key} ) eq "ARRAY" ) {
            $h->{$key} =
              { $self->object->foreign_keys->{$key}->moniker => $h->{$key} };
        }
        elsif ( !defined $h->{$key} ) {
            delete $h->{$key};
        }
    }

    my $output;
    eval { $output = $xs->XMLout( { $self->object->moniker => $h } ); };
    if ($@) {
        return $self->error($@);
    }
    $self->body($output);
    return 1;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
