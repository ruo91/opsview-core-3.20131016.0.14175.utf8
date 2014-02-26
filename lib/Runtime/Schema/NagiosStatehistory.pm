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
package Runtime::Schema::NagiosStatehistory;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/UTF8Columns InflateColumn::DateTime Core/);
__PACKAGE__->table( "nagios_statehistory" );
__PACKAGE__->add_columns(
    "statehistory_id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "instance_id",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "state_time",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "state_time_usec",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "state_change",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "state",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "state_type",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "current_check_attempt",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "max_check_attempts",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "last_state",
    {
        data_type     => "SMALLINT",
        default_value => -1,
        is_nullable   => 0,
        size          => 6
    },
    "last_hard_state",
    {
        data_type     => "SMALLINT",
        default_value => -1,
        is_nullable   => 0,
        size          => 6
    },
    "downtimehistory_id",
    {
        data_type     => "SMALLINT",
        default_value => undef,
        is_nullable   => 1,
        size          => 6
    },
    "eventtype",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "output",
    {
        data_type     => "TEXT",
        default_value => "",
        is_nullable   => 0,
        size          => 65535
    },
);
__PACKAGE__->utf8_columns(qw/output/);
__PACKAGE__->set_primary_key( "statehistory_id" );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-07-16 21:25:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ASPBNcWLLUqEgSaGliG3Mw

__PACKAGE__->belongs_to(
    "object",
    "Runtime::Schema::NagiosObjects",
    { object_id => "object_id" },
    { join_type => "inner" },
);

__PACKAGE__->belongs_to(
    "downtimehistory",
    "Runtime::Schema::NagiosDowntimehistory",
    { downtimehistory_id => "downtimehistory_id" },
    { join_type          => "left" },
);

__PACKAGE__->has_many(
    "keywords",
    "Runtime::Schema::OpsviewViewports",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->has_many(
    "object_hosts",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
