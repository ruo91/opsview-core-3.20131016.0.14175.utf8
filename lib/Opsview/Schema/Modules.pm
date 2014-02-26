package Opsview::Schema::Modules;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".modules" );
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
        default_value => undef,
        is_nullable   => 0,
        size          => 128,
    },
    "url",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 255,
    },
    "description",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 255,
    },
    "access",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 128,
    },
    "enabled",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 1,
        size          => 4
    },
    "priority",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "version",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 16,
    },
    "namespace",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255,
    },
    "installed",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "namespace", ["namespace"] );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-01-12 13:31:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cyIpe18/1GDS3Lse2z6uZA

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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Module" );

sub class_title {"role"}

sub identity_string {
    my $self = shift;
    "id=" . $self->id . " name=" . $self->name;
}

1;
