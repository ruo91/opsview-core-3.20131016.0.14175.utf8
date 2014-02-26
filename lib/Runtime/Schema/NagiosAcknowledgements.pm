package Runtime::Schema::NagiosAcknowledgements;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::NagiosAcknowledgements

=cut

__PACKAGE__->table( "nagios_acknowledgements" );

=head1 ACCESSORS

=head2 acknowledgement_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 instance_id

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 entry_time

  data_type: 'datetime'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 entry_time_usec

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 acknowledgement_type

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 object_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 state

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 author_name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 comment_data

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 is_sticky

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 persistent_comment

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 notify_contacts

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "acknowledgement_id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0
    },
    "instance_id",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "entry_time",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
    },
    "entry_time_usec",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "acknowledgement_type",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "object_id",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "state",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "author_name",
    {
        data_type     => "varchar",
        default_value => "",
        is_nullable   => 0,
        size          => 64
    },
    "comment_data",
    {
        data_type     => "varchar",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "is_sticky",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "persistent_comment",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "notify_contacts",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "acknowledgement_id" );

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-04-27 15:53:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LkfDdoSc12hXngBnCji7Uw

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

1;
