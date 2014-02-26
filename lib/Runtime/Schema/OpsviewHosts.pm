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
package Runtime::Schema::OpsviewHosts;

use strict;
use warnings;

use base 'DBIx::Class';
use Opsview::Externalcommand;
use Try::Tiny;
use Opsview::Auditlog;

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_hosts" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "opsview_host_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "name",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 64,
    },
    "ip",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "alias",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "icon_filename",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 128,
    },
    "hostgroup_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "monitored_by",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "primary_node",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "secondary_node",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "num_interfaces",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "num_services",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "num_children",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->belongs_to(
    "hostgroup",
    "Runtime::Schema::OpsviewHostgroups",
    { "foreign.id" => "self.hostgroup_id" },
);

__PACKAGE__->has_many(
    "hostgroups",
    "Runtime::Schema::OpsviewHostgroupHosts",
    { "foreign.host_object_id" => "self.id" },
    { join_type                => "inner" }
);

__PACKAGE__->has_many(
    "host_objects",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.host_object_id" => "self.id" },
    { join_type                => "inner" }
);

__PACKAGE__->has_many(
    "host_services",
    "Runtime::Schema::OpsviewHostServices",
    { "foreign.host_object_id" => "self.id" },
);

__PACKAGE__->belongs_to(
    "hoststatus",
    "Runtime::Schema::NagiosHoststatus",
    { "foreign.host_object_id" => "self.id" },
    { join_type                => "inner" }
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.id" },
    { join_type           => "inner" },
);

__PACKAGE__->has_many(
    "comments",
    "Runtime::Schema::NagiosComments",
    { "foreign.object_id" => "self.id" },
    { join_type           => "inner" }
);

__PACKAGE__->belongs_to(
    "configuration_host", "Opsview::Schema::Hosts",
    { "foreign.id" => "self.opsview_host_id" }, { join_type => "inner" }
);

__PACKAGE__->might_have(
    "info", "Opsview::Schema::Hostinfo",
    { "foreign.id" => "self.opsview_host_id" },
    { proxy        => [qw/information/] }
);

__PACKAGE__->has_many(
    "matpaths",
    "Runtime::Schema::OpsviewHostsMatpaths",
    { "foreign.object_id" => "self.id" },
);

__PACKAGE__->resultset_class( "Runtime::ResultSet::OpsviewHosts" );

# Returns an arrayref of errors
sub set_downtime {
    my ( $self, $contact_obj, $config ) = @_;
    my $author = "";
    if ( ref $contact_obj ) {
        if ( my $method = $contact_obj->can('name') ) {
            $author = $method->($contact_obj);
        }
    }
    my $start = $config->{start_timev};
    my $end   = $config->{end_timev};
    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime scheduled for host id "
              . $self->id . " ('"
              . $self->name
              . "'): starting "
              . scalar localtime($start)
              . ", ending "
              . scalar localtime($end) . ": "
              . $config->{comment},
        }
    );
    my @errors;
    try {
        my $comment = "Host '" . $self->name . "': " . $config->{comment};
        my $cmd     = Opsview::Externalcommand->new(
            command => "SCHEDULE_HOST_SVC_DOWNTIME",
            args    => $self->name . ";$start;$end;1;0;;$author;$comment",
        );
        $cmd->submit;
        $cmd = Opsview::Externalcommand->new(
            command => "SCHEDULE_HOST_DOWNTIME",
            args    => $self->name . ";$start;$end;1;0;;$author;$comment",
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

    my $downtime_args = ";;$start;$comment";
    $downtime_args =~ s/;+$//;

    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime deleted for host id "
              . $self->id . " ('"
              . $self->name
              . "'): args '$downtime_args'",
        }
    );
    my @errors;
    try {
        my $cmd = Opsview::Externalcommand->new(
            command => "DEL_DOWNTIME_BY_HOST_NAME",
            args    => $self->name . $downtime_args,
        );
        $cmd->submit;
    }
    catch {
        push @errors,
          "Failure deleting downtime for host '" . $self->name . "': $_";
    };
    return \@errors;
}

# Compatibility for info wiki
sub my_type_is {"host"}

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("ACTIONALL") ) {
        return 1;
    }

    if ( $contact_obj->has_access("ACTIONSOME") ) {
        my $count =
          $self->result_source->schema->resultset("OpsviewHostObjects")
          ->search( { "me.object_id" => $self->id }, { join => "contacts" } )
          ->count;
        return $count ? 1 : 0;
    }

    return 0;
}

sub expand_link_macros {
    my ( $self, $link ) = @_;

    $link =~ s/\$HOSTADDRESS\$/$self->ip/eg;
    $link =~ s/\$HOSTNAME\$/$self->name/eg;

    $link;
}

1;
