package Opsview::Schema::Session;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

=head1 NAME

Opsview::Schema::Session

=cut

__PACKAGE__->load_components( '+Opsview::DBIx::Class::Common', 'Core' );
__PACKAGE__->table( __PACKAGE__->opsviewdb . '.sessions' );

=head1 ACCESSORS

=head2 id

  data_type: 'char'
  is_nullable: 0
  size: 72

=head2 session_data

  data_type: 'text'
  is_nullable: 1

=head2 expires

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
    'id',
    {
        data_type   => 'char',
        is_nullable => 0,
        size        => 72
    },
    'session_data',
    {
        data_type   => 'text',
        is_nullable => 1
    },
    'expires',
    {
        data_type   => 'integer',
        is_nullable => 1
    },
);
__PACKAGE__->set_primary_key( 'id' );

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-09-07 10:59:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GXiD60HDsqu5mCHt8Mbi2g
#
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

1;
