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

package Runtime::ResultSet::OpsviewViewports;

use strict;
use warnings;

use Opsview::Utils qw(convert_to_arrayref);

use base qw/Runtime::ResultSet/;

sub list_summary {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    $self = $self->search(
        { "opsview_keyword.enabled" => 1 },
        { join                      => "opsview_keyword" }
    );

    # Object specific filtering
    $self = $self->search( { "keyword" => $filters->{keyword} } )
      if exists $filters->{keyword};
    $self = $self->search( { "servicename" => $filters->{servicecheck} } )
      if ( exists $filters->{servicecheck} );
    $self = $self->search( { "hostname" => $filters->{host} } )
      if ( exists $filters->{host} );

    $self->next::method( $filters, $args );
}

sub _downtimes_hash {
    my ( $self, $key ) = @_;
    $self = $self->search( {}, { join => "downtimes" } );
    $self->next::method( "me.keyword" );
}

sub create_summarized_resultset {
    my ( $self, $downtimes, $filters, $args ) = @_;

    $self = $self->search( {}, { join => [ "hoststatus", "servicestatus" ] } );

    #<<<
    $self = $self->search( {},
        {
        "+select" => [
            "opsview_keyword.description",
            "me.keyword AS keyword_name",
            "me.host_object_id",
            \"count(*)",
            "opsview_keyword.exclude_handled",
            ],
        "+as" => [
            "description",
            "keyword_name",
            "host_object_id",
            "total",
            "exclude_handled",
            ],
        group_by => ["me.keyword", "me.host_object_id", "servicestatus.current_state", "service_unhandled"],
        order_by => ["me.keyword", "me.host_object_id"],
        }
    );
    #>>>
    $filters->{summarizeon} = "keyword";
    $self->next::method( $downtimes, $filters, $args );
}

sub restrict_by_user {
    my ( $rs, $user ) = @_;
    unless ( $user->role->all_keywords ) {

        # We need to set this - see set_roleid for why
        # Not sure if using the class here will cause problems, but still seems to load okay
        Opsview::Schema::Keywords->set_roleid( $user->role->id );

        $rs = $rs->search(
            {
                "-or" => [
                    { "keywordroles_or_public.roleid" => $user->role->id },
                    { "opsview_keyword.public"        => 1 }
                ]
            },
            { join => { "opsview_keyword" => "keywordroles_or_public" } }
        );
    }

    return $rs;
}

1;
