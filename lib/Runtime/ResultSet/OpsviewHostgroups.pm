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

package Runtime::ResultSet::OpsviewHostgroups;

use strict;
use warnings;

use Opsview::Utils qw(convert_to_arrayref);

use base qw/Runtime::ResultSet/;

sub list_summary {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};
    $args->{extra_columns} = [qw(matpath leaf)];

    # Save this for lookups later
    my $allhgs_rs = $self;

    # Filter by access first
    $self = $self->search( { parentid => $filters->{parentid} } )
      if ( exists $filters->{parentid} );

    # This counts all the host groups that would be returned without object specific
    # filtering. Therefore, this can be used to describe the security permissions of the user
    $args->{totalhgs} = $self->search( {}, { distinct => 1 } )->count;

    # Object specific filtering
    $self = $self->search( { "me.id" => $filters->{hostgroupid} } )
      if ( exists $filters->{hostgroupid} );
    $self =
      $self->search( { "host_objects.name2" => $filters->{servicecheck} } )
      if ( exists $filters->{servicecheck} );
    $self = $self->search( { "host_objects.hostname" => $filters->{host} } )
      if ( exists $filters->{host} );

    if ( exists $filters->{fromhostgroupid} ) {
        my $input  = convert_to_arrayref( $filters->{fromhostgroupid} );
        my $search = [];
        foreach my $p (@$input) {
            my $hg = $allhgs_rs->find( { id => $p } );
            if ($hg) {
                push @$search, $hg->matpath . "%";
            }
        }
        $self = $self->search( { "me.matpath" => { "-like" => $search } } );
    }

    if ( exists $filters->{only_leaves} ) {
        $self = $self->search( { "lft" => \"=rgt-1" } );
    }

    $self->next::method( $filters, $args );
}

sub _downtimes_hash {
    my ( $self, $key ) = @_;
    $self = $self->search(
        {},
        { join => { "hostgroup_hosts" => { "host_objects" => "downtimes" } } }
    );
    $self->next::method( "me.id" );
}

sub create_summarized_resultset {
    my ( $self, $downtimes, $filters, $args ) = @_;

    my $joins = "servicestatus";
    if ( $filters->{include_servicegroups} ) {
        $joins = [ $joins, { "servicecheck" => "servicegroup" } ];
    }
    $self = $self->search(
        {},
        {
            join => {
                hostgroup_hosts =>
                  [ "hoststatus", { "host_objects" => $joins } ]
            },
        }
    );

    my $group_by = [
        "me.id",                       "hostgroup_hosts.host_object_id",
        "servicestatus.current_state", "service_unhandled"
    ];
    if ( $filters->{include_servicegroups} ) {
        push @$group_by, "servicegroup.id";
        $self = $self->search(
            {},
            {
                "+select" => [ "servicegroup.name", ],
                "+as"     => [ "servicegroup_name", ],
            }
        );
    }
    #<<<
    $self = $self->search( {},
        {
        "+select" => [
            "me.id",
            "me.name",
            "hostgroup_hosts.host_object_id",
            \"count(*)",
            ],
        "+as" => [
            "hostgroupid",
            "hostgroup_name",
            "host_object_id",
            "total",
            ],
        group_by => $group_by,
        order_by => ["me.name", "me.id", "hostgroup_hosts.host_object_id"],
        }
    );
    #>>>
    if ( $filters->{order} && $filters->{order} eq "dependency" ) {
        my $order_by = [ "me.lft", "hostgroup_hosts.host_object_id" ];
        if ( $filters->{include_servicegroups} ) {
            push @$order_by, "servicegroup.id";
        }
        $self = $self->search( {}, { order_by => $order_by } );
    }

    my $extracols = $filters->{extra_columns};
    if ( $extracols->{matpath} ) {
        $self = $self->search(
            {},
            {
                "+select" => [ "me.matpath", "me.matpathid", ],
                "+as"     => [ "matpath",    "matpathid", ],
            }
        );
    }

    if ( $extracols->{leaf} ) {
        $self = $self->search(
            {},
            {
                "+select" => [ "(me.lft+1=me.rgt) AS leaf", ],
                "+as"     => [ "leaf", ],
            }
        );
    }

    $filters->{summarizeon} = "hostgroup";
    $self->next::method( $downtimes, $filters, $args );
}

sub restrict_by_user {
    my ( $rs, $user ) = @_;
    $rs = $rs->search(
        { "contacts.contactid" => $user->id },
        { join => { "hostgroup_hosts" => { "host_objects" => "contacts" } } },
    );
    return $rs;
}

1;
