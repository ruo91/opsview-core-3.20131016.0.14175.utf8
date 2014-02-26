package Opsview::Schema::Hostgroups;

use strict;
use warnings;

use base 'Opsview::DBIx::Class', "Opsview::SchemaBase::Hostgroups";

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".hostgroups" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
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
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
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
        is_nullable   => 0
    },
    "matpathid",
    {
        data_type     => "TEXT",
        default_value => "",
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "id" );

# Remove this unique constraint- not sure how to proceed with this at the moment
# We tell the model layer that matpath is unique. Now this should always be unique due to generation
# but we can't use mysql to force the constraint because of length limitations
#__PACKAGE__->add_unique_constraint( "matpath", ["matpath"] );
__PACKAGE__->has_many(
    "hostgroupinfoes",
    "Opsview::Schema::Hostgroupinfo",
    { "foreign.id" => "self.id" },
);
__PACKAGE__->has_many(
    "notifications",
    "Opsview::Schema::NotificationprofileHostgroups",
    { "foreign.hostgroupid" => "self.id" },
);
__PACKAGE__->belongs_to( "parent", "Opsview::Schema::Hostgroups",
    { id => "parentid" },
);
__PACKAGE__->has_many( "children", "Opsview::Schema::Hostgroups",
    { "foreign.parentid" => "self.id" },
);
__PACKAGE__->has_many( "hostgroups", "Opsview::Schema::Hostgroups",
    { "foreign.parentid" => "self.id" },
);
__PACKAGE__->has_many( "hosts", "Opsview::Schema::Hosts",
    { "foreign.hostgroup" => "self.id" },
);
__PACKAGE__->has_many(
    "keywordhostgroups",
    "Opsview::Schema::Keywordhostgroups",
    { "foreign.hostgroupid" => "self.id" },
);
__PACKAGE__->has_many(
    "roles_hostgroups",
    "Opsview::Schema::RolesHostgroups",
    { "foreign.hostgroupid" => "self.id" },
);
__PACKAGE__->has_many(
    "role_access_hostgroups",
    "Opsview::Schema::RoleAccessHostgroups",
    { "foreign.hostgroupid" => "self.id" },
);

__PACKAGE__->might_have(
    "info",
    "Opsview::Schema::Hostgroupinfo",
    { "foreign.id" => "self.id" },
    { proxy        => [qw/information/] }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dYd8EQ3Zb3mZZbk/80oj6g
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Hostgroups" );
__PACKAGE__->resultset_attributes( { order_by => [ "name", "id" ] } );

__PACKAGE__->many_to_many(
    roles => "roles_monitoringservers",
    "roleid"
);
__PACKAGE__->many_to_many(
    access_roles => "role_access_hostgroups",
    "roleid"
);

use overload
  '""'     => sub { shift->id },
  fallback => 1;

sub allowed_columns {
    [
        qw( id name
          hosts
          parent
          children
          matpath
          uncommitted
          is_leaf
          )
    ];
}

sub relationships_to_related_class {
    {
        "hosts" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
        "parent" => {
            type  => "single",
            class => "Opsview::Schema::Hostgroups",
        },
        "children" => {
            type  => "multi",
            class => "Opsview::Schema::Hostgroups",
        },
    };
}

sub insert {
    my ( $self, @args ) = @_;
    my $res = $self->next::method(@args);
    $self->discard_changes;
    $self->check_parent_with_no_hosts;
    $self->result_source->resultset->add_lft_rgt_values;
    $res;
}

sub delete {
    my ($self) = @_;
    if ( $self->id == 1 ) {
        $self->throw_exception( "Cannot delete top level hostgroup" );
    }

    # Parent inherits children
    my $parent = $self->parentid;
    foreach my $c ( $self->children ) {
        $c->parentid($parent);
        $c->update;
    }
    my $res = $self->next::method();
    $self->result_source->resultset->add_lft_rgt_values;
    $res;
}

sub update {
    my ( $self, @args ) = @_;

    # Need to use this flag to ensure that only changes with parentid cause the
    # lft/rgt regeneration
    my $flag = 0;
    if ( $self->is_column_changed("parentid") ) {
        $flag = 1;
    }
    my $res = $self->next::method(@args);
    if ($flag) {
        $self->check_parent_with_no_hosts;
        $self->result_source->resultset->add_lft_rgt_values;
    }
    $res;

}

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "parentid" ) {
        if ( $value && $self->id && ( $value == $self->id ) ) {
            $self->throw_exception( "Cannot have parent id same as id" );
        }
    }
    elsif ( $name eq "name" ) {
        $self->result_source->resultset->check_duplicate_leaf_name( $value,
            $self->id );
        $self->result_source->resultset->check_name_clash_with_same_parent(
            $self, $value );
    }
    $self->next::method( $name, $value );
}

sub check_parent_with_no_hosts {
    my ($self) = @_;
    if ( $self->id != 1 && $self->parent->hosts->count > 1 ) {
        $self->throw_exception(
            "Cannot set parent if parent already has hosts associated"
        );
    }
}

sub can_see_parent {
    my ( $self, $user ) = @_;
    return unless $user;
    return $self->result_source->resultset->restrict_by_user($user)
      ->count( { id => $self->parentid } );
}

# Copied from Opsview::Hostgroup
sub typeid {
    my $self = shift;
    return "hostgroup" . $self->id;
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
    if ( delete $serialize_columns->{is_leaf} ) {
        $data->{is_leaf} = ( $self->lft == $self->rgt - 1 ) ? 1 : 0;
    }

    # We need to add the parent with the matpath, so that the parent is uniquely identifiable
    if ( delete $serialize_columns->{parent} ) {
        if ( my $parent = $self->parent ) {
            my $hash = {
                name    => $parent->name,
                matpath => $parent->matpath
            };
            $data->{parent} = $hash;
            if ( $options->{ref_prefix} ) {
                $hash->{ref} =
                  join( "/", $options->{ref_prefix}, "hostgroup", $parent->id );
            }
        }
        else {

            # Top level host group
            $data->{parent} = undef;
        }
    }
}

# Returns an array of hash describing the hierarchy for this host group
# [
#  { name => "Opsview", id => 1 },
#  { name => "UK",      id => 4 },
#  { name => "Monitoring Servers", id => 7 },
# ]
sub matpath_hashinfo {
    my ($self) = @_;
    my @info;
    my $mp = $self->matpath;
    $mp =~ s/,$//;
    my $mpid = $self->matpathid;
    $mpid =~ s/,$//;
    my @mp   = split( ",", $mp );
    my @mpid = split( ",", $mpid );

    while ( my $name = shift @mp ) {
        my $id = shift @mpid;
        push @info,
          {
            name => $name,
            id   => $id,
          };
    }
    return \@info;
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w .\/\+-]+$/, },
        msgs               => { format => "%s", },
    };
}

1;
