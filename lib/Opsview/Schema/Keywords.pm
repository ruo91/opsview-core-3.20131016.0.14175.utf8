package Opsview::Schema::Keywords;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components(
    qw/+Opsview::DBIx::Class::Common Validation UTF8Columns Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".keywords" );
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
    "enabled",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "style",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "all_hosts",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "all_servicechecks",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "public",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "show_contextual_menus",
    {
        data_type     => "BOOLEAN",
        default_value => 1,
        is_nullable   => 0,
        size          => 1
    },
    "uncommitted",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
    "exclude_handled",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1
    },
);
__PACKAGE__->utf8_columns(qw/name description/);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "keywordhostgroups",
    "Opsview::Schema::Keywordhostgroups",
    { "foreign.keywordid" => "self.id" },
);
__PACKAGE__->has_many(
    "keywordhosts",
    "Opsview::Schema::Keywordhosts",
    { "foreign.keywordid" => "self.id" },
    { join_type           => "inner" },
);
__PACKAGE__->has_many(
    "keywordhosttemplates",
    "Opsview::Schema::Keywordhosttemplates",
    { "foreign.keywordid" => "self.id" },
);
__PACKAGE__->has_many(
    "keywordservicechecks",
    "Opsview::Schema::Keywordservicechecks",
    { "foreign.keywordid" => "self.id" },
    { join_type           => "inner" },
);
__PACKAGE__->has_many(
    "keywordservicegroups",
    "Opsview::Schema::Keywordservicegroups",
    { "foreign.keywordid" => "self.id" },
);
__PACKAGE__->has_many(
    "notificationprofiles",
    "Opsview::Schema::NotificationprofileKeywords",
    { "foreign.keywordid" => "self.id" },
    { join_type           => "inner" },
);

__PACKAGE__->has_many(
    "keywordroles",
    "Opsview::Schema::RoleAccessKeywords",
    { "foreign.keywordid" => "self.id" },
    { join_type           => "left" }
);

my $viewport_search_roleid = undef;

sub set_roleid {
    my ( $self, $new_roleid ) = @_;
    $viewport_search_roleid = $new_roleid;
}

# This relationship is a sub routine because extra parameters need to be added in for the search.
# DBIx::Class does not currently provide a way of gathering this information with a join relationship
# because of the current viewport_search_roleid value. So everything using the "keywordroles_or_public"
# relationship needs to run set_roleid first (see Opsview::Web::Controller::Viewport->setup_keyword_rs)
# There is a possiblity of doing something like
# __PACKAGE__->has_many( "keywordroles_or_public", "Opsview::Schema::RoleAccessKeywords",
#   { "foreign.keywordid" => "self.id", "foreign.roleid" => "?" },
#   { "join_type" => "left" }
# )
# and calling with:
#  $rs->search( {}, { join => "keywordroles_or_public", args => $roleid } );
# But this requires development in DBIx::Class and would need to check with the project if they will
# take this feature and support moving forward
my $viewports_public_or_specific = sub {
    my $args = shift;

    # Unfortunately, you cannot seem to reset viewport_search_roleid as it is used more than once
    # This technique will have problems in threaded environments
    DBIx::Class::Exception->throw("Roleid not set")
      unless $viewport_search_roleid;
    my $hash = {
        "$args->{foreign_alias}.keywordid" => \"= $args->{self_alias}.id",
        "$args->{foreign_alias}.roleid"    => $viewport_search_roleid,
    };
    return $hash;
};

__PACKAGE__->has_many(
    "keywordroles_or_public", "Opsview::Schema::RoleAccessKeywords",
    $viewports_public_or_specific, { "join_type" => "left" }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iB4l/YNnk8ERKPu22+ATBA
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Keywords" );
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

__PACKAGE__->many_to_many(
    roles => "keywordroles",
    "roleid"
);
__PACKAGE__->many_to_many(
    hosts => "keywordhosts",
    "hostid"
);
__PACKAGE__->many_to_many(
    servicechecks => "keywordservicechecks",
    "servicecheckid"
);

sub allowed_columns {
    [
        qw(id name description
          enabled public style
          all_hosts all_servicechecks
          hosts servicechecks roles
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "hosts" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts"
        },
        "servicechecks" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks"
        },
        "roles" => {
            type  => "multi",
            class => "Opsview::Schema::Roles"
        },
    };
}

# You can replace this text with custom content, and it will be preserved on regeneration
sub count_all_services {
    return Runtime::Searches->count_services_by_keyword(shift);
}

__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w-]{1,128}$/, },
        msgs               => { format => "%s", },
    };
}

1;
