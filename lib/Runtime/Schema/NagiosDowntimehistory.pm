package Runtime::Schema::NagiosDowntimehistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::NagiosDowntimehistory

=cut

__PACKAGE__->table( "nagios_downtimehistory" );

=head1 ACCESSORS

=head2 downtimehistory_id

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
  datetime_undef_if_invalid: 1
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
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 scheduled_end_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 was_started

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 actual_start_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 actual_start_time_usec

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 actual_end_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 actual_end_time_usec

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 was_cancelled

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 was_logged

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "downtimehistory_id",
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
        datetime_undef_if_invalid => 1,
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
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
        datetime_undef_if_invalid => 1,
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
    },
    "scheduled_end_time",
    {
        data_type                 => "datetime",
        datetime_undef_if_invalid => 1,
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
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
        datetime_undef_if_invalid => 1,
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
    },
    "actual_start_time_usec",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "actual_end_time",
    {
        data_type                 => "datetime",
        datetime_undef_if_invalid => 1,
        default_value             => "0000-00-00 00:00:00",
        is_nullable               => 0,
    },
    "actual_end_time_usec",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "was_cancelled",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
    "was_logged",
    {
        data_type     => "tinyint",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "downtimehistory_id" );
__PACKAGE__->add_unique_constraint( "instance_id",
    [ "instance_id", "object_id", "entry_time", "internal_downtime_id", ],
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-06-18 08:09:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6RNng8FgFXETWrgtU06JjA

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
