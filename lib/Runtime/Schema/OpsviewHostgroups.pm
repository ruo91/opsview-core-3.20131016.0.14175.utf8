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
package Runtime::Schema::OpsviewHostgroups;

use strict;
use warnings;

use base 'DBIx::Class', "Opsview::SchemaBase::Hostgroups";

use Opsview::Auditlog;
use Try::Tiny;

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_hostgroups" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "parentid",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 1,
        size          => 11
    },
    "name",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "lft",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "rgt",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "matpath",
    {
        data_type     => "TEXT",
        default_value => "",
        is_nullable   => 0,
        size          => 65535,
    },
    "matpathid",
    {
        data_type     => "TEXT",
        default_value => "",
        is_nullable   => 0,
        size          => 65535,
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->resultset_class( "Runtime::ResultSet::OpsviewHostgroups" );

__PACKAGE__->has_many(
    "hostgroup_hosts",
    "Runtime::Schema::OpsviewHostgroupHosts",
    { "foreign.hostgroup_id" => "self.id" },
    { join_type              => "inner" },
);

__PACKAGE__->has_many(
    "hosts",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.hostgroup_id" => "self.id" },
);

# Sets downtime for this hostgroup and all its leaves
# Returns an arrayref of errors
sub set_downtime {
    my ( $self, $contact_obj, $config ) = @_;
    my $author = $contact_obj->name;
    my $start  = $config->{start_timev};
    my $end    = $config->{end_timev};
    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime scheduled for host group id "
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

    # Use the hostgroup where the downtime was set as the prefix, so that all downtimes are grouped together
    my $this_hostgroupname = $self->name;
    foreach my $hg ( $self->leaves ) {
        try {
            my $comment =
              "Host group '$this_hostgroupname': " . $config->{comment};
            my $cmd = Opsview::Externalcommand->new(
                command => "SCHEDULE_HOSTGROUP_SVC_DOWNTIME",
                args    => $hg->name . ";$start;$end;1;0;;$author;$comment",
            );
            $cmd->submit;
            $cmd = Opsview::Externalcommand->new(
                command => "SCHEDULE_HOSTGROUP_HOST_DOWNTIME",
                args    => $hg->name . ";$start;$end;1;0;;$author;$comment",
            );
            $cmd->submit;
        }
        catch {
            push @errors, "Failure scheduling downtime for host group '"
              . $hg->name . "': $_";
        };
    }
    return \@errors;
}

# Returns a list of host groups at the bottom of the hierarchy
# Returns itself if is already a leaf
sub leaves {
    my $self = shift;
    $self->result_source->schema->resultset("OpsviewHostgroups")->search(
        {
            "-and" => [
                { "lft" => \"=rgt-1" },
                {
                    "lft" => { ">=" => $self->lft },
                    "rgt" => { "<=" => $self->rgt }
                }
            ]
        },
        { order_by => "lft" }
    );
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

    # Arg1=hostname, arg2=servicename, arg3=starttime, arg4=comment
    my $downtime_args = ";;;" . join( ";", $start, $comment );
    $downtime_args =~ s/;+$//;

    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime deleted for host group id "
              . $self->id . " ('"
              . $self->name
              . "'): args '$downtime_args'",
        }
    );
    my @errors;
    foreach my $hg ( $self->leaves ) {
        try {
            my $cmd = Opsview::Externalcommand->new(
                command => "DEL_DOWNTIME_BY_HOSTGROUP_NAME",
                args    => $hg->name . $downtime_args,
            );
            $cmd->submit;
        }
        catch {
            push @errors, "Failure deleting downtime for host group '"
              . $hg->name . "': $_";
        };
    }
    return \@errors;
}

1;
