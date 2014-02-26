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

package Opsview::ResultSet::Hosttemplates;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

sub auto_create_foreign {
    { "keywords" => 1, };
}

sub synchronise_override_servicechecks {
    my ( $self, $object, $objs, $errors ) = @_;

    my %current_exceptions =
      map { ( $_->id => 1 ) } ( $object->search_related("exceptions") );
    my %current_timed_exceptions =
      map { ( $_->id => 1 ) } ( $object->search_related("timed_exceptions") );
    $object->delete_related( "hosttemplateservicechecks" );

    foreach my $sc (@$objs) {
        my $original_attrs = $sc->{_stash}->{original_attrs};

        $object->add_to_servicechecks($sc);

        if ( ref($original_attrs) ne "HASH" ) {
            next;
        }

        if ( defined( my $args = $original_attrs->{exception} ) ) {
            my $item = $object->update_or_create_related(
                "exceptions",
                {
                    servicecheck => $sc,
                    args         => $args
                }
            );
            delete $current_exceptions{ $item->id };
        }

        if ( my $timed_exception = $original_attrs->{timed_exception} ) {
            next unless ref($timed_exception) eq "HASH";

            my $timeperiod = $timed_exception->{timeperiod};
            if ($timeperiod) {
                my $timeperiod_obj = $self->expand_foreign_object(
                    {
                        rel => "timeperiod",
                        rs  => $object->result_source->schema->resultset(
                            "Timeperiods"),
                        search => $timeperiod,
                        errors => $errors,
                    }
                );
                my $args = $timed_exception->{args};

                # TODO: better error message if check timeperiod doesn't exists
                if ( $timeperiod_obj && defined $args ) {
                    my $item = $object->update_or_create_related(
                        "timed_exceptions",
                        {
                            servicecheck => $sc,
                            timeperiod   => $timeperiod_obj,
                            args         => $args
                        }
                    );
                    delete $current_timed_exceptions{ $item->id };
                }
            }
        }
    }

    my $to_delete = [ keys %current_exceptions ];
    $object->delete_related( 'exceptions', { id => $to_delete } );
    $to_delete = [ keys %current_timed_exceptions ];
    $object->delete_related( 'timed_exceptions', { id => $to_delete } );
}

# Need to see if the hosts already exist. If they do, then do not delete
sub synchronise_override_hosts {
    my ( $self, $object, $objs, $errors ) = @_;
    my %current_hosts = map { ( $_->id => $_ ) } $object->hosts;
    foreach my $new_host (@$objs) {
        if ( delete $current_hosts{ $new_host->id } ) {

            # Do nothing as already existed
        }
        else {
            $object->add_to_hosts($new_host);
        }
    }
    foreach my $removed_host ( keys %current_hosts ) {
        $object->remove_from_hosts( $current_hosts{$removed_host} );
    }
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $hosttemplate, $attrs ) = @_;

    # We save the list of hosts currently associated with this host template
    # as we may need to take some action at synchronise_intxn_post
    if ( $self->result_source->schema->resultset("Systempreferences")->find(1)
        ->smart_hosttemplate_removal )
    {
        my %hosts = map { $_->id => $_ } $hosttemplate->hosts;
        $hosttemplate->{_stash}->{hosts} = \%hosts;
    }
}

sub synchronise_intxn_post {
    my ( $self, $hosttemplate, $attrs, $errors ) = @_;

    if ( my $pre = $hosttemplate->{_stash}->{hosts} ) {

        foreach my $h ( $hosttemplate->hosts ) {
            delete $pre->{ $h->id };
        }

        # Get list of servicechecks in this hosttemplate
        my @scids = map { $_->id } $hosttemplate->servicechecks;

        # For each host, check if any other host templates have this servicecheck
        # If not, delete from the host specific service checks
        foreach my $host ( values %$pre ) {
            my %servicechecks_to_remove =
              map { ( $_->id => $_ ) }
              ( $host->servicechecks( { id => { "-in" => \@scids } } ) );
            foreach my $ht ( $host->hosttemplates ) {
                foreach my $sc ( $ht->servicechecks ) {
                    delete $servicechecks_to_remove{ $sc->id };
                }
            }
            $host->hostservicechecks(
                {
                    servicecheckid =>
                      { "-in" => [ keys %servicechecks_to_remove ] }
                }
            )->delete_all;
        }
    }
}

1;
