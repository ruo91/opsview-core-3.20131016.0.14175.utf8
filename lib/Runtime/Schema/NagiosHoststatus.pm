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
package Runtime::Schema::NagiosHoststatus;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "nagios_hoststatus" );
__PACKAGE__->add_columns(
    "hoststatus_id",
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
    "host_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "status_update_time",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "output",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 0,
        size          => 65535,
    },
    "perfdata",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 0,
        size          => 65535,
    },
    "current_state",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "has_been_checked",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "should_be_scheduled",
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
    "last_check",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "next_check",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "check_type",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "last_state_change",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "last_hard_state_change",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "last_hard_state",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "last_time_up",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "last_time_down",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "last_time_unreachable",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "state_type",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "last_notification",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "next_notification",
    {
        data_type     => "DATETIME",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
    },
    "no_more_notifications",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "notifications_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "problem_has_been_acknowledged",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "acknowledgement_type",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "current_notification_number",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "passive_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "active_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "event_handler_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "flap_detection_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "is_flapping",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "percent_state_change",
    {
        data_type     => "DOUBLE",
        default_value => 0,
        is_nullable   => 0,
        size          => 64
    },
    "latency",
    {
        data_type     => "DOUBLE",
        default_value => 0,
        is_nullable   => 0,
        size          => 64
    },
    "execution_time",
    {
        data_type     => "DOUBLE",
        default_value => 0,
        is_nullable   => 0,
        size          => 64
    },
    "scheduled_downtime_depth",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "failure_prediction_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "process_performance_data",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "obsess_over_host",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "modified_host_attributes",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "event_handler",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "check_command",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "normal_check_interval",
    {
        data_type     => "DOUBLE",
        default_value => 0,
        is_nullable   => 0,
        size          => 64
    },
    "retry_check_interval",
    {
        data_type     => "DOUBLE",
        default_value => 0,
        is_nullable   => 0,
        size          => 64
    },
    "check_timeperiod_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "hoststatus_id" );
__PACKAGE__->add_unique_constraint( "object_id", ["host_object_id"] );

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
    "opsview_host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.host_object_id" },
);

1;
