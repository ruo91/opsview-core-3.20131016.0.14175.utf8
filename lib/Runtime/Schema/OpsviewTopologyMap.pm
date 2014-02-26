#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#
package Runtime::Schema::OpsviewTopologyMap;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::OpsviewTopologyMap

=cut

__PACKAGE__->table( "opsview_topology_map" );

__PACKAGE__->add_columns(
    "id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "monitored_by",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "object_id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "host_id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "opsview_host_id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "name",
    {
        data_type   => "varchar",
        is_nullable => 0,
        size        => 64
    },
    "parent_id",
    {
        data_type   => "integer",
        is_nullable => 1
    },
    "parent_object_id",
    {
        data_type   => "integer",
        is_nullable => 1
    },
    "parent_name",
    {
        data_type   => "varchar",
        is_nullable => 1,
        size        => 64
    },
    "child_id",
    {
        data_type   => "integer",
        is_nullable => 1
    },
    "child_object_id",
    {
        data_type   => "integer",
        is_nullable => 1
    },
    "child_name",
    {
        data_type   => "varchar",
        is_nullable => 1,
        size        => 64
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->has_many(
    "hostgroups",
    "Runtime::Schema::OpsviewHostgroupHosts",
    { "foreign.host_object_id" => "self.object_id" },
    { join_type                => "inner" }
);

__PACKAGE__->belongs_to(
    "host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.object_id" },
);

__PACKAGE__->belongs_to(
    "parent_host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.parent_id" },
);

__PACKAGE__->belongs_to(
    "child_host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.child_id" },
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

# WARNING: both parent_contacts and child_contacts require that "contacts" is
# also joined
__PACKAGE__->belongs_to(
    "parent_contacts",
    "Runtime::Schema::OpsviewContactObjects",
    sub {
        my $args = shift;
        return {
            "$args->{foreign_alias}.object_id" =>
              { -ident => "$args->{self_alias}.parent_object_id" },
            "$args->{foreign_alias}.contactid" =>
              { -ident => "contacts.contactid" },
        };
    },
    { join_type => 'left' }
);

__PACKAGE__->belongs_to(
    "child_contacts",
    "Runtime::Schema::OpsviewContactObjects",
    sub {
        my $args = shift;
        return {
            "$args->{foreign_alias}.object_id" =>
              { -ident => "$args->{self_alias}.child_object_id" },
            "$args->{foreign_alias}.contactid" =>
              { -ident => "contacts.contactid" },
        };
    },
    { join_type => 'left' }
);

1;
