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
package Runtime::Schema::OpsviewHostServices;

use strict;
use warnings;

use base 'DBIx::Class';
use Opsview::Externalcommand;
use Try::Tiny;
use Opsview::Auditlog;

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_host_services" );
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
    "service_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "servicename",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 128,
    },
    "perfdata_available",
    {
        data_type     => "INT",
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
    "markdown_filter",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "icon_filename",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
);

__PACKAGE__->set_primary_key( "service_object_id" );

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

__PACKAGE__->belongs_to(
    "servicestatus",
    "Runtime::Schema::NagiosServicestatus",
    { "foreign.service_object_id" => "self.service_object_id" },
);

__PACKAGE__->belongs_to(
    "servicegroup",
    "Runtime::Schema::OpsviewServicegroups",
    { "foreign.id" => "self.servicegroup_id" },
);

__PACKAGE__->belongs_to(
    "servicecheck",
    "Runtime::Schema::OpsviewServicechecks",
    { "foreign.id" => "self.servicecheck_id" },
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.service_object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->has_many(
    "keywords",
    "Runtime::Schema::OpsviewViewports",
    { "foreign.object_id" => "self.service_object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->resultset_class( "Runtime::ResultSet::OpsviewHostServices" );

# Compatibility with host and hostgroup objects
*id   = \&service_object_id;
*name = \&servicename;

# Returns an arrayref of errors
sub set_downtime {
    my ( $self, $contact_obj, $config ) = @_;
    my $author = $contact_obj->name;
    my $start  = $config->{start_timev};
    my $end    = $config->{end_timev};
    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime scheduled for service "
              . $self->name . " on "
              . $self->hostname
              . ": starting "
              . scalar localtime($start)
              . ", ending "
              . scalar localtime($end) . ": "
              . $config->{comment},
        }
    );
    my @errors;
    try {
        my $comment =
            "Service '"
          . $self->name
          . "' on host '"
          . $self->hostname . "': "
          . $config->{comment};
        my $cmd = Opsview::Externalcommand->new(
            command => "SCHEDULE_SVC_DOWNTIME",
            args    => $self->hostname . ';'
              . $self->name
              . ";$start;$end;1;0;;$author;$comment",
        );
        $cmd->submit;
    }
    catch {
        push @errors,
          "Failure scheduling downtime for host '" . $self->name . "': $_";
    };
    return \@errors;
}

# Returns an arrayref of errors
sub delete_downtime {
    my ( $self, $contact_obj, $config ) = @_;
    my $author = $contact_obj->name;
    my $start  = "";
    if ( $config->{start_time_dt} ) {
        $start = $config->{start_time_dt}->epoch;
    }
    my $comment = $config->{comment} || "";

    my $downtime_args = ";" . join( ";", $start, $comment );
    $downtime_args =~ s/;+$//;

    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime deleted for service id "
              . $self->id . " ('"
              . join( "::", $self->hostname, $self->name )
              . "'): args '$downtime_args'",
        }
    );
    my @errors;
    try {
        my $cmd = Opsview::Externalcommand->new(
            command => "DEL_DOWNTIME_BY_HOST_NAME",
            args    => $self->hostname . ";" . $self->name . $downtime_args,
        );
        $cmd->submit;
    }
    catch {
        push @errors, "Failure deleting downtime for service '"
          . join( "::", $self->hostname, $self->name ) . "': $_";
    };
    return \@errors;
}

1;
