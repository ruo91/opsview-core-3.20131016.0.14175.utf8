package Opsview::Schema::Servicegroups;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".servicegroups" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "name",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "keywordservicegroups",
    "Opsview::Schema::Keywordservicegroups",
    { "foreign.servicegroupid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicechecks",
    "Opsview::Schema::Servicechecks",
    { "foreign.servicegroup" => "self.id" },
);
__PACKAGE__->has_many(
    "notificationprofile_servicegroups",
    "Opsview::Schema::NotificationprofileServicegroups",
    { "foreign.servicegroupid" => "self.id" },
);
__PACKAGE__->has_many(
    "role_access_servicegroups",
    "Opsview::Schema::RoleAccessServicegroups",
    { "foreign.servicegroupid" => "self.id" },
);

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

__PACKAGE__->many_to_many(
    access_roles => "role_access_servicegroups",
    "roleid"
);
__PACKAGE__->many_to_many(
    notificationprofiles => "notificationprofile_servicegroups",
    "notificationprofileid"
);
__PACKAGE__->many_to_many(
    keywords => "keywordservicegroups",
    "keywordid"
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Servicegroups" );
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

sub allowed_columns {
    [
        qw(id name
          servicechecks
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "servicechecks" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        }
    };
}

__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w .\/\+-]+$/ },
        msgs               => { format => "%s", },
    };
}

# Class::DBI compatibility - TODO: convert to DBIx::Class
sub class_dbi_obj {
    my $self = shift;
    unless ( exists $self->{opsview_stash}->{class_dbi_obj} ) {
        $self->{opsview_stash}->{class_dbi_obj} =
          Opsview::Servicegroup->retrieve( $self->id );
    }
    return $self->{opsview_stash}->{class_dbi_obj};
}

sub servicechecks_by_object {
    my ( $self, @args ) = @_;
    return $self->class_dbi_obj->servicechecks_by_object(@args);
}

1;
