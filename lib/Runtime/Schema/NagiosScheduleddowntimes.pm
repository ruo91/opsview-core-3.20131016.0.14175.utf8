package Runtime::Schema::NagiosScheduleddowntimes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components( "InflateColumn::DateTime" );

=head1 NAME

Runtime::Schema::Result::NagiosScheduleddowntimes

=cut

__PACKAGE__->table( "nagios_scheduleddowntime" );

=head1 ACCESSORS

=head2 scheduleddowntime_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 instance_id

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 downtime_type

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 object_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 entry_time

  data_type: 'datetime'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 author_name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 comment_data

  data_type: 'text'
  is_nullable: 0

=head2 internal_downtime_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 triggered_by_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 is_fixed

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 duration

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 scheduled_start_time

  data_type: 'datetime'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 scheduled_end_time

  data_type: 'datetime'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 was_started

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 actual_start_time

  data_type: 'datetime'
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 actual_start_time_usec

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "scheduleddowntime_id",
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
    "downtime_type",
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
    "entry_time",
    {
        data_type                 => "datetime",
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
        timezone                  => "UTC",
        datetime_undef_if_invalid => 1,
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
        data_type   => "text",
        is_nullable => 0
    },
    "internal_downtime_id",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "triggered_by_id",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "is_fixed",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "duration",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "scheduled_start_time",
    {
        data_type                 => "datetime",
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
        timezone                  => "UTC",
        datetime_undef_if_invalid => 1,
    },
    "scheduled_end_time",
    {
        data_type                 => "datetime",
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
        timezone                  => "UTC",
        datetime_undef_if_invalid => 1,
    },
    "was_started",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "actual_start_time",
    {
        data_type                 => "datetime",
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
        timezone                  => "UTC",
        datetime_undef_if_invalid => 1,
    },
    "actual_start_time_usec",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "scheduleddowntime_id" );
__PACKAGE__->add_unique_constraint( "instance_id",
    [ "object_id", "instance_id", "entry_time", "internal_downtime_id", ],
);

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-02-02 22:24:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vytcCU8RqTUjCXR92wFCXg

#
# AUTHORS:
#   Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

__PACKAGE__->resultset_class( "Runtime::ResultSet::NagiosScheduleddowntimes" );

__PACKAGE__->belongs_to(
    "object",
    "Runtime::Schema::OpsviewHostObjects",
    { object_id => "object_id" },
    { join_type => "inner" }
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);
1;
