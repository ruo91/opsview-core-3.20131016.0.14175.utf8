package Opsview::Schema::Hosttemplates;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components(qw/+Opsview::DBIx::Class::Common Validation Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".hosttemplates" );
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
    "description",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "hosthosttemplates",
    "Opsview::Schema::Hosthosttemplates",
    { "foreign.hosttemplateid" => "self.id" },
);
__PACKAGE__->has_many(
    "managementurls",
    "Opsview::Schema::Hosttemplatemanagementurls",
    { "foreign.hosttemplateid" => "self.id" },
);
__PACKAGE__->has_many(
    "hosttemplateservicechecks",
    "Opsview::Schema::Hosttemplateservicechecks",
    { "foreign.hosttemplateid" => "self.id" },
);
__PACKAGE__->has_many(
    "keywordhosttemplates",
    "Opsview::Schema::Keywordhosttemplates",
    { "foreign.hosttemplateid" => "self.id" },
);
__PACKAGE__->has_many(
    "exceptions",
    "Opsview::Schema::Servicecheckhosttemplateexceptions",
    { "foreign.hosttemplate" => "self.id" },
);
__PACKAGE__->has_many(
    "timed_exceptions",
    "Opsview::Schema::Servicechecktimedoverridehosttemplateexceptions",
    { "foreign.hosttemplate" => "self.id" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wAgNHlsFfSggpW8yPi7gnA
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

__PACKAGE__->many_to_many(
    servicechecks => 'hosttemplateservicechecks',
    'servicecheckid'
);
__PACKAGE__->many_to_many(
    hosts => 'hosthosttemplates',
    'hostid'
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Hosttemplates" );
__PACKAGE__->resultset_attributes( { order_by => "name" } );

sub allowed_columns {
    [
        qw(id name description uncommitted
          hosts
          servicechecks
          managementurls
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "hosts" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
        "servicechecks" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        },
        "managementurls" => {
            type  => "has_many",
            class => "Opsview::Schema::Hosttemplatemanagementurls",
        },
    };
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
    if ( delete $serialize_columns->{servicechecks} ) {

        my %exceptions =
          map { ( $_->servicecheck->id => $_ ) } $self->exceptions;
        my %timed_exceptions =
          map { ( $_->servicecheck->id => $_ ) } $self->timed_exceptions;

        $data->{servicechecks} = [];
        foreach my $rel ( $self->servicechecks ) {
            my $hash = { name => $rel->name };
            if ( $options->{ref_prefix} ) {
                $hash->{ref} =
                  join( "/", $options->{ref_prefix}, "servicecheck", $rel->id );
            }

            if ( my $ex = $exceptions{ $rel->id } ) {
                $hash->{exception} = $ex->args;
            }
            else {
                $hash->{exception} = undef;
            }

            if ( my $timed = $timed_exceptions{ $rel->id } ) {
                $hash->{timed_exception} = {
                    args       => $timed->args,
                    timeperiod => { name => $timed->timeperiod->name }
                };
            }
            else {
                $hash->{timed_exception} = undef;
            }

            push @{ $data->{servicechecks} }, $hash;
        }

    }
    if ( delete $serialize_columns->{managementurls} ) {
        my $sub_options = {};
        $sub_options->{ref_prefix} = $options->{ref_prefix}
          if $options->{ref_prefix};
        $sub_options->{level}++;
        $data->{managementurls} = [];
        foreach my $rel ( $self->managementurls ) {
            my $hash = $rel->serialize_to_hash($sub_options);
            push @{ $data->{managementurls} }, $hash;
        }
    }
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w \.-]{1,127}$/, },
        msgs               => { format => "%s", },
    };
}

1;
