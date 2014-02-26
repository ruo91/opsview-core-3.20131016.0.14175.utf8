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

package Opsview::ResultSet::Hosts;

use strict;
use warnings;
use Carp;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

sub auto_create_foreign {
    { "keywords" => 1, };
}

sub synchronise_allowed_duplicates {
    { "hostattributes" => 1, };
}

# synchronise function moved into ResultSet.pm
# Only model specific hooks left here
sub synchronise_pre_txn {
    my ( $self, $attrs, $errors ) = @_;

    if ( $attrs->{hostgroup} ) {

        # Should already be expanded out
        my $obj = $attrs->{hostgroup};
        unless ( $obj->is_leaf ) {
            push @$errors, "Host group is not a leaf";
        }
    }
}

sub synchronise_intxn_pre_insert {
    my ( $self, $object, $attrs, $errors ) = @_;

    # Special case: Check host group is a leaf. Can't seem to do at Schema level, so need to do here
    # Only applies when inserting
    # If a CONFIGUREHOSTS user adds no hostgroup (impossible in web UI), then it is possible the host will get
    # added to a host group they cannot access - this should be okay from a model perspective
    if ( !$attrs->{hostgroup} ) {
        my ($first_alphabetic_leaf_hostgroup) =
          $self->result_source->schema->resultset("Hostgroups")
          ->search( { lft => \"= (rgt-1)" }, { order_by => "lft" } )->first;
        $object->hostgroup($first_alphabetic_leaf_hostgroup);
    }

    # We need this here to cover new hosts added. Opsview::Schema::Hosts::store_columns() will sort out
    # updates
    if ( !$attrs->{icon} ) {
        my $default_icon = "LOGO - Opsview";
        $object->icon($default_icon);
    }
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $host, $attrs ) = @_;
    if ( my $objs = delete $attrs->{hosttemplates} ) {

        my %old_hosttemplates;
        if ( $self->result_source->schema->resultset("Systempreferences")
            ->find(1)->smart_hosttemplate_removal )
        {
            %old_hosttemplates = map { $_->id => $_ } ( $host->hosttemplates );
        }

        $host->delete_related( 'hosthosttemplates' );
        my $priority = 1;
        foreach my $ht (@$objs) {
            delete $old_hosttemplates{ $ht->id };
            $host->add_to_hosttemplates( $ht, { priority => $priority } );
            $priority++;
        }

        # Anything left in old_hosttemplates has been removed - mark for later deletion
        # in synchronise_intxn_post because servicechecks might have been assigned later
        $host->{_stash}->{hosttemplates_removed} = \%old_hosttemplates;
    }

    # Remove parent if same as self
    if ( $attrs->{parents} ) {
        $attrs->{parents} =
          [ grep { $_->id != $host->id } @{ $attrs->{parents} } ];
    }
}

sub synchronise_override_servicechecks {
    my ( $self, $host, $objs, $errors ) = @_;

    my %current_exceptions =
      map { ( $_->id => 1 ) } ( $host->search_related("exceptions") );
    my %current_timed_exceptions =
      map { ( $_->id => 1 ) } ( $host->search_related("timed_exceptions") );
    $host->delete_related( 'event_handlers' );
    $host->delete_related( "hostservicechecks" );

    foreach my $sc (@$objs) {

        my $original_attrs      = $sc->{_stash}->{original_attrs};
        my $remove_servicecheck = 0;

        if ( ref($original_attrs) eq "HASH" ) {
            $remove_servicecheck = $original_attrs->{remove_servicecheck} || 0;
        }

        $host->add_to_servicechecks( $sc,
            { remove_servicecheck => $remove_servicecheck }
        );

        # Need this if primary key id is used to reference servicechecks
        if ( ref($original_attrs) ne "HASH" ) {
            next;
        }

        # Event handler
        my $command = $sc->{_stash}->{original_attrs}->{event_handler};
        if ($command) {
            $host->add_to_event_handlers(
                {
                    servicecheck  => $sc,
                    event_handler => $command
                }
            );
        }

        # Exceptions
        if (
            defined( my $args = $sc->{_stash}->{original_attrs}->{exception} ) )
        {
            my $item = $host->update_or_create_related(
                "exceptions",
                {
                    servicecheck => $sc,
                    args         => $args
                }
            );
            delete $current_exceptions{ $item->id };
        }

        # Timed exceptions
        if ( my $timed_exception =
            $sc->{_stash}->{original_attrs}->{timed_exception} )
        {

            # TODO: need to error here
            next unless ref($timed_exception) eq "HASH";

            my $timeperiod = $timed_exception->{timeperiod};

            if ($timeperiod) {
                my $timeperiod_obj = $self->expand_foreign_object(
                    {
                        rel => "timeperiod",
                        rs  => $host->result_source->schema->resultset(
                            "Timeperiods"),
                        search => $timeperiod,
                        errors => $errors,
                    }
                );
                my $args = $timed_exception->{args};

                # TODO: better error message if check timeperiod doesn't exists
                if ( $timeperiod_obj && defined $args ) {
                    my $item = $host->update_or_create_related(
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

    # Delete all unrelated items not listed
    my $to_delete;
    $to_delete = [ keys %current_timed_exceptions ];
    $host->delete_related( 'timed_exceptions', { id => $to_delete } );
    $to_delete = [ keys %current_exceptions ];
    $host->delete_related( 'exceptions', { id => $to_delete } );
}

sub synchronise_intxn_post {
    my ( $self, $host, $attrs, $errors ) = @_;
    if ( my $objs = $attrs->{snmpinterfaces} ) {
        $host->set_all_snmpinterfaces( convert_to_arrayref($objs) );
    }

    if ( my $hts_to_delete = $host->{_stash}->{hosttemplates_removed} ) {
        foreach my $ht_to_delete ( values %$hts_to_delete ) {
            my %servicechecks_to_remove =
              map { ( $_->id => $_ ) } ( $ht_to_delete->servicechecks );
            foreach my $ht_live ( $host->hosttemplates ) {
                foreach my $sc ( $ht_live->servicechecks ) {
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

sub synchronise_override_hostattributes {
    my ( $self, $host, $objs, $errors ) = @_;

    # Variables. Can't use Opsview::ResultSet::synchronise_handle_variables as there is more stuff required for host variables
    $host->delete_related( "hostattributes" );
    my $seen = {};
    foreach my $obj (@$objs) {
        my $args        = $obj->{_stash}->{original_attrs};
        my $attributeid = $obj->id;
        my $value       = $args->{value};
        if ( defined $value ) {
            if ( exists $seen->{$attributeid}->{$value} ) {
                push @$errors,
                    "attributes duplicated for name '"
                  . $obj->name
                  . "', value '$value'";
                next;
            }
            $seen->{$attributeid}->{$value}++;
            my $data = {
                attribute => $obj->id,
                value     => $value,
            };
            foreach my $i ( 1 .. 9 ) {
                my $a = "arg$i";
                $data->{$a} = $args->{$a};
            }
            $host->add_to_hostattributes($data);
        }
    }
}

# Args can be: parents => 1 (list existing parents)
sub search_parents_by_filter {
    my ( $self, $args ) = @_;

    if ( $args->{parents} ) {
        $self = $self->search( {}, { join => "parents_parentids" } );
    }
    $self = $self->search(
        {},
        {
            distinct => 1,
            order_by => "me.name"
        }
    );
    return $self;
}

# Returns a lookup hash with values of a list ref of hostnames which are the parents
# Used to return host objects, but the only thing used with this was to
# get the name, so this is a good optimisation
sub calculate_parents {
    my ( $self, $args ) = @_;

    # Rather than calculate again, can pass through a calculation already
    my $monitoringserverhosts_lookup = $args->{monitoringserverhosts_lookup}
      || $self->result_source->schema->resultset("Monitoringservers")
      ->monitoringserverhosts_lookup;
    my $monitors_lookup = $args->{monitors_lookup};

    my $parents_lookup = {};

    my $slavefilter;
    my $masterhost;
    my $rs = $self;
    if ( $slavefilter = $args->{filter_by_monitoringserver} ) {
        $rs = $rs->search( { monitored_by => $slavefilter } );

        # Calculate if not passed information through
        unless ($monitors_lookup) {
            map { $monitors_lookup->{ $_->id } = 1 }
              ( $rs->search( {}, { columns => ["id"] } ) );
        }
    }
    else {
        $masterhost =
          $self->result_source->schema->resultset("Monitoringservers")->find(1)
          ->host;
    }

    # Use caching as mshosts is very expensive
    my $cached_mshosts = {};

    # Create a lookup for all parents in DB first
    my $parents_in_database = {};
    foreach my $host (
        $rs->search(
            {},
            {
                join         => "parents_parentids",
                select       => [qw(parents_parentids.hostid me.id me.name)],
                as           => [qw(thisid parentid parentname)],
                result_class => "DBIx::Class::ResultClass::HashRefInflator"
            }
        )
      )
    {
        next if ( $host->{thisid} == $host->{parentid} );
        push @{ $parents_in_database->{ $host->{thisid} } },
          {
            id   => $host->{parentid},
            name => $host->{parentname}
          };
    }

    foreach my $host (
        $rs->search(
            {},
            {
                prefetch => "monitored_by",
                columns  => ["id"]
            }
        )
      )
    {
        my @parents = ();

        foreach my $p ( @{ $parents_in_database->{ $host->id } || [] } ) {
            if ($slavefilter) {

                # Remove parents where there don't exist on this monitoring server
                next
                  unless ( $monitors_lookup
                    && exists $monitors_lookup->{ $p->{id} } );
            }
            push @parents, $p->{name};
        }

        # If no parents, set to the monitoring server
        if ( !@parents ) {

            # If this host is used as a monitoring server, set slaves to have master as parent
            my $ms = $monitoringserverhosts_lookup->{ $host->id };
            if ($ms) {
                if ( !$slavefilter && $ms->is_slave ) {
                    @parents = ( $masterhost->name );
                }
            }
            else {
                my $ms = $host->monitored_by;
                unless ( exists $cached_mshosts->{ $ms->id } ) {
                    $cached_mshosts->{ $ms->id } = [ $ms->mshosts ];
                }
                my $p = $cached_mshosts->{ $ms->id };
                foreach my $slavenode (@$p) {
                    if (
                        !$slavefilter
                        || (   $monitors_lookup
                            && $monitors_lookup->{ $slavenode->id } )
                      )
                    {
                        push @parents, $slavenode->name;
                    }
                }
            }
        }

        $parents_lookup->{ $host->id } = \@parents;
    }

    $parents_lookup;
}

sub restrict_by_user {
    my ( $self, $user ) = @_;
    my $hg_paths = [ map { $_->matpath . '%' } $user->role->hostgroups ];
    return $self->search(
        { 'hostgroup.matpath' => { '-like' => $hg_paths }, },
        { join                => "hostgroup", }
    );
}

1;
