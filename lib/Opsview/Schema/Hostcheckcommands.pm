package Opsview::Schema::Hostcheckcommands;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".hostcheckcommands" );
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
    "plugin",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "args",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
        accessor      => "args",
    },
    "priority",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 1,
        size          => 11
    },
    "uncommitted",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "hosts", "Opsview::Schema::Hosts",
    { "foreign.check_command" => "self.id" },
    { "join_type"             => "inner" },
);
__PACKAGE__->belongs_to( "plugin", "Opsview::Schema::Plugins",
    { name => "plugin" }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:au1nQ+NvTn2l3MMEVbGRuA
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Hostcheckcommands" );
__PACKAGE__->resultset_attributes( { order_by => [ "priority", "name" ] } );

sub allowed_columns {
    [
        qw(id name
          plugin args
          hosts
          priority
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "plugin" => {
            type  => "single",
            class => "Opsview::Schema::Plugins",
        },
        "hosts" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
    };
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w\. \/\(\)-]{1,127}$/, },
        msgs               => { format => "%s" },
    };
}

1;
