package Opsview::Schema::Roles;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".roles" );
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
        data_type       => "VARCHAR",
        default_value   => undef,
        is_nullable     => 0,
        size            => 128,
        constrain_regex => { regex => '^[\w ,-]+$' }
    },
    "description",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 255
    },
    "priority",
    {
        data_type     => "INT",
        default_value => 1000,
        is_nullable   => 0,
        size          => 11
    },
    "all_hostgroups",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "all_servicegroups",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "all_keywords",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
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
__PACKAGE__->has_many( "contacts", "Opsview::Schema::Contacts",
    { "foreign.role" => "self.id" },
);
__PACKAGE__->has_many(
    "roles_accesses",
    "Opsview::Schema::RolesAccess",
    { "foreign.roleid" => "self.id" },
);
__PACKAGE__->has_many(
    "roles_monitoringservers",
    "Opsview::Schema::RolesMonitoringservers",
    { "foreign.roleid" => "self.id" },
);
__PACKAGE__->has_many(
    "roles_hostgroups",
    "Opsview::Schema::RolesHostgroups",
    { "foreign.roleid" => "self.id" },
);
__PACKAGE__->has_many(
    "role_access_hostgroups",
    "Opsview::Schema::RoleAccessHostgroups",
    { "foreign.roleid" => "self.id" },
);
__PACKAGE__->has_many(
    "role_access_servicegroups",
    "Opsview::Schema::RoleAccessServicegroups",
    { "foreign.roleid" => "self.id" },
);
__PACKAGE__->has_many(
    "role_access_keywords",
    "Opsview::Schema::RoleAccessKeywords",
    { "foreign.roleid" => "self.id" },
);

__PACKAGE__->has_many(
    "sharednotificationprofiles",
    "Opsview::Schema::Sharednotificationprofiles",
    { "foreign.role" => "self.id" },
    {
        cascade_copy   => 0,
        cascade_delete => 0
    },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2oqDF8r0BNjf9sGEGs5AyQ
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
    accesses => "roles_accesses",
    "accessid"
);
__PACKAGE__->many_to_many(
    monitoringservers => "roles_monitoringservers",
    "monitoringserverid"
);
__PACKAGE__->many_to_many(
    hostgroups => "roles_hostgroups",
    "hostgroupid"
);
__PACKAGE__->many_to_many(
    access_hostgroups => "role_access_hostgroups",
    "hostgroupid"
);
__PACKAGE__->many_to_many(
    access_servicegroups => "role_access_servicegroups",
    "servicegroupid"
);
__PACKAGE__->many_to_many(
    access_keywords => "role_access_keywords",
    "keywordid"
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Roles" );

sub allowed_columns {
    [
        qw(id name description uncommitted
          accesses
          monitoringservers
          hostgroups
          contacts
          access_hostgroups access_servicegroups access_keywords
          all_hostgroups all_servicegroups all_keywords
          )
    ];
}

sub relationships_to_related_class {
    {
        "hostgroups" => {
            type  => "multi",
            class => "Opsview::Schema::Hostgroups",
        },
        "accesses" => {
            type  => "multi",
            class => "Opsview::Schema::Access"
        },
        "monitoringservers" => {
            type  => "multi",
            class => "Opsview::Schema::Monitoringservers",
        },
        "access_hostgroups" => {
            type  => "multi",
            class => "Opsview::Schema::Hostgroups",
        },
        "access_servicegroups" => {
            type  => "multi",
            class => "Opsview::Schema::Servicegroups",
        },
        "access_keywords" => {
            type  => "multi",
            class => "Opsview::Schema::Keywords",
        },

        # Even though contacts is a has_many relationship, we make this into a
        # multi to find suitable contacts when editing.
        # I'm sure something is not right here
        "contacts" => {
            type  => "multi",
            class => "Opsview::Schema::Contacts"
        },
    };
}

use Opsview::Utils;

sub has_access {
    my ( $self, $accessname ) = @_;

    return $self->accesses->search_rs( { name => $accessname } )->count > 0;
}

sub allowed_hostgroups_hierarchy {
    my ($self) = @_;
    return $self->result_source->schema->resultset("Hostgroups")->search();
}

sub valid_hostgroups_hierarchy {
    my ($self) = @_;
    my $hg_paths = [ map { $_->matpath . "%" } ( $self->hostgroups->all ) ];
    return $self->result_source->schema->resultset("Hostgroups")
      ->search( { matpath => { "-like" => $hg_paths } } );
}

sub allowed_hostgroups {
    my ($self) = @_;
    return $self->result_source->schema->resultset("Hostgroups")->leaves;
}

sub valid_hostgroups {
    my ($self) = @_;
    if ( $self->all_hostgroups ) {
        return $self->allowed_hostgroups;
    }
    else {
        return $self->access_hostgroups;
    }
}

sub allowed_servicegroups {
    my ($self) = @_;
    return $self->result_source->schema->resultset("Servicegroups")->search();
}

sub valid_servicegroups {
    my ($self) = @_;
    if ( $self->all_servicegroups ) {
        return $self->allowed_servicegroups;
    }
    else {
        return $self->access_servicegroups;
    }
}

sub allowed_keywords {
    my ($self) = @_;

    # Not sure why search() is required, but otherwise will get an error in
    # t/941keywords.t
    return $self->result_source->schema->resultset("Keywords")->search();
}

sub valid_keywords {
    my ($self) = @_;
    return $self->all_keywords
      ? $self->allowed_keywords
      : $self->access_keywords;
}

# Remove all hostgroups,servicegroups,keywords in notificationprofiles table where access now removed
sub remove_objects_from_notificationprofiles {
    my ( $self, $contact_id ) = @_;

    my ( $rs, @valid );
    $rs =
      $self->result_source->schema->resultset("NotificationprofileHostgroups")
      ->search(
        { "role.id" => $self->id },
        { join      => { "notificationprofile" => { "contact" => "role" } } }
      );
    $rs = $rs->search( { "contact.id" => $contact_id } ) if $contact_id;
    @valid = map { $_->id } ( $self->valid_hostgroups->all );
    my @invalid_hostgroups =
      $rs->search( { "hostgroupid" => { -not_in => \@valid } } )->all;
    $_->delete for @invalid_hostgroups;

    $rs = $self->result_source->schema->resultset(
        "NotificationprofileServicegroups")->search(
        { "role.id" => $self->id },
        { join      => { "notificationprofile" => { "contact" => "role" } } }
        );
    $rs = $rs->search( { "contact.id" => $contact_id } ) if $contact_id;
    @valid = map { $_->id } ( $self->valid_servicegroups->all );
    @invalid_hostgroups =
      $rs->search( { "servicegroupid" => { -not_in => \@valid } } )->all;
    $_->delete for @invalid_hostgroups;

    $rs =
      $self->result_source->schema->resultset("NotificationprofileKeywords")
      ->search(
        { "role.id" => $self->id },
        { join      => { "notificationprofile" => { "contact" => "role" } } }
      );
    $rs = $rs->search( { "contact.id" => $contact_id } ) if $contact_id;
    @valid = map { $_->id } ( $self->valid_keywords->all );
    @invalid_hostgroups =
      $rs->search( { "keywordid" => { -not_in => \@valid } } )->all;
    $_->delete for @invalid_hostgroups;

}

sub class_title {"role"}

sub identity_string {
    my $self = shift;
    "id=" . $self->id . " name=" . $self->name;
}

1;
