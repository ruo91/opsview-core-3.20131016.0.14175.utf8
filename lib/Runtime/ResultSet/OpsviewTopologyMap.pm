#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#

package Runtime::ResultSet::OpsviewTopologyMap;

use strict;
use warnings;

use Opsview::Utils
  qw(convert_to_arrayref convert_state_to_text convert_host_state_to_text convert_state_type_to_text set_highest_service_state get_first_hash_key);
use List::MoreUtils qw( uniq );

use base qw/Runtime::ResultSet/;

# This handles all the filtering, based on parameters coming in
sub filter_objects {
    my ( $self, $filters, $args ) = @_;

    my $num_filters    = 0;
    my $service_search = 0;

    # Host groups
    my @hostgroupids;
    if ( exists $filters->{hostgroupid} ) {
        @hostgroupids = @{ convert_to_arrayref( $filters->{hostgroupid} ) };
    }
    if (@hostgroupids) {
        $self = $self->search(
            { "hostgroups.hostgroup_id" => \@hostgroupids },
            { join                      => "hostgroups" }
        );
        $num_filters++;
    }

    # Host names
    my $hostnames = get_first_hash_key( $filters, "hostname", "host" );
    if ( defined $hostnames ) {
        $self = $self->search( { "me.name" => { "-like" => $hostnames } } );
        $num_filters++;
    }
    if ( exists $filters->{hostid} ) {
        $self = $self->search( { "me.object_id" => $filters->{hostid} } );
        $num_filters++;
    }

    # Root host
    if ( exists $filters->{fromhostname} ) {
        my $hostnames = convert_to_arrayref( $filters->{fromhostname} );
        my @matpaths =
          map { $_->{matpath} . "%" }
          $self->result_source->schema->resultset("OpsviewHosts")->search(
            { "me.name" => $hostnames },
            {
                result_class => "DBIx::Class::ResultClass::HashRefInflator",
                join         => 'matpaths',
                select       => 'matpaths.matpath',
                as           => 'matpath',
            }
          )->all;
        $self = $self->search(
            { 'matpaths.matpath' => { '-like' => [ uniq(@matpaths) ] } },
        );
        $num_filters++;
    }

    # Monitoring server
    if ( exists $filters->{monitoredby} ) {
        $self =
          $self->search( { "me.monitored_by" => $filters->{monitoredby} }, );
        $num_filters++;
    }

    # Only with children
    if ( $filters->{only_with_children} ) {
        $self = $self->search(
            { "host.num_children" => { '!=' => 0 } },
            { 'join'              => 'host', }
        );
        $num_filters++;
    }

    if ( $args->{restricted_contactid} ) {
        $self = $self->search(
            {},
            {
                '+select' => [
                    \'IF(ISNULL(parent_contacts.contactid),0,1)',
                    \'IF(ISNULL(child_contacts.contactid),0,1)',
                ],
                '+as' => [
                    qw(
                      parent_visible
                      child_visible
                      )
                ],
                join     => [qw( parent_contacts child_contacts )],
                group_by => [
                    qw(
                      me.id me.parent_object_id me.child_object_id
                      )
                ],
            }
        );
        $num_filters++;
    }
    else {
        $self = $self->search(
            {},
            {
                '+select' => [ \'1', \'1', ],
                '+as'     => [
                    qw(
                      parent_visible
                      child_visible
                      )
                ],
                group_by => [
                    qw(
                      me.id me.parent_object_id me.child_object_id
                      )
                ],
            }
        );
    }

    # If inclusive, then make search fail to return any objects if no filtering is applied
    if ( $args->{inclusive} && $num_filters == 0 ) {
        $self = $self->search( { 1 => 0 } );
    }

    return $self;
}

sub list_topology {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    # all accessible by current contact hosts
    my $total = $self->search(
        {},
        {
            columns  => ['opsview_host_id'],
            group_by => 'opsview_host_id'
        }
    )->count;

    # We order by matpath.depth to get the list in some sort of "importance order"
    # This is needed for Dashboard's network map
    my $opts = {
        result_class => "DBIx::Class::ResultClass::HashRefInflator",
        columns      => [
            qw( opsview_host_id name parent_id parent_name child_id child_name )
        ],
        join => { host => "matpaths" },
        order_by => [ "matpaths.depth", "me.id" ],
    };
    $self = $self->search( {}, $opts, );

    # filter objects (hostgrups/monitored by etc.)
    $self = $self->filter_objects( $filters, $args );

    my @list          = ();
    my $req_limit     = $filters->{rows} ? $filters->{rows} - 1 : 0;
    my $limit_reached = -1;
    my %host_ids      = ();

    while ( my $row = $self->next ) {
        my $new_host;
        unless ( exists $host_ids{ $row->{opsview_host_id} } ) {
            $host_ids{ $row->{opsview_host_id} } = {
                name     => $row->{name},
                parents  => [],
                children => [],
            };
            $new_host++;
        }
        next if $limit_reached > 0;

        my $this_host = $host_ids{ $row->{opsview_host_id} };

        if ($new_host) {

            # loaded all host parents and children - now just count allrows
            if ( $limit_reached == 0 ) {
                $limit_reached = 1;
                next;

                # reached last host - now load parents and children
            }
            elsif ( $req_limit && scalar @list >= $req_limit ) {
                $limit_reached = 0;
            }

            push @list, $this_host;

        }
        if ( $row->{parent_id} ) {
            push @{ $this_host->{parents} },
              $row->{parent_visible} ? $row->{parent_name} : undef;
        }
        if ( $row->{child_id} ) {
            push @{ $this_host->{children} },
              $row->{child_visible} ? $row->{child_name} : undef;
        }
    }

    return {
        list    => \@list,
        rows    => scalar @list,
        allrows => scalar keys %host_ids,
        total   => $total,
    };
}

sub restrict_by_user {
    my ( $rs, $user ) = @_;
    $rs = $rs->search(
        { "contacts.contactid" => $user->id },
        { join                 => 'contacts' },
    );
    return $rs;
}

1;
