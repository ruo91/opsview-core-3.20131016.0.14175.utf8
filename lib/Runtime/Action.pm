#
#
# DESCRIPTION:
#	Thin class to handle do_change, which is the XML action for Runtime objects
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

package Runtime::Action;
use warnings;
use strict;
use Carp;
use Opsview::Auditlog;
use Opsview::Common;

=head1 NAME

Runtime::Action - Runtime's equivalent to Opsview::CRUD::Base

=head1 DESCRIPTION

Only handles do_change at moment. Possibly to be expanded in future

=head1 METHODS

=over 4

=item __PACKAGE__->do_change( $hash )

Called for action="change" in API. Finds the only key and runs it for this 
object.  Performs some parameter validate depending on what is being changed.

=cut

sub do_change {
    my ( $self, $hash ) = @_;
    my ($thing_to_change) = keys %$hash; # Should only be one thing here
    my $log_event = 1;

    # Expecting something like "notifications"
    # Do parameter checking here since parameters may be used across diff
    # commands, such as downtime on hosts, hostgroups or services
    SWITCH: {
        foreach ($thing_to_change) {
            /^downtime$/ && do {
                if ( ref( $hash->{$thing_to_change} ) eq "HASH" ) {

                    # enable comes in as a hash, disable as a scalar
                    my ( $start, $end ) = parse_downtime_strings(
                        $hash->{$thing_to_change}->{start},
                        $hash->{$thing_to_change}->{end},
                    );

                    if ( !$start || !$end ) {

                        #$@=$@; # ensure $@ is propogated
                        return undef;
                    }
                    else {
                        $hash->{$thing_to_change}->{start} = $start->epoch
                          if ( $hash->{$thing_to_change}->{start} ne
                            $start->epoch );
                        $hash->{$thing_to_change}->{end} = $end->epoch
                          if (
                            $hash->{$thing_to_change}->{end} ne $end->epoch );
                    }
                }

                # All downtime events are logged in a higher module
                $log_event = 0;
                last SWITCH;
            };
        }
    }
    $self->$thing_to_change( $hash->{$thing_to_change} );
    Opsview::Auditlog->create(
        {
            username => $self->username,
            text     => ucfirst( $self->class_title ) . " "
              . $self->name
              . " $thing_to_change="
              . $hash->{$thing_to_change}
        }
    ) if ($log_event);
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
