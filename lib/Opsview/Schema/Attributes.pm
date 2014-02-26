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
package Opsview::Schema::Attributes;

use strict;
use warnings;

use base "Opsview::DBIx::Class";

__PACKAGE__->load_components(
    qw/+Opsview::DBIx::Class::Common Validation UTF8Columns Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".attributes" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "INT",
        default_value     => undef,
        is_auto_increment => 1,
        is_nullable       => 0,
        size              => 11,
    },
    "name",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 64,
    },
    "value",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 64,
    },
    "arg1",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg2",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg3",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg4",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg5",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg6",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg7",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg8",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "arg9",
    {
        data_type     => "TEXT",
        default_value => '',
        is_nullable   => 0,
        size          => 65535,
    },
    "internally_generated",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "label1",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label2",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label3",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label4",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label5",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label6",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label7",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label8",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
    },
    "label9",
    {
        data_type     => "VARCHAR",
        default_value => '',
        is_nullable   => 0,
        size          => 16,
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
    "hostattributes",
    "Opsview::Schema::HostAttributes",
    { "foreign.attribute" => "self.id" },
);

__PACKAGE__->has_many(
    "servicechecks",
    "Opsview::Schema::Servicechecks",
    { "foreign.attribute" => "self.id" },
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Attributes" );
__PACKAGE__->resultset_attributes(
    { order_by => [ "internally_generated", "name" ] }
);

__PACKAGE__->many_to_many(
    hosts => 'hostattributes',
    'host'
);

sub allowed_columns {
    [
        qw(id name
          servicechecks
          uncommitted
          value
          arg1 arg2 arg3 arg4
          )
    ];
}

sub relationships_to_related_class {
    {
        "servicechecks" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        },
    };
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {

    # name regexp will need to get changed in Opsview::Schema::Hosts->substitute_host_attributes
    return {
        required           => [qw/name/],
        optional           => [qw/value/],
        constraint_methods => {

            # Changes to characters in an attribute name need to be altered at Opsview::Config->parse_attributes_regexp too
            name  => qr/^[A-Z0-9_]{1,63}$/,
            value => qr/^[\w .\/-]{1,63}$/,
        },
        msgs => { format => "%s", },
    };
}

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "value" ) {
        $value =~ s/ +$//;
    }
    $self->next::method( $name, $value );
}

1;
