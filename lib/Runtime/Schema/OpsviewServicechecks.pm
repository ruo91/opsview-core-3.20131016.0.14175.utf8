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
package Runtime::Schema::OpsviewServicechecks;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::OpsviewServicechecks

=cut

__PACKAGE__->table( "opsview_servicechecks" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 128

=head2 multiple

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 active

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 markdown_filter

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 servicegroup

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "name",
    {
        data_type     => "varchar",
        default_value => "",
        is_nullable   => 0,
        size          => 64
    },
    "description",
    {
        data_type     => "varchar",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "multiple",
    {
        data_type     => "tinyint",
        default_value => 0,
        is_nullable   => 0
    },
    "active",
    {
        data_type     => "tinyint",
        default_value => 0,
        is_nullable   => 0
    },
    "markdown_filter",
    {
        data_type     => "tinyint",
        default_value => 0,
        is_nullable   => 0
    },
    "cascaded_from",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "servicegroup_id",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->belongs_to(
    "servicegroup",
    "Runtime::Schema::OpsviewServicegroups",
    { "foreign.id" => "self.servicegroup_id" },
);

__PACKAGE__->has_many(
    "host_services",
    "Runtime::Schema::OpsviewHostServices",
    { "foreign.servicecheck_id" => "self.id" }
);

__PACKAGE__->has_many(
    "host_objects",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.servicecheck_id" => "self.id" }
);

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-17 17:57:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q45M7tFC1NVCwP8IfuSFEg

# You can replace this text with custom content, and it will be preserved on regeneration
1;
