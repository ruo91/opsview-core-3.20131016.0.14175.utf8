package Opsview::Schema::Contacts;

use strict;
use warnings;

use base qw/Opsview::DBIx::Class Opsview::Base::Contact/;

use Opsview::Config::Web;

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "UTF8Columns", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".contacts" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "fullname",
    {
        data_type       => "VARCHAR",
        default_value   => "",
        is_nullable     => 0,
        size            => 128,
        constrain_regex => { regex => '^[\w ,.\/\+-]+$' }
    },
    "name",
    {
        data_type       => "VARCHAR",
        default_value   => "",
        is_nullable     => 0,
        size            => 128,
        constrain_regex => { regex => '^[\w.\@-]+$' }
    },
    "realm",
    {
        data_type     => "VARCHAR",
        default_value => "local",
        is_nullable   => 1,
        size          => 255,
    },
    "encrypted_password",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "language",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 10,
    },
    "description",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "role",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "show_welcome_page",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 4
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->utf8_columns(qw/description/);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->belongs_to( "role", "Opsview::Schema::Roles", { id => "role" } );
__PACKAGE__->has_many(
    "contact_variables",
    "Opsview::Schema::ContactVariables",
    { "foreign.contactid" => "self.id" },
    { order_by            => "name" }
);
__PACKAGE__->has_many(
    "notificationprofiles",
    "Opsview::Schema::Notificationprofiles",
    { "foreign.contactid" => "self.id" },
);
__PACKAGE__->has_many(
    "contact_objects",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.contactid" => "self.id" },
    { cascade_delete      => 0, }
);

__PACKAGE__->has_many(
    "contact_sharednotificationprofiles",
    "Opsview::Schema::ContactSharednotificationprofile",
    { "foreign.contactid" => "self.id" },
    {
        cascade_copy   => 0,
        cascade_delete => 0
    },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5Kq7DyaekDOiH54cPhwl/w
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Contacts" );
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

__PACKAGE__->many_to_many(
    sharednotificationprofiles => "contact_sharednotificationprofiles",
    "sharednotificationprofileid"
);

# Compatibility. This is okay, as long as you remember the db column is called name with fullname as a more descriptive version
*username = \&name;

# Valid columns
sub allowed_columns {
    [
        qw(id name fullname description realm role
          language
          notificationprofiles
          sharednotificationprofiles
          encrypted_password
          variables uncommitted
          )
    ];
}

# Relationships to classes
# Terrible that we have to specify this again, but belongs in model and not in opsview-web controllers
sub relationships_to_related_class {
    {
        "role" => {
            type  => "single",
            class => "Opsview::Schema::Roles"
        },
        "notificationprofiles" => {
            type  => "has_many",
            class => "Opsview::Schema::Notificationprofiles"
        },
        "sharednotificationprofiles" => {
            type  => "multi",
            class => "Opsview::Schema::Sharednotificationprofiles"
        },
    };
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
    if ( delete $serialize_columns->{notificationprofiles} ) {
        my $sub_options = {};
        $sub_options->{ref_prefix} = $options->{ref_prefix}
          if $options->{ref_prefix};
        $sub_options->{level}++;
        $data->{notificationprofiles} = [];
        foreach my $rel ( $self->notificationprofiles ) {
            my $hash = $rel->serialize_to_hash($sub_options);
            if ( $options->{ref_prefix} ) {
                $hash->{ref} = join( "/",
                    $options->{ref_prefix},
                    "notificationprofile", $rel->id );
            }
            push @{ $data->{notificationprofiles} }, $hash;
        }
    }
}

use Crypt::PasswdMD5 qw/apache_md5_crypt/;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors( qw(access_hashref_cached) );

# This routine compares the password in Opsview database with the given one
sub check_password {
    my ( $self, $password ) = @_;
    my $crypted = $self->encrypted_password;
    return ( apache_md5_crypt( $password, $crypted ) eq $crypted );
}

# This should reside here, but you get warnings due to UTF8Columns - needs investigation
#sub store_column {
#    my ( $self, $name, $value ) = @_;
#    if ( $name eq "password" ) {
#        $value = apache_md5_crypt($value);
#    }
#    $self->next::method( $name, $value );
#}

sub valid_hostgroups {
    my ($self) = @_;
    return $self->role->valid_hostgroups;
}

sub valid_servicegroups {
    my ($self) = @_;
    return $self->role->valid_servicegroups;
}

sub valid_keywords {
    my ($self) = @_;
    return $self->role->valid_keywords;
}

# Compatibility layer with Opsview::Base::Contact
*hostgroups    = \&valid_hostgroups;
*keywords      = \&valid_keywords;
*servicegroups = \&valid_servicegroups;

# Returns a hashref of all accesses for this contact
# Includes contact's role as well as the authenticated role
# TODO: I'm sure this can be optimised
sub access_hashref {
    my ($self) = @_;
    if ( defined $self->access_hashref_cached ) {
        return $self->access_hashref_cached;
    }
    my $access_list = {};

    # We generate a list from this contact's role and the authenticated role in one shot to save a 2nd lookup
    foreach my $access (
        $self->result_source->schema->resultset("Access")->search(
            {
                "roles_accesses.roleid" => [
                    $self->role->id,
                    Opsview::ResultSet::Roles->authenticated_role_id
                ]
            },
            { join => "roles_accesses" }
        )
      )
    {
        my $name = $access->name;
        $access_list->{$name}++;
    }
    return $self->access_hashref_cached($access_list);
}

# Returns a comma separated list of accesses for this contact
sub access_list {
    my ($self) = @_;
    my $h = $self->access_hashref;
    return join( ",", sort keys %$h );
}

# This is the lowest level access checker. May have some higher level ones later
# Returns true if access is allowed
sub has_access {
    my ( $self, @possible_access ) = @_;
    my $access_list = $self->access_hashref;
    for (@possible_access) {
        return 1 if exists $access_list->{$_};
    }
    return 0;
}

sub delete {
    my ( $self, @args ) = @_;
    my @contacts_with_adminaccess =
      $self->result_source->schema->resultset("Contacts")
      ->all_with_access( "ADMINACCESS" );
    if ( scalar @contacts_with_adminaccess == 1
        && $contacts_with_adminaccess[0]->id == $self->id )
    {
        $self->throw_exception( "CannotDeleteAllAdminAccess" );
    }
    my $cfg = Opsview::Config::Web->web_config;
    if (   $cfg->{authtkt_default_username}
        && $cfg->{authtkt_default_username} eq $self->username )
    {
        $self->throw_exception( "CannotDeleteAuthtktDefaultUsername" );
    }
    return $self->next::method(@args);
}

# Returns 1 if can configure, otherwise 0
sub can_configurehost {
    my ( $self, $hostid ) = @_;
    die "Need hostid" unless $hostid;
    my @matpaths = map { $_->matpath } $self->role->hostgroups;
    my $host = $self->result_source->schema->resultset("Hosts")->find($hostid);
    return 0 unless $host;
    my $hostpath = $host->hostgroup->matpath;
    for (@matpaths) {
        return 1 if index( $hostpath, $_ ) == 0;
    }
    return 0;
}

# Looks up variable in joining table
sub variable {
    my ( $self, $name ) = @_;
    my $variable = $self->contact_variables->find( { name => $name } );
    if ($variable) {
        return $variable->value;
    }
    return undef;
}

# Sets variable in joining table
sub set_variable {
    my ( $self, $name, $newval ) = @_;
    my $variable =
      $self->contact_variables->find_or_create( { name => $name } );
    if ($variable) {
        if ( defined $newval ) {
            $variable->update( { value => $newval } );
        }
        return $variable->value;
    }
    return undef;
}

# Returns a hash of all variables
sub variables {
    my ($self) = @_;
    my $vars = { map { $_->name => $_->value } ( $self->contact_variables ) };
    return $vars;
}

sub contact_variables_list {
    my ($self) = @_;
    my $vars = $self->variables;
    return sort keys %$vars;
}

sub contactgroups {
    my $self = shift;
    my @cgs  = ();
    my @sgs  = $self->servicegroups->search(
        {},
        {
            columns      => "id",
            result_class => "DBIx::Class::ResultClass::HashRefInflator"
        }
    );
    foreach my $hg (
        $self->hostgroups->search(
            {},
            {
                columns      => "id",
                result_class => "DBIx::Class::ResultClass::HashRefInflator"
            }
        )
      )
    {
        foreach my $sg (@sgs) {
            push @cgs, "hostgroup" . $hg->{id} . "_servicegroup" . $sg->{id};
        }
    }
    foreach my $k (
        $self->keywords->search(
            {},
            {
                columns => [ "id", "name" ],
                result_class => "DBIx::Class::ResultClass::HashRefInflator"
            }
        )
      )
    {
        push @cgs, "k" . $k->{id} . '_' . $k->{name};
    }
    return @cgs;
}

# This works out what the best host group parent is to be used when adding a new host group
# The rules are:
#   - use the highest non-leaf host group the user has access to, or
#   - find a leaf without any hosts
# It will be a failure if there are no host groups to choose
sub get_highest_hostgroup_parent {
    my ($self) = @_;
    my $res    = {};
    my $role   = $self->role;
    my $hg     = $role->hostgroups->non_leaf->order_by_depth_last->first;
    if ($hg) {
        return {
            hostgroup   => $hg,
            used_parent => 0
        };
    }
    $hg = $role->hostgroups->search_leaves_without_hosts->first;
    if ($hg) {
        return {
            hostgroup   => $hg,
            used_parent => 0
        };
    }
    return undef;
}

__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required => [qw/fullname name/],
        msgs     => { format => "%s", },
    };
}

1;
