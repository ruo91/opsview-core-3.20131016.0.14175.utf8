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
package Runtime::Schema::OpsviewHostObjects;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_host_objects" );
__PACKAGE__->add_columns(
    "host_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "hostname",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 64,
    },
    "object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "name2",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "perfdata_available",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "markdown_filter",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "servicecheck_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "servicegroup_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);

__PACKAGE__->set_primary_key( "object_id" );

__PACKAGE__->has_many(
    "hostgroups",
    "Runtime::Schema::OpsviewHostgroupHosts",
    { "foreign.host_object_id" => "self.host_object_id" },
    { join_type                => "inner" },
);

__PACKAGE__->has_many(
    "events",
    "Runtime::Schema::NagiosStatehistory",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->belongs_to(
    "host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.host_object_id" },
);

# This only exists if the object is actually a service
__PACKAGE__->belongs_to(
    "hostservice",
    "Runtime::Schema::OpsviewHostServices",
    { "foreign.service_object_id" => "self.object_id" }
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->belongs_to(
    "hoststatus",
    "Runtime::Schema::NagiosHoststatus",
    { "foreign.host_object_id" => "self.host_object_id" },
    { join_type                => "inner" }
);
__PACKAGE__->belongs_to(
    "servicestatus",
    "Runtime::Schema::NagiosServicestatus",
    { "foreign.service_object_id" => "self.object_id" },
    { join_type                   => "inner" }
);

__PACKAGE__->has_many(
    "downtimes",
    "Runtime::Schema::NagiosScheduleddowntimes",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" }
);

__PACKAGE__->has_many(
    "comments",
    "Runtime::Schema::NagiosComments",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" }
);

__PACKAGE__->has_many(
    "performance_metrics",
    "Runtime::Schema::OpsviewPerformanceMetrics",
    { "foreign.service_object_id" => "self.object_id" },
    { join_type                   => "inner" }
);

__PACKAGE__->has_many(
    "viewports",
    "Runtime::Schema::OpsviewViewports",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" }
);

__PACKAGE__->might_have(
    "info",
    "Opsview::Schema::Serviceinfo",
    { "foreign.id" => "self.object_id" },
    { proxy        => [qw/information/] }
);

__PACKAGE__->belongs_to(
    "servicecheck",
    "Runtime::Schema::OpsviewServicechecks",
    { "foreign.id" => "self.servicecheck_id" },
);

__PACKAGE__->resultset_class( "Runtime::ResultSet::OpsviewHostObjects" );

sub is_host {
    my ($self) = @_;
    if ( $self->object_id == $self->host_object_id ) {
        return 1;
    }
    return 0;
}

# This is so that there is compatibility between OpsviewHostServices and OpsviewHostObjects
# for the name of the service
*servicename = \&name2;

# This compatibility is for wiki style comments as opsview-web/root/object_info_base expects id to return its information
*id                = \&object_id;
*service_object_id = \&object_id;

sub my_type_is {"service"}

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("ACTIONALL") ) {
        return 1;
    }

    if ( $contact_obj->has_access("ACTIONSOME") ) {
        my $count =
          $self->result_source->schema->resultset("OpsviewHostObjects")
          ->search( { "me.object_id" => $self->object_id },
            { join => "contacts" } )->count;
        return $count ? 1 : 0;
    }

    return 0;
}

sub expand_link_macros {
    my ( $self, $link ) = @_;

    my ($servicecheckname) = ( $self->name2 ) =~ /^([^:]+)/;

    $link =~ s/\$HOSTADDRESS\$/$self->host->ip/eg;
    $link =~ s/\$HOSTNAME\$/$self->hostname/eg;
    $link =~ s/\$SERVICENAME\$/$self->name2/eg;
    $link =~ s/\$SERVICECHECKNAME\$/$servicecheckname/g;

    $link;
}

sub name {
    my $self = shift;
    return $self->name2 . " on " . $self->hostname;
}

# End compatibility

1;
