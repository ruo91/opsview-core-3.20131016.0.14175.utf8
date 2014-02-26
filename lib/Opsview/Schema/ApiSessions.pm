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

package Opsview::Schema::ApiSessions;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "InflateColumn::DateTime", "Core" );

=head1 NAME

Opsview::Schema::ApiSessions

=cut

__PACKAGE__->table( __PACKAGE__->opsviewdb . ".api_sessions" );

=head1 ACCESSORS

=head2 token

  data_type: CHAR
  default_value: undef
  is_nullable: 0
  size: 72

=head2 expires_at

  data_type: INT
  default_value: undef
  is_nullable: 0
  size: 10

=head2 accessed_at

  data_type: INT
  default_value: undef
  is_nullable: 0
  size: 10

=head2 username

  data_type: VARCHAR
  default_value: undef
  is_nullable: 0
  size: 128

=head2 ip

  data_type: VARCHAR
  default_value: undef
  is_nullable: 0
  size: 128

=cut

__PACKAGE__->add_columns(
    "token",
    {
        data_type     => "CHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 72
    },
    "expires_at",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 10,
    },
    "accessed_at",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 10,
    },
    "username",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 128,
    },
    "ip",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 0,
        size          => 128,
    },
    "one_time_token",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1,
    },
);
__PACKAGE__->set_primary_key( "token" );

1;
