package Opsview::Schema::RoleAccessServicegroups;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );

=head1 NAME

Opsview::Schema::RoleAccessServicegroups

=cut

__PACKAGE__->table( __PACKAGE__->opsviewdb . ".role_access_servicegroups" );

=head1 ACCESSORS

=head2 roleid

  data_type: INT
  default_value: undef
  is_foreign_key: 1
  is_nullable: 0
  size: 11

=head2 servicegroupid

  data_type: INT
  default_value: undef
  is_foreign_key: 1
  is_nullable: 0
  size: 11

=cut

__PACKAGE__->add_columns(
    "roleid",
    {
        data_type      => "INT",
        default_value  => undef,
        is_foreign_key => 1,
        is_nullable    => 0,
        size           => 11,
    },
    "servicegroupid",
    {
        data_type      => "INT",
        default_value  => undef,
        is_foreign_key => 1,
        is_nullable    => 0,
        size           => 11,
    },
);
__PACKAGE__->set_primary_key( "roleid", "servicegroupid" );

=head1 RELATIONS

=head2 roleid

Type: belongs_to

Related object: L<Opsview::Schema::Result::Role>

=cut

__PACKAGE__->belongs_to( "roleid", "Opsview::Schema::Roles", { id => "roleid" },
    {}, );

=head2 servicegroupid

Type: belongs_to

Related object: L<Opsview::Schema::Servicegroups>

=cut

__PACKAGE__->belongs_to(
    "servicegroupid",
    "Opsview::Schema::Servicegroups",
    { id => "servicegroupid" }, {},
);

# Created by DBIx::Class::Schema::Loader v0.05003 @ 2010-11-29 17:07:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WmRIYqKbMD7yCt5BH1LNbA

# AUTHORS:
#   Copyright (C) 2003-2013 Opsview Limited. All rights reserved
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

# You can replace this text with custom content, and it will be preserved on regeneration
1;
