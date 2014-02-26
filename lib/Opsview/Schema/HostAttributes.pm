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
package Opsview::Schema::HostAttributes;

use strict;
use warnings;

use base "Opsview::DBIx::Class";

__PACKAGE__->load_components(qw/+Opsview::DBIx::Class::Common Validation Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".host_attributes" );
__PACKAGE__->add_columns(
    "host",
    {
        data_type      => "INT",
        default_value  => undef,
        is_foreign_key => 1,
        is_nullable    => 0,
        size           => 11,
    },
    "attribute",
    {
        data_type      => "INT",
        default_value  => undef,
        is_foreign_key => 1,
        is_nullable    => 0,
        size           => 11,
    },
    "value",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 64,
    },
    "arg1",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg2",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg3",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg4",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg5",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg6",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg7",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg8",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
    "arg9",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 1,
        size          => 65535,
    },
);
__PACKAGE__->set_primary_key( "host", "attribute", "value" );
__PACKAGE__->belongs_to( "host", "Opsview::Schema::Hosts", { id => "host" },
    {}, );
__PACKAGE__->belongs_to( "attribute", "Opsview::Schema::Attributes",
    { id => "attribute" }, {}, );

__PACKAGE__->resultset_class( "Opsview::ResultSet::HostAttributes" );

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "value" ) {
        $value =~ s/ +$//;
    }
    $self->next::method( $name, $value );
}

sub allowed_columns {
    [
        qw(name value
          arg1 arg2 arg3 arg4
          )
    ];
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
    if ( delete $serialize_columns->{name} ) {
        $data->{name} = $self->attribute->name;
    }
}

# Returns a lookup hashref of the arg values
sub arg_lookup_hash {
    my ($self)         = @_;
    my $hash           = {};
    my $attribute      = $self->attribute;
    my $attribute_name = $attribute->name;

    $hash->{$attribute_name} = $self->value;

    # TODO: If more than 4 args allowed, increase here
    for ( 1 .. 4 ) {
        my $argname = "arg$_";
        my $val =
          defined $self->$argname ? $self->$argname : $attribute->$argname;
        $hash->{"${attribute_name}:$_"} = $val;
    }
    $hash;
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {

    # Value regexp is based on service check names
    return {
        required           => [qw/value/],
        constraint_methods => {
            value => qr/^[\w .\/-]{1,63}$/,

        },
        msgs => { format => "%s", },
    };
}

1;
