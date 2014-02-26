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
package Runtime::Schema::OpsviewServicegroups;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::Result::OpsviewServicegroups

=cut

__PACKAGE__->table( "opsview_servicegroups" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 128

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
        size          => 128
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->has_many(
    "servicechecks",
    "Runtime::Schema::OpsviewServicechecks",
    { "foreign.servicegroup_id" => "self.id" },
);

__PACKAGE__->has_many(
    "host_services",
    "Runtime::Schema::OpsviewHostServices",
    { "foreign.servicegroup_id" => "self.id" }
);

__PACKAGE__->has_many(
    "host_objects",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.servicegroup_id" => "self.id" }
);

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-17 17:57:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rEwm0HwYg8XS3jWLawPkdg

1;
