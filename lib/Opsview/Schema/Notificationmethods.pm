package Opsview::Schema::Notificationmethods;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".notificationmethods" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "active",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 1
    },
    "name",
    {
        data_type       => "VARCHAR",
        default_value   => "",
        is_nullable     => 0,
        size            => 64,
        constrain_regex => { regex => '^[a-zA-Z0-9 -]+$' }
    },
    "namespace",
    {
        data_type       => "VARCHAR",
        default_value   => "",
        is_nullable     => 0,
        size            => 255,
        constrain_regex => { regex => '^[a-zA-Z0-9\.-]+$' }
    },
    "master",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 1
    },
    "command",
    {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 1,
        size            => 65535,
        constrain_regex => { regex => '^[a-zA-Z0-9][^\$`\(\)/!*?^%]+$' },
    },
    "priority",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "uncommitted",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "contact_variables",
    {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 1,
        size            => 65535,
        constrain_regex => { regex => '^[\w,]*$' },
    },

);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "variables",
    "Opsview::Schema::NotificationmethodVariables",
    { "foreign.notificationmethodid" => "self.id" },
    { order_by                       => "name" }
);
__PACKAGE__->has_many(
    "notificationprofile_notificationmethods",
    "Opsview::Schema::NotificationprofileNotificationmethods",
    { "foreign.notificationmethodid" => "self.id" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zkin5gLhYav0eZCTtP12/Q
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

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->resultset_class( "Opsview::ResultSet::Notificationmethods" );
__PACKAGE__->resultset_attributes( { order_by => ["priority"] } );

__PACKAGE__->many_to_many(
    notificationprofiles => "notificationprofile_notificationmethods",
    "notificationprofile"
);

sub allowed_columns {
    [
        qw(id name active
          namespace master command
          contact_variables
          notificationprofiles
          uncommitted
          )

          # TODO:
          # variables
    ];
}

sub relationships_to_related_class {
    {
        "notificationprofiles" => {
            type  => "multi",
            class => "Opsview::Schema::Notificationprofiles",
        },
    };
}

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "contact_variables" && $value ) {
        $value = uc $value;
    }
    if ( $name eq "name" && $value ) {
        unless ( $self->namespace ) {
            my $default_namespace = $value;
            $default_namespace =~ s/ //g;
            $self->namespace($default_namespace);
        }
    }
    $self->next::method( $name, $value );
}

sub command_line {
    my $self    = shift;
    my $command = "/usr/local/nagios/libexec/notifications/" . $self->command;
}

sub nagios_name {
    my $self = shift;
    my $name = $self->name;
    $name =~ s/ /-/g;
    lc $name;
}

sub required_variables_list {
    my $self = shift;
    return split( ",", $self->contact_variables || "" );
}

sub class_title {"notificationmethod"}

sub identity_string {
    my $self = shift;
    "id=" . $self->id . " name=" . $self->name;
}

1;
